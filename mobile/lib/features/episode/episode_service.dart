import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

class EpisodeService {
  final Dio _dio = ApiClient.dio;

  // Tüm episodları getir
  Future<List<dynamic>> getEpisodes() async {
    final response = await _dio.get('/health/episodes/');
    return response.data['data'];
  }

  // Aktif episodları getir
  Future<List<dynamic>> getActiveEpisodes() async {
    final response = await _dio.get('/health/episodes/active/');
    return response.data['data'];
  }

  // Geçmiş episodları getir
  Future<List<dynamic>> getHistoryEpisodes() async {
    final response = await _dio.get('/health/episodes/history/');
    return response.data['data'];
  }

  // Tekil episode getir
  Future<Map<String, dynamic>> getEpisode(int id) async {
    final response = await _dio.get('/health/episodes/$id/');
    return response.data['data'];
  }

  // Episode başlat
  Future<Map<String, dynamic>> startEpisode(int symptomEntryId) async {
    final response = await _dio.post(
      '/health/episodes/',
      data: {
        'symptom_entry_id': symptomEntryId,
        'action': 'start',
      },
    );
    return response.data['data'];
  }

  // Mevcut episode'a entry ekle
  Future<Map<String, dynamic>> addToEpisode({
    required int symptomEntryId,
    required int episodeId,
    required bool isNewLocation,
  }) async {
    final response = await _dio.post(
      '/health/episodes/',
      data: {
        'symptom_entry_id': symptomEntryId,
        'action': 'add',
        'episode_id': episodeId,
        'is_new_location': isNewLocation,
      },
    );
    return response.data['data'];
  }

  // Episode kapat
  Future<Map<String, dynamic>> closeEpisode({
    required int episodeId,
    DateTime? endedAt,
    String resolutionNotes = '',
  }) async {
    final response = await _dio.patch(
      '/health/episodes/$episodeId/close/',
      data: {
        if (endedAt != null) 'ended_at': endedAt.toIso8601String(),
        'resolution_notes': resolutionNotes,
      },
    );
    return response.data['data'];
  }

  // Episode sil
  Future<void> deleteEpisode(int episodeId) async {
    await _dio.delete('/health/episodes/$episodeId/');
  }
}