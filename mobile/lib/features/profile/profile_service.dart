import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';

class ProfileService {
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await ApiClient.dio.get('/users/me/');
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Profil alınamadı');
    }
  }

  static Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final response = await ApiClient.dio.post(
        '/users/change-password/',
        data: {
          'old_password': oldPassword,
          'new_password': newPassword,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Şifre değiştirilemedi');
    }
  }
}