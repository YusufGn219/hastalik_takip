import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'support.dart';

/// Açıkça atlanan rutin dozlar. Alım kaydı değildir (bkz. [DoseSkips]); kurallar
/// (doz planlı mı, zaten alınmış mı) servis katmanındadır, burası yalnız saklar.
abstract class DoseSkipRepository {
  /// [scheduledDay] 'YYYY-MM-DD', [scheduledTime] 'HH:mm'. Aynı doz için
  /// silinmemiş ikinci kayıt veritabanı dizininde reddedilir.
  Future<DoseSkip> create({
    required String medicationId,
    required String scheduledDay,
    required String scheduledTime,
    required DateTime skippedAt,
  });

  /// Yerel [day] gününe ait silinmemiş atlama kayıtları.
  Future<List<DoseSkip>> listForDay(String day);

  Future<void> softDelete(String id);
}

class DriftDoseSkipRepository implements DoseSkipRepository {
  DriftDoseSkipRepository(this._db, {Clock? clock, IdGenerator? newId})
      : _clock = clock ?? DateTime.now,
        _newId = newId ?? newUuid;

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _newId;

  @override
  Future<DoseSkip> create({
    required String medicationId,
    required String scheduledDay,
    required String scheduledTime,
    required DateTime skippedAt,
  }) {
    final now = _clock();
    return _db.into(_db.doseSkips).insertReturning(
          DoseSkipsCompanion.insert(
            id: _newId(),
            createdAt: now,
            updatedAt: now,
            medicationId: medicationId,
            scheduledDay: scheduledDay,
            scheduledTime: scheduledTime,
            skippedAt: skippedAt,
            utcOffsetMinutes: utcOffsetOf(skippedAt),
          ),
        );
  }

  @override
  Future<List<DoseSkip>> listForDay(String day) {
    return (_db.select(_db.doseSkips)
          ..where((t) => t.deletedAt.isNull() & t.scheduledDay.equals(day))
          ..orderBy([(t) => OrderingTerm.asc(t.skippedAt)]))
        .get();
  }

  @override
  Future<void> softDelete(String id) async {
    final now = _clock();
    await (_db.update(_db.doseSkips)..where((t) => t.id.equals(id))).write(
      DoseSkipsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }
}
