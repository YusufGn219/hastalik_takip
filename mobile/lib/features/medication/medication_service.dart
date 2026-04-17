import 'package:dio/dio.dart';
import 'package:mobile/core/network/api_client.dart';

class MedicationService{
  final Dio _dio = ApiClient.dio;
  Future<List<dynamic>> getMedications() async {
    final response = await _dio.get ('/health/medications/');
    return response.data;
  }

  Future<Map<String, dynamic>> createMedication({
    required String name,
    required String type,
    bool isRecurring = false,
    String? recurringTime,
    List<String>? recurringDays,
  }) async {
    final response = await _dio.post('/health/medications/', data:{
      'name': name,
      'type': type,
      'is_recurring': isRecurring,
      if(recurringTime != null) 'recurring_time': recurringTime,
      if(recurringDays != null) 'recurring_days': recurringDays,
    });
    return response.data;
  }

    Future<List<dynamic>> getChronicConditions() async {
    final response = await _dio.get('/health/chronic-conditions/');
    return response.data;
  }

  Future<Map<String, dynamic>> createChronicCondition({
    required String name,
    List<int> medicationIds = const [],
  }) async {
    final response = await _dio.post('/health/chronic-conditions/', data: {
      'name': name,
      'medication_ids': medicationIds,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> updateChronicCondition({
    required int id,
    required String name,
    List<int> medicationIds = const [],
  }) async {
    final response = await _dio.patch('/health/chronic-conditions/$id/', data: {
      'name': name,
      'medication_ids': medicationIds,
    });
    return response.data;
  }

  Future<void> deleteChronicCondition(int id) async {
    await _dio.delete('/health/chronic-conditions/$id/');
  }

  // --- Medication Logs ---

  Future<Map<String, dynamic>> createMedicationLog({
    required int medicationId,
    required String takenAt,
    double? doseAmount,
    String doseUnit = 'tablet',
    int? episodeId,
    int? conditionId,
    String notes = '',
  }) async {
    final response = await _dio.post('/health/medication-logs/', data: {
      'medication': medicationId,
      'taken_at': takenAt,
      if (doseAmount != null) 'dose_amount': doseAmount,
      'dose_unit': doseUnit,
      if (episodeId != null) 'episode_id': episodeId,
      if (conditionId != null) 'condition_id': conditionId,
      'notes': notes,
    });
    return response.data;
  }

  Future<void> deleteMedicationLog(int id) async {
    await _dio.delete('/health/medication-logs/$id/');
  }
}