// Atak (episode) kuralları: eski `services/health/episode.py` portu.

import '../../data/database/app_database.dart';
import '../../data/database/enums.dart';
import '../../data/repositories/episode_repository.dart';
import '../../data/repositories/support.dart';
import '../../data/repositories/symptom_entry_repository.dart';
import '../errors.dart';

/// Birden çok yazmayı tek işlem yapar (ör. `db.transaction`). Verilmezse
/// adımlar sırayla, işlemsiz çalışır.
typedef Transactor = Future<T> Function<T>(Future<T> Function() action);

Future<T> runDirect<T>(Future<T> Function() action) => action();

class EpisodeService {
  EpisodeService({
    required EpisodeRepository episodes,
    required SymptomEntryRepository entries,
    Transactor? transactor,
    Clock? clock,
  })  : _episodes = episodes,
        _entries = entries,
        _tx = transactor ?? runDirect,
        _clock = clock ?? DateTime.now;

  final EpisodeRepository _episodes;
  final SymptomEntryRepository _entries;
  final Transactor _tx;
  final Clock _clock;

  /// Bu semptom için devam eden atak (yoksa null).
  Future<Episode?> activeEpisode(String symptomId) =>
      _episodes.findOngoing(symptomId);

  /// Girişle yeni atak başlatır: atak girişin zamanında başlar, giriş ataka
  /// bağlanır, girişte konum varsa atağın ilk konumu olur.
  Future<Episode> start(SymptomEntry entry) {
    return _tx(() async {
      final episode = await _episodes.start(
        symptomId: entry.symptomId,
        startTime: entry.timestamp,
      );
      await _entries.attachToEpisode(entry.id, episode.id);
      if (entry.location.isNotEmpty) {
        await _episodes.addLocation(
          episodeId: episode.id,
          location: entry.location,
          addedAt: entry.timestamp,
        );
      }
      return episode;
    });
  }

  /// Girişi var olan ataka bağlar. [isNewLocation] doğruysa ve konum atakta
  /// henüz yoksa konum eklenir.
  Future<void> addEntry(
    Episode episode,
    SymptomEntry entry, {
    bool isNewLocation = false,
  }) {
    return _tx(() async {
      await _entries.attachToEpisode(entry.id, episode.id);
      if (isNewLocation && entry.location.isNotEmpty) {
        final existing = (await _episodes.listLocations(episode.id))
            .map((l) => l.location);
        if (!existing.contains(entry.location)) {
          await _episodes.addLocation(
            episodeId: episode.id,
            location: entry.location,
            addedAt: entry.timestamp,
          );
        }
      }
    });
  }

  /// Atağı kapatır. Zaten kapalıysa ya da bitiş başlangıçtan önce/eşitse
  /// [RuleViolation] fırlatır.
  Future<void> close(
    Episode episode, {
    DateTime? endedAt,
    String resolutionNotes = '',
  }) async {
    if (episode.status == EpisodeStatus.resolved) {
      throw const RuleViolation(
        RuleCodes.episodeAlreadyClosed,
        'Bu atak zaten kapatılmış.',
      );
    }
    final end = endedAt ?? _clock();
    if (!end.isAfter(episode.startTime)) {
      throw const RuleViolation(
        RuleCodes.episodeEndBeforeStart,
        'Bitiş zamanı başlangıç zamanından önce olamaz.',
      );
    }
    await _episodes.markResolved(
      id: episode.id,
      endedAt: end,
      resolutionNotes: resolutionNotes,
    );
  }

  /// Süre dakika olarak (kapanmamışsa null); kesirli dakika atılır.
  static int? durationMinutes(Episode episode) {
    final end = episode.endedAt;
    if (end == null) return null;
    return (end.difference(episode.startTime).inSeconds / 60).truncate();
  }
}
