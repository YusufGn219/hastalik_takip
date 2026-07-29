import 'package:dio/dio.dart';
import '../storage/token_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiClient {
  static String baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:8000/api/v1';

  // Eşzamanlı birden fazla 401 aynı anda gelirse tek bir refresh isteği
  // paylaşılsın diye — her 401 kendi refresh'ini tetiklerse refresh token
  // rotation'ı yüzünden birbirini geçersiz kılabilirler.
  static Future<String?>? _refreshFuture;

  static Dio createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final isAuthEndpoint = options.path.contains('/auth/');
        if (!isAuthEndpoint) {
          final token = await TokenStorage.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        final isAuthEndpoint = error.requestOptions.path.contains('/auth/');
        if (error.response?.statusCode != 401 || isAuthEndpoint) {
          return handler.next(error);
        }

        final newAccessToken = await _refreshAccessToken();
        if (newAccessToken == null) {
          await TokenStorage.clearTokens();
          return handler.next(error);
        }

        final retryOptions = error.requestOptions;
        retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';
        try {
          final retryResponse = await dio.fetch(retryOptions);
          return handler.resolve(retryResponse);
        } on DioException catch (retryError) {
          return handler.next(retryError);
        }
      },
    ));
    return dio;
  }

  static Future<String?> _refreshAccessToken() {
    _refreshFuture ??= _doRefresh().whenComplete(() => _refreshFuture = null);
    return _refreshFuture!;
  }

  static Future<String?> _doRefresh() async {
    final refresh = await TokenStorage.getRefreshToken();
    if (refresh == null) return null;

    try {
      final refreshDio = Dio(BaseOptions(baseUrl: baseUrl));
      final response = await refreshDio.post(
        '/auth/token/refresh/',
        data: {'refresh': refresh},
      );
      final newAccessToken = response.data['access'] as String;
      // ROTATE_REFRESH_TOKENS aktif olduğu için backend her refresh'te
      // yeni bir refresh token da döner — eskisi blacklist'e düşer.
      final newRefreshToken = response.data['refresh'] as String? ?? refresh;
      await TokenStorage.saveTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      );
      return newAccessToken;
    } catch (_) {
      return null;
    }
  }

  static final Dio dio = createDio();
}
