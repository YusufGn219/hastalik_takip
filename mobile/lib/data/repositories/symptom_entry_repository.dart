import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'support.dart';

abstract class SymptomEntryRepository {
  Future<SymptomEntry> create({
    required String symptomId,
    required int severity,
    required DateTime timestamp,
    String? episodeId,
    String notes = '',
    String location = '',
  });

  Future<SymptomEntry?> getById(String id);

  /// [from] ve [to] dahil. Hangi uç dahil/hariç olacağı iş mantığına (servis)
  /// bağlıdır; burası geniş aralığı verir, servis kendi kuralıyla süzer.
  Future<List<SymptomEntry>> listInRange(DateTime from, DateTime to);

  /// [from] dahil, üst sınır yok.
  Future<List<SymptomEntry>> listSince(DateTime from);

  Future<List<SymptomEntry>> listForEpisode(String episodeId);

  Future<void> attachToEpisode(String entryId, String episodeId);

  Future<void> softDelete(String id);
}

class DriftSymptomEntryRepository implements SymptomEntryRepository {
  DriftSymptomEntryRepository(this._db, {Clock? clock, IdGenerator? newId})
      : _clock = clock ?? DateTime.now,
        _newId = newId ?? newUuid;

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _newId;

  @override
  Future<SymptomEntry> create({
    required String symptomId,
    required int severity,
    required DateTime timestamp,
    String? episodeId,
    String notes = '',
    String location = '',
  }) {
    final now = _clock();
    return _db.into(_db.symptomEntries).insertReturning(
          SymptomEntriesCompanion.insert(
            id: _newId(),
            createdAt: now,
            updatedAt: now,
            symptomId: symptomId,
            episodeId: Value(episodeId),
            severity: severity,
            timestamp: timestamp,
            utcOffsetMinutes: utcOffsetOf(timestamp),
            notes: Value(notes),
            location: Value(location),
          ),
        );
  }

  @override
  Future<SymptomEntry?> getById(String id) {
    return (_db.select(_db.symptomEntries)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<List<SymptomEntry>> listInRange(DateTime from, DateTime to) {
    return (_db.select(_db.symptomEntries)
          ..where(
            (t) =>
                t.deletedAt.isNull() &
                t.timestamp.isBiggerOrEqualValue(from) &
                t.timestamp.isSmallerOrEqualValue(to),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
        .get();
  }

  @override
  Future<List<SymptomEntry>> listSince(DateTime from) {
    return (_db.select(_db.symptomEntries)
          ..where(
            (t) =>
                t.deletedAt.isNull() & t.timestamp.isBiggerOrEqualValue(from),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
        .get();
  }

  @override
  Future<List<SymptomEntry>> listForEpisode(String episodeId) {
    return (_db.select(_db.symptomEntries)
          ..where((t) => t.deletedAt.isNull() & t.episodeId.equals(episodeId))
          ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
        .get();
  }

  @override
  Future<void> attachToEpisode(String entryId, String episodeId) async {
    await (_db.update(_db.symptomEntries)..where((t) => t.id.equals(entryId)))
        .write(
      SymptomEntriesCompanion(
        episodeId: Value(episodeId),
        updatedAt: Value(_clock()),
      ),
    );
  }

  @override
  Future<void> softDelete(String id) async {
    final now = _clock();
    await (_db.update(_db.symptomEntries)..where((t) => t.id.equals(id)))
        .write(SymptomEntriesCompanion(
      deletedAt: Value(now),
      updatedAt: Value(now),
    ));
  }
}
