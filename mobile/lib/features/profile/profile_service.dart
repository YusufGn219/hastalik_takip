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

  static Future<Map<String, dynamic>> updateProfile({
    required String firstName,
    required String lastName,
  }) async {
    try {
      final response = await ApiClient.dio.patch(
        '/users/me/',
        data: {
          'first_name': firstName,
          'last_name': lastName,
        },
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Profil güncellenemedi');
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

  static Future<Map<String, dynamic>> uploadProfilePhoto(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'profile_photo': await MultipartFile.fromFile(
          filePath,
          filename: filePath.split('/').last,
        ),
      });
      final response = await ApiClient.dio.post(
        '/users/profile-photo/',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Fotoğraf yüklenemedi');
    }
  }

  static Future<Map<String, dynamic>> deleteProfilePhoto() async {
    try {
      final response = await ApiClient.dio.delete('/users/profile-photo/');
      return response.data;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Fotoğraf silinemedi');
    }
  }
}