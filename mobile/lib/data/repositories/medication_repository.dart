import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/enums.dart';
import 'support.dart';

/// Tekrarlayan ilacın gün listesi (boş/null = her gün).
List<String>? recurringDaysOf(Medication m) {
  final raw = m.recurringDays;
  if (raw == null) return null;
  return (jsonDecode(raw) as List).cast<String>();
}

/// İlaçlar ve kronik hastalıklar.
abstract class MedicationRepository {
  /// Silinmemiş tüm ilaçlar (katalog + kullanıcının kendi ilaçları), ada göre.
  Future<List<Medication>> listAvailable();
  Future<Medication?> getById(String id);

  /// Yeni ilaç ekler. Bildirim için ayrı sayısal numara atanır.
  Future<Medication> create({
    required String name,
    MedicationType type = MedicationType.symptomatic,
    bool isRecurring = false,
    String? recurringTime,
    List<String>? recurringDays,
  });

  Future<void> softDelete(String id);

  Future<ChronicCondition> createCondition({
    required String name,
    List<String> medicationIds = const [],
  });
  Future<List<ChronicCondition>> listConditions();
  Future<List<Medication>> medicationsOfCondition(String conditionId);
  Future<void> setConditionMedications(
    String conditionId,
    List<String> medicationIds,
  );
  Future<void> softDeleteCondition(String id);
}

class DriftMedicationRepository implements MedicationRepository {
  DriftMedicationRepository(this._db, {Clock? clock, IdGenerator? newId})
      : _clock = clock ?? DateTime.now,
        _newId = newId ?? newUuid;

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _newId;

  @override
  Future<List<Medication>> listAvailable() {
    return (_db.select(_db.medications)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  @override
  Future<Medication?> getById(String id) {
    return (_db.select(_db.medications)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<Medication> create({
    required String name,
    MedicationType type = MedicationType.symptomatic,
    bool isRecurring = false,
    String? recurringTime,
    List<String>? recurringDays,
  }) {
    return _db.transaction(() async {
      final now = _clock();
      final maxId = _db.medications.notificationId.max();
      final row =
          await (_db.selectOnly(_db.medications)..addColumns([maxId])).getSingle();
      final notificationId = (row.read(maxId) ?? 0) + 1;
      return _db.into(_db.medications).insertReturning(
            MedicationsCompanion.insert(
              id: _newId(),
              createdAt: now,
              updatedAt: now,
              name: name,
              type: Value(type),
              isRecurring: Value(isRecurring),
              recurringTime: Value(recurringTime),
              recurringDays: Value(
                recurringDays == null ? null : jsonEncode(recurringDays),
              ),
              notificationId: Value(notificationId),
            ),
          );
    });
  }

  @override
  Future<void> softDelete(String id) async {
    final now = _clock();
    await (_db.update(_db.medications)..where((t) => t.id.equals(id))).write(
      MedicationsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  @override
  Future<ChronicCondition> createCondition({
    required String name,
    List<String> medicationIds = const [],
  }) {
    return _db.transaction(() async {
      final now = _clock();
      final condition = await _db.into(_db.chronicConditions).insertReturning(
            ChronicConditionsCompanion.insert(
              id: _newId(),
              createdAt: now,
              updatedAt: now,
              name: name,
            ),
          );
      await setConditionMedications(condition.id, medicationIds);
      return condition;
    });
  }

  @override
  Future<List<ChronicCondition>> listConditions() {
    return (_db.select(_db.chronicConditions)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  @override
  Future<List<Medication>> medicationsOfCondition(String conditionId) {
    final query = _db.select(_db.medications).join([
      innerJoin(
        _db.conditionMedications,
        _db.conditionMedications.medicationId.equalsExp(_db.medications.id),
      ),
    ])
      ..where(
        _db.conditionMedications.conditionId.equals(conditionId) &
            _db.medications.deletedAt.isNull(),
      )
      ..orderBy([OrderingTerm.asc(_db.medications.name)]);
    return query.map((row) => row.readTable(_db.medications)).get();
  }

  @override
  Future<void> setConditionMedications(
    String conditionId,
    List<String> medicationIds,
  ) {
    return _db.transaction(() async {
      await (_db.delete(_db.conditionMedications)
            ..where((t) => t.conditionId.equals(conditionId)))
          .go();
      for (final medicationId in medicationIds.toSet()) {
        await _db.into(_db.conditionMedications).insert(
              ConditionMedicationsCompanion.insert(
                conditionId: conditionId,
                medicationId: medicationId,
              ),
            );
      }
    });
  }

  @override
  Future<void> softDeleteCondition(String id) async {
    final now = _clock();
    await (_db.update(_db.chronicConditions)..where((t) => t.id.equals(id)))
        .write(
      ChronicConditionsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }
}
