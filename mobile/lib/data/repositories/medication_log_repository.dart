import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/enums.dart';
import 'support.dart';

/// İlaç alım kayıtları. "Atak ve kronik hastalık aynı anda dolu olamaz" gibi
/// kurallar servis katmanındadır (Sprint 2); burası yalnız saklar.
abstract class MedicationLogRepository {
  Future<MedicationLog> create({
    required String medicationId,
    required DateTime takenAt,
    double? doseAmount,
    DoseUnit doseUnit = DoseUnit.tablet,
    String? episodeId,
    String? conditionId,
    String notes = '',
  });

  Future<MedicationLog?> getById(String id);

  /// [from] ve [to] dahil; servis kendi kuralıyla süzer.
  Future<List<MedicationLog>> listInRange(DateTime from, DateTime to);
  Future<List<MedicationLog>> listSince(DateTime from);
  Future<List<MedicationLog>> listForEpisode(String episodeId);
  Future<List<MedicationLog>> listForMedication(String medicationId);

  Future<void> softDelete(String id);
}

class DriftMedicationLogRepository implements MedicationLogRepository {
  DriftMedicationLogRepository(this._db, {Clock? clock, IdGenerator? newId})
      : _clock = clock ?? DateTime.now,
        _newId = newId ?? newUuid;

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _newId;

  @override
  Future<MedicationLog> create({
    required String medicationId,
    required DateTime takenAt,
    double? doseAmount,
    DoseUnit doseUnit = DoseUnit.tablet,
    String? episodeId,
    String? conditionId,
    String notes = '',
  }) {
    final now = _clock();
    return _db.into(_db.medicationLogs).insertReturning(
          MedicationLogsCompanion.insert(
            id: _newId(),
            createdAt: now,
            updatedAt: now,
            medicationId: medicationId,
            takenAt: takenAt,
            utcOffsetMinutes: utcOffsetOf(takenAt),
            doseAmount: Value(doseAmount),
            doseUnit: Value(doseUnit),
            episodeId: Value(episodeId),
            conditionId: Value(conditionId),
            notes: Value(notes),
          ),
        );
  }

  @override
  Future<MedicationLog?> getById(String id) {
    return (_db.select(_db.medicationLogs)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<List<MedicationLog>> listInRange(DateTime from, DateTime to) {
    return (_db.select(_db.medicationLogs)
          ..where(
            (t) =>
                t.deletedAt.isNull() &
                t.takenAt.isBiggerOrEqualValue(from) &
                t.takenAt.isSmallerOrEqualValue(to),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]))
        .get();
  }

  @override
  Future<List<MedicationLog>> listSince(DateTime from) {
    return (_db.select(_db.medicationLogs)
          ..where(
            (t) => t.deletedAt.isNull() & t.takenAt.isBiggerOrEqualValue(from),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]))
        .get();
  }

  @override
  Future<List<MedicationLog>> listForEpisode(String episodeId) {
    return (_db.select(_db.medicationLogs)
          ..where((t) => t.deletedAt.isNull() & t.episodeId.equals(episodeId))
          ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]))
        .get();
  }

  @override
  Future<List<MedicationLog>> listForMedication(String medicationId) {
    return (_db.select(_db.medicationLogs)
          ..where(
            (t) => t.deletedAt.isNull() & t.medicationId.equals(medicationId),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.takenAt)]))
        .get();
  }

  @override
  Future<void> softDelete(String id) async {
    final now = _clock();
    await (_db.update(_db.medicationLogs)..where((t) => t.id.equals(id)))
        .write(MedicationLogsCompanion(
      deletedAt: Value(now),
      updatedAt: Value(now),
    ));
  }
}
