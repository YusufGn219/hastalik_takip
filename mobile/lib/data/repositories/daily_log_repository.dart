import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'support.dart';

abstract class DailyLogRepository {
  /// Gün için kayıt yoksa ekler, varsa günceller (günde tek kayıt).
  /// [logDate] yerel takvim günü, 'YYYY-MM-DD'.
  Future<DailyLog> upsert({
    required String logDate,
    required double sleepHours,
    required double waterIntake,
    required int mood,
    required int energyLevel,
    String? notes,
  });

  Future<DailyLog?> getByDate(String logDate);

  /// [fromDate] ve [toDate] dahil, tarihe göre artan.
  Future<List<DailyLog>> listInRange(String fromDate, String toDate);

  Future<void> softDelete(String id);
}

class DriftDailyLogRepository implements DailyLogRepository {
  DriftDailyLogRepository(this._db, {Clock? clock, IdGenerator? newId})
      : _clock = clock ?? DateTime.now,
        _newId = newId ?? newUuid;

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _newId;

  @override
  Future<DailyLog> upsert({
    required String logDate,
    required double sleepHours,
    required double waterIntake,
    required int mood,
    required int energyLevel,
    String? notes,
  }) {
    return _db.transaction(() async {
      final now = _clock();
      final existing = await getByDate(logDate);
      if (existing == null) {
        return _db.into(_db.dailyLogs).insertReturning(
              DailyLogsCompanion.insert(
                id: _newId(),
                createdAt: now,
                updatedAt: now,
                logDate: logDate,
                sleepHours: sleepHours,
                waterIntake: waterIntake,
                mood: mood,
                energyLevel: energyLevel,
                notes: Value(notes),
              ),
            );
      }
      await (_db.update(_db.dailyLogs)..where((t) => t.id.equals(existing.id)))
          .write(
        DailyLogsCompanion(
          sleepHours: Value(sleepHours),
          waterIntake: Value(waterIntake),
          mood: Value(mood),
          energyLevel: Value(energyLevel),
          notes: Value(notes),
          updatedAt: Value(now),
        ),
      );
      return (await getByDate(logDate))!;
    });
  }

  @override
  Future<DailyLog?> getByDate(String logDate) {
    return (_db.select(_db.dailyLogs)
          ..where((t) => t.deletedAt.isNull() & t.logDate.equals(logDate)))
        .getSingleOrNull();
  }

  @override
  Future<List<DailyLog>> listInRange(String fromDate, String toDate) {
    return (_db.select(_db.dailyLogs)
          ..where(
            (t) =>
                t.deletedAt.isNull() &
                t.logDate.isBiggerOrEqualValue(fromDate) &
                t.logDate.isSmallerOrEqualValue(toDate),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.logDate)]))
        .get();
  }

  @override
  Future<void> softDelete(String id) async {
    final now = _clock();
    await (_db.update(_db.dailyLogs)..where((t) => t.id.equals(id))).write(
      DailyLogsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }
}
