import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/token_storage.dart';

class AuthService {
  static Future<Map<String, dynamic>> register({
    required String email,
    required String firstName,
    required String lastName,
    required String password,
  }) async {
    try {
      final response = await ApiClient.dio.post(
        '/auth/register/',
        data: {
          'email': email,
          'first_name': firstName,
          'last_name': lastName,
          'password': password,
        },
      );
      final data = response.data['data'];
      await TokenStorage.saveTokens(
        accessToken: data['tokens']['access'],
        refreshToken: data['tokens']['refresh'],
      );
      return {'success': true, 'data': data};
    } on DioException catch (e) {
      print('REGISTER HATA: ${e.message}');
      print('REGISTER RESPONSE: ${e.response?.data}');
      print('REGISTER STATUS: ${e.response?.statusCode}');
      return {
        'success': false,
        'message': e.response?.data['message'] ?? e.message ?? 'Bir hata oluştu',
      };
    }
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await ApiClient.dio.post(
        '/auth/login/',
        data: {
          'email': email,
          'password': password,
        },
      );
      final data = response.data['data'];
      await TokenStorage.saveTokens(
        accessToken: data['tokens']['access'],
        refreshToken: data['tokens']['refresh'],
      );
      return {'success': true, 'data': data};
    } on DioException catch (e) {
      print('LOGIN HATA: ${e.message}');
      print('LOGIN RESPONSE: ${e.response?.data}');
      print('LOGIN STATUS: ${e.response?.statusCode}');
      return {
        'success': false,
        'message': e.response?.data['message'] ?? e.message ?? 'Bir hata oluştu',
      };
    }
  }

  static Future<void> logout() async {
    await TokenStorage.clearTokens();
  }

  static Future<Map<String, dynamic>> getMe() async {
    try {
      final response = await ApiClient.dio.get('/users/me/');
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Kullanıcı bilgisi alınamadı');
    }
  }

  static Future<void> refreshToken() async {
    final refresh = await TokenStorage.getRefreshToken();
    if (refresh == null) throw Exception('Refresh token yok');

    final response = await ApiClient.dio.post(
      '/auth/token/refresh/',
      data: {'refresh': refresh},
    );

    final newAccessToken = response.data['access'];
    await TokenStorage.saveTokens(
      accessToken: newAccessToken,
      refreshToken: refresh,
    );
  }
}