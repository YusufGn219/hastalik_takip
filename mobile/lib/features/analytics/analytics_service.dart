// mobile/lib/features/analytics/analytics_service.dart

import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

class AnalyticsService {
  final Dio _dio = ApiClient.dio;

  Future<Map<String, dynamic>> getSymptomAnalytics(int days) async {
    final response = await _dio.get(
      '/health/analytics/symptoms/',
      queryParameters: {'days': days},
    );
    return response.data;
  }

  Future<Map<String, dynamic>> getDailyTrends(int days) async {
    final response = await _dio.get(
      '/health/analytics/daily-trends/',
      queryParameters: {'days': days},
    );
    return response.data;
  }

  Future<Map<String, dynamic>> getMedicationEffect(int days) async {
    final response = await _dio.get(
      '/health/analytics/medication-effect/',
      queryParameters: {'days': days},
    );
    return response.data;
  }

  Future<Map<String, dynamic>> getMedicationAdherence(int days) async {
    final response = await _dio.get(
      '/health/analytics/medication-adherence/',
      queryParameters: {'days': days},
    );
    return response.data;
  }
}