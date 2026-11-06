// Dönem listesi için okuma modeli: bir dönemi, kartta gösterilecek her şeyle
// (semptom adı, girişler, konumlar) birlikte toplar.

import 'dart:math' as math;

import '../../data/database/app_database.dart';
import '../../data/database/enums.dart';
import '../../data/repositories/episode_repository.dart';
import '../../data/repositories/symptom_entry_repository.dart';
import '../../data/repositories/symptom_repository.dart';
import '../../domain/services/episode_service.dart';

/// Tek dönem ve kartında gösterilen bilgiler.
class EpisodeOverview {
  const EpisodeOverview({
    required this.episode,
    required this.symptomName,
    required this.entries,
    required this.locations,
  });

  final Episode episode;

  /// Semptom bulunamazsa boş metin.
  final String symptomName;

  /// Döneme bağlı girişler, zamana göre artan.
  final List<SymptomEntry> entries;

  /// Dönemin konumları, eklenme zamanına göre artan.
  final List<EpisodeLocationEntry> locations;

  bool get isOngoing => episode.status == EpisodeStatus.ongoing;

  /// En son girişin şiddeti; giriş yoksa null.
  int? get lastSeverity => entries.isEmpty ? null : entries.last.severity;

  /// Girişlerin en yükseği; giriş yoksa null.
  int? get maxSeverity =>
      entries.isEmpty ? null : entries.map((e) => e.severity).reduce(math.max);

  /// Dakika olarak süre; dönem kapanmamışsa null.
  int? get durationMinutes => EpisodeService.durationMinutes(episode);
}

/// Dönemleri yerel veritabanından okur, devam edenler ve biten geçmiş olarak
/// ayırır.
class EpisodeOverviewLoader {
  EpisodeOverviewLoader({
    required EpisodeRepository episodes,
    required SymptomEntryRepository entries,
    required SymptomRepository symptoms,
  })  : _episodes = episodes,
        _entries = entries,
        _symptoms = symptoms;

  final EpisodeRepository _episodes;
  final SymptomEntryRepository _entries;
  final SymptomRepository _symptoms;

  /// Devam edenler: en yeni başlayan üstte. Geçmiş: en son biten üstte.
  Future<({List<EpisodeOverview> active, List<EpisodeOverview> history})>
      load() async {
    final all = await _episodes.listAll();
    final names = <String, String>{};
    final active = <EpisodeOverview>[];
    final history = <EpisodeOverview>[];

    for (final episode in all) {
      if (!names.containsKey(episode.symptomId)) {
        final symptom = await _symptoms.getById(episode.symptomId);
        names[episode.symptomId] = symptom?.name ?? '';
      }
      final overview = EpisodeOverview(
        episode: episode,
        symptomName: names[episode.symptomId]!,
        entries: await _entries.listForEpisode(episode.id),
        locations: await _episodes.listLocations(episode.id),
      );
      (overview.isOngoing ? active : history).add(overview);
    }

    active.sort((a, b) => b.episode.startTime.compareTo(a.episode.startTime));
    history.sort((a, b) => (b.episode.endedAt ?? b.episode.startTime)
        .compareTo(a.episode.endedAt ?? a.episode.startTime));
    return (active: active, history: history);
  }
}
