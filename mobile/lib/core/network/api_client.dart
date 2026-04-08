import 'package:dio/dio.dart';
import '../storage/token_storage.dart';

class ApiClient {
  static const String baseUrl = 'http://192.168.1.103:8000/api/v1';

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
    ));
    return dio;
  }
  static final Dio dio = createDio();
}