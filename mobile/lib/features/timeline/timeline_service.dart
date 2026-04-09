import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

class TimelineService {
  final Dio _dio = ApiClient.dio;

  Future<Map<String, dynamic>> getTimeline(String date) async {
    final response = await _dio.get(
      '/health/timeline/',
      queryParameters: {'date': date},
    );
    return response.data;
  }
}