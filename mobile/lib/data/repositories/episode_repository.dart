import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/enums.dart';
import 'support.dart';

/// Atak / dönem kayıtları. İş kuralları (zaten kapalı mı, bitiş başlangıçtan
/// önce olamaz vb.) servis katmanındadır (Sprint 2); burası yalnız saklar.
abstract class EpisodeRepository {
  Future<Episode> start({
    required String symptomId,
    required DateTime startTime,
  });

  Future<Episode?> getById(String id);

  /// Bu semptom için devam eden atak (varsa).
  Future<Episode?> findOngoing(String symptomId);

  /// Silinmemiş tüm ataklar, başlangıcı en yeni olan önce.
  Future<List<Episode>> listAll();

  Future<void> markResolved({
    required String id,
    required DateTime endedAt,
    String resolutionNotes = '',
  });

  Future<EpisodeLocationEntry> addLocation({
    required String episodeId,
    required String location,
    required DateTime addedAt,
  });

  Future<List<EpisodeLocationEntry>> listLocations(String episodeId);

  Future<void> softDelete(String id);
}

class DriftEpisodeRepository implements EpisodeRepository {
  DriftEpisodeRepository(this._db, {Clock? clock, IdGenerator? newId})
      : _clock = clock ?? DateTime.now,
        _newId = newId ?? newUuid;

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _newId;

  @override
  Future<Episode> start({
    required String symptomId,
    required DateTime startTime,
  }) {
    final now = _clock();
    return _db.into(_db.episodes).insertReturning(
          EpisodesCompanion.insert(
            id: _newId(),
            createdAt: now,
            updatedAt: now,
            symptomId: symptomId,
            startTime: startTime,
            startUtcOffsetMinutes: utcOffsetOf(startTime),
          ),
        );
  }

  @override
  Future<Episode?> getById(String id) {
    return (_db.select(_db.episodes)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<Episode?> findOngoing(String symptomId) {
    return (_db.select(_db.episodes)
          ..where(
            (t) =>
                t.deletedAt.isNull() &
                t.symptomId.equals(symptomId) &
                t.status.equals(EpisodeStatus.ongoing.name),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.startTime)])
          ..limit(1))
        .getSingleOrNull();
  }

  @override
  Future<List<Episode>> listAll() {
    return (_db.select(_db.episodes)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.startTime)]))
        .get();
  }

  @override
  Future<void> markResolved({
    required String id,
    required DateTime endedAt,
    String resolutionNotes = '',
  }) async {
    await (_db.update(_db.episodes)..where((t) => t.id.equals(id))).write(
      EpisodesCompanion(
        status: const Value(EpisodeStatus.resolved),
        endedAt: Value(endedAt),
        endUtcOffsetMinutes: Value(utcOffsetOf(endedAt)),
        resolutionNotes: Value(resolutionNotes),
        updatedAt: Value(_clock()),
      ),
    );
  }

  @override
  Future<EpisodeLocationEntry> addLocation({
    required String episodeId,
    required String location,
    required DateTime addedAt,
  }) {
    final now = _clock();
    return _db.into(_db.episodeLocationEntries).insertReturning(
          EpisodeLocationEntriesCompanion.insert(
            id: _newId(),
            createdAt: now,
            updatedAt: now,
            episodeId: episodeId,
            location: location,
            addedAt: addedAt,
            utcOffsetMinutes: utcOffsetOf(addedAt),
          ),
        );
  }

  @override
  Future<List<EpisodeLocationEntry>> listLocations(String episodeId) {
    return (_db.select(_db.episodeLocationEntries)
          ..where(
            (t) => t.deletedAt.isNull() & t.episodeId.equals(episodeId),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.addedAt)]))
        .get();
  }

  @override
  Future<void> softDelete(String id) async {
    final now = _clock();
    await (_db.update(_db.episodes)..where((t) => t.id.equals(id))).write(
      EpisodesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }
}
