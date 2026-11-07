import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'support.dart';

/// Tekrarlayan ilacın gün listesi (boş/null = her gün).
List<String>? recurringDaysOf(Medication m) {
  final raw = m.recurringDays;
  if (raw == null) return null;
  return (jsonDecode(raw) as List).cast<String>();
}

/// Rutin ilacın doz saatleri: sıralı, tekil 'HH:mm' listesi. Kayıt virgüllü
/// liste ("08:00,20:00") ya da eski tek saat ("08:30", "08:30:00") olabilir;
/// saniye kırpılır. Saat yoksa boş liste.
List<String> recurringTimesOf(Medication m) {
  final raw = m.recurringTime;
  if (raw == null) return const [];
  final times = <String>{};
  for (final part in raw.split(',')) {
    final t = part.trim();
    if (t.isEmpty) continue;
    times.add(t.length > 5 ? t.substring(0, 5) : t);
  }
  return times.toList()..sort();
}

/// İlaçlar ve kronik hastalıklar.
abstract class MedicationRepository {
  /// Silinmemiş tüm ilaçlar (katalog + kullanıcının kendi ilaçları), ada göre.
  Future<List<Medication>> listAvailable();
  Future<Medication?> getById(String id);

  /// Yeni ilaç ekler. Bildirim için ayrı sayısal numara atanır. [categoryId]
  /// verilirse kategorinin var olup olmadığı burada denetlenmez (servis denetler).
  Future<Medication> create({
    required String name,
    String? categoryId,
    bool isRecurring = false,
    String? recurringTime,
    List<String>? recurringDays,
  });

  Future<void> softDelete(String id);

  /// Silinmemiş kategoriler, ada göre (ikili sıra; Türkçe sıralama üst katmanda).
  Future<List<MedicationCategory>> listCategories();

  /// Silinmiş olsa bile kaydı verir (yoksa null); silinmiş mi diye bakmak
  /// çağıranın işidir.
  Future<MedicationCategory?> getCategory(String id);

  Future<MedicationCategory> createCategory(String name);

  Future<void> renameCategory(String id, String name);

  /// Kategoriyi siler (silme işareti) ve ona bağlı ilaçları kategorisiz bırakır;
  /// ilaçların kendisi silinmez. İkisi tek işlemde yapılır.
  Future<void> softDeleteCategory(String id);

  /// İlacın kategorisini değiştirir; [categoryId] null ise kategorisiz yapar.
  Future<void> setMedicationCategory(String medicationId, String? categoryId);

  /// İlacın rutin (tekrar) ayarını yazar. [isRecurring] false ise saat ve günler
  /// de temizlenir. Bildirim numarası ve diğer alanlar değişmez.
  Future<void> setRecurrence(
    String medicationId, {
    required bool isRecurring,
    String? recurringTime,
    List<String>? recurringDays,
  });

  Future<ChronicCondition> createCondition({
    required String name,
    List<String> medicationIds = const [],
  });
  Future<List<ChronicCondition>> listConditions();

  /// Silinmiş olsa bile kaydı verir (yoksa null).
  Future<ChronicCondition?> getCondition(String id);

  Future<void> renameCondition(String id, String name);
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
    String? categoryId,
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
              categoryId: Value(categoryId),
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
  Future<List<MedicationCategory>> listCategories() {
    return (_db.select(_db.medicationCategories)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  @override
  Future<MedicationCategory?> getCategory(String id) {
    return (_db.select(_db.medicationCategories)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<MedicationCategory> createCategory(String name) {
    final now = _clock();
    return _db.into(_db.medicationCategories).insertReturning(
          MedicationCategoriesCompanion.insert(
            id: _newId(),
            createdAt: now,
            updatedAt: now,
            name: name,
          ),
        );
  }

  @override
  Future<void> renameCategory(String id, String name) async {
    await (_db.update(_db.medicationCategories)..where((t) => t.id.equals(id)))
        .write(
      MedicationCategoriesCompanion(
        name: Value(name),
        updatedAt: Value(_clock()),
      ),
    );
  }

  @override
  Future<void> softDeleteCategory(String id) {
    return _db.transaction(() async {
      final now = _clock();
      await (_db.update(_db.medications)..where((t) => t.categoryId.equals(id)))
          .write(
        MedicationsCompanion(
          categoryId: const Value(null),
          updatedAt: Value(now),
        ),
      );
      await (_db.update(_db.medicationCategories)
            ..where((t) => t.id.equals(id)))
          .write(
        MedicationCategoriesCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    });
  }

  @override
  Future<void> setMedicationCategory(
    String medicationId,
    String? categoryId,
  ) async {
    await (_db.update(_db.medications)..where((t) => t.id.equals(medicationId)))
        .write(
      MedicationsCompanion(
        categoryId: Value(categoryId),
        updatedAt: Value(_clock()),
      ),
    );
  }

  @override
  Future<void> setRecurrence(
    String medicationId, {
    required bool isRecurring,
    String? recurringTime,
    List<String>? recurringDays,
  }) async {
    await (_db.update(_db.medications)..where((t) => t.id.equals(medicationId)))
        .write(
      MedicationsCompanion(
        isRecurring: Value(isRecurring),
        recurringTime: Value(isRecurring ? recurringTime : null),
        recurringDays: Value(
          isRecurring && recurringDays != null
              ? jsonEncode(recurringDays)
              : null,
        ),
        updatedAt: Value(_clock()),
      ),
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
  Future<ChronicCondition?> getCondition(String id) {
    return (_db.select(_db.chronicConditions)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<void> renameCondition(String id, String name) async {
    await (_db.update(_db.chronicConditions)..where((t) => t.id.equals(id)))
        .write(
      ChronicConditionsCompanion(
        name: Value(name),
        updatedAt: Value(_clock()),
      ),
    );
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
