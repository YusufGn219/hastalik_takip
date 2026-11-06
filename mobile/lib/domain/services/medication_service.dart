// İlaç kuralları: eski `services/health/medication.py` portu.

import '../../data/database/app_database.dart';
import '../../data/database/enums.dart';
import '../../data/repositories/medication_log_repository.dart';
import '../../data/repositories/medication_repository.dart';
import '../../core/utils/turkish_text.dart';
import '../errors.dart';
import '../local_day.dart';
import '../weekdays.dart';

/// Kronik hastalık ve ona bağlı (silinmemiş) ilaçlar.
class ConditionSummary {
  const ConditionSummary(this.condition, this.medications);

  final ChronicCondition condition;
  final List<Medication> medications;
}

class MedicationService {
  MedicationService({
    required MedicationRepository medications,
    required MedicationLogRepository logs,
  })  : _medications = medications,
        _logs = logs;

  final MedicationRepository _medications;
  final MedicationLogRepository _logs;

  /// Kullanılabilir ilaçlar (katalog + kullanıcının kendi ilaçları).
  Future<List<Medication>> available() => _medications.listAvailable();

  /// Yeni ilaç ekler. [recurringDays] yalnız geçerli gün adları içerebilir
  /// ([weekdayKeys]); aksi halde [RuleViolation] fırlatılır. Tekrarlar tek
  /// sayılır. Boş liste ya da null "her gün" demektir ve null saklanır.
  Future<Medication> create({
    required String name,
    String? categoryId,
    bool isRecurring = false,
    String? recurringTime,
    List<String>? recurringDays,
  }) async {
    if (categoryId != null) await _requireCategory(categoryId);
    List<String>? days;
    if (recurringDays != null) {
      for (final d in recurringDays) {
        if (!weekdayIndex.containsKey(d)) {
          throw RuleViolation(
            RuleCodes.invalidRecurringDay,
            'Geçersiz gün adı: $d',
          );
        }
      }
      final unique = recurringDays.toSet();
      days = unique.isEmpty
          ? null
          : (weekdayKeys.where(unique.contains).toList());
    }
    return _medications.create(
      name: name,
      categoryId: categoryId,
      isRecurring: isRecurring,
      recurringTime: recurringTime,
      recurringDays: days,
    );
  }

  // ------------------------------------------------------- kronik hastalık

  static const _maxConditionNameLength = 200;

  /// Silinmemiş kronik hastalıklar ve ilaçları; ikisi de Türkçe sıralı.
  Future<List<ConditionSummary>> conditions() async {
    final list = await _medications.listConditions();
    list.sort((a, b) => compareTr(a.name, b.name));
    final result = <ConditionSummary>[];
    for (final c in list) {
      final meds = await _medications.medicationsOfCondition(c.id)
        ..sort((a, b) => compareTr(a.name, b.name));
      result.add(ConditionSummary(c, meds));
    }
    return result;
  }

  /// Yeni kronik hastalık ekler. Ad kırpılır; boş, 200 karakterden uzun ya da
  /// var olan bir adla (harf farkı gözetmeden) aynıysa; ilaçlardan biri yoksa ya
  /// da silinmişse [RuleViolation] fırlatılır. Hiçbir şey yazılmadan önce
  /// denetlenir.
  Future<ChronicCondition> createCondition({
    required String name,
    List<String> medicationIds = const [],
  }) async {
    final clean = await _validConditionName(name);
    await _requireMedications(medicationIds);
    return _medications.createCondition(
      name: clean,
      medicationIds: medicationIds,
    );
  }

  /// Adı ve ilaç listesini birlikte günceller (aynı denetimler; kendi adı serbest).
  Future<void> updateCondition({
    required String id,
    required String name,
    required List<String> medicationIds,
  }) async {
    await _requireCondition(id);
    final clean = await _validConditionName(name, exceptId: id);
    await _requireMedications(medicationIds);
    await _medications.renameCondition(id, clean);
    await _medications.setConditionMedications(id, medicationIds);
  }

  /// Hastalığı siler (silme işareti). İlaçlar ve eski alım kayıtları kalır.
  Future<void> deleteCondition(String id) async {
    await _requireCondition(id);
    await _medications.softDeleteCondition(id);
  }

  Future<void> _requireCondition(String id) async {
    final c = await _medications.getCondition(id);
    if (c == null || c.deletedAt != null) {
      throw const RuleViolation(
        RuleCodes.conditionNotFound,
        'Kronik hastalık bulunamadı.',
      );
    }
  }

  Future<void> _requireMedications(List<String> ids) async {
    for (final id in ids.toSet()) {
      final m = await _medications.getById(id);
      if (m == null || m.deletedAt != null) {
        throw const RuleViolation(
          RuleCodes.medicationNotFound,
          'İlaç bulunamadı.',
        );
      }
    }
  }

  Future<String> _validConditionName(String name, {String? exceptId}) async {
    final clean = name.trim();
    if (clean.isEmpty) {
      throw const RuleViolation(
        RuleCodes.conditionNameEmpty,
        'Hastalık adı boş olamaz.',
      );
    }
    if (clean.length > _maxConditionNameLength) {
      throw const RuleViolation(
        RuleCodes.conditionNameTooLong,
        'Hastalık adı en çok $_maxConditionNameLength karakter olabilir.',
      );
    }
    final key = foldTr(clean);
    final existing = await _medications.listConditions();
    if (existing.any((c) => c.id != exceptId && foldTr(c.name) == key)) {
      throw const RuleViolation(
        RuleCodes.conditionNameExists,
        'Bu adla bir kronik hastalık zaten var.',
      );
    }
    return clean;
  }

  // ------------------------------------------------------------ kategori

  static const _maxCategoryNameLength = 100;

  /// Silinmemiş kategoriler, Türkçe sıralı.
  Future<List<MedicationCategory>> categories() async {
    final list = await _medications.listCategories();
    return list..sort((a, b) => compareTr(a.name, b.name));
  }

  /// Yeni kategori ekler. Ad kırpılır; boş, 100 karakterden uzun ya da var olan
  /// bir adla (büyük/küçük harf ve Türkçe harf farkı gözetmeden) aynıysa
  /// [RuleViolation] fırlatılır.
  Future<MedicationCategory> createCategory(String name) async {
    final clean = await _validCategoryName(name);
    return _medications.createCategory(clean);
  }

  Future<void> renameCategory(String id, String name) async {
    await _requireCategory(id);
    final clean = await _validCategoryName(name, exceptId: id);
    await _medications.renameCategory(id, clean);
  }

  /// Kategoriyi siler; ilaçlar silinmez, kategorisiz kalır.
  Future<void> deleteCategory(String id) async {
    await _requireCategory(id);
    await _medications.softDeleteCategory(id);
  }

  /// İlacın kategorisini değiştirir; [categoryId] null ise kategorisiz yapar.
  Future<void> setCategory(String medicationId, String? categoryId) async {
    final med = await _medications.getById(medicationId);
    if (med == null || med.deletedAt != null) {
      throw const RuleViolation(
        RuleCodes.medicationNotFound,
        'İlaç bulunamadı.',
      );
    }
    if (categoryId != null) await _requireCategory(categoryId);
    await _medications.setMedicationCategory(medicationId, categoryId);
  }

  Future<void> _requireCategory(String id) async {
    final c = await _medications.getCategory(id);
    if (c == null || c.deletedAt != null) {
      throw const RuleViolation(
        RuleCodes.categoryNotFound,
        'Kategori bulunamadı.',
      );
    }
  }

  Future<String> _validCategoryName(String name, {String? exceptId}) async {
    final clean = name.trim();
    if (clean.isEmpty) {
      throw const RuleViolation(
        RuleCodes.categoryNameEmpty,
        'Kategori adı boş olamaz.',
      );
    }
    if (clean.length > _maxCategoryNameLength) {
      throw const RuleViolation(
        RuleCodes.categoryNameTooLong,
        'Kategori adı en çok $_maxCategoryNameLength karakter olabilir.',
      );
    }
    final key = foldTr(clean);
    final existing = await _medications.listCategories();
    if (existing.any((c) => c.id != exceptId && foldTr(c.name) == key)) {
      throw const RuleViolation(
        RuleCodes.categoryNameExists,
        'Bu adla bir kategori zaten var.',
      );
    }
    return clean;
  }

  /// İlaç alımı kaydeder. Atak ve kronik hastalık aynı anda dolu olamaz.
  Future<MedicationLog> logIntake({
    required String medicationId,
    required DateTime takenAt,
    double? doseAmount,
    DoseUnit doseUnit = DoseUnit.tablet,
    String? episodeId,
    String? conditionId,
    String notes = '',
  }) async {
    if (episodeId != null && conditionId != null) {
      throw const RuleViolation(
        RuleCodes.episodeAndConditionBoth,
        'Atak ve kronik hastalık aynı anda doldurulamaz.',
      );
    }
    return _logs.create(
      medicationId: medicationId,
      takenAt: takenAt,
      doseAmount: doseAmount,
      doseUnit: doseUnit,
      episodeId: episodeId,
      conditionId: conditionId,
      notes: notes,
    );
  }

  /// Yerel [day] gününde alınan ilaçlar, eskiden yeniye.
  Future<List<MedicationLog>> logsForDay(String day) async {
    final w = utcWindowForLocalDay(day);
    final candidates = await _logs.listInRange(w.from, w.to);
    final result = candidates
        .where((l) => localDayOf(l.takenAt, l.utcOffsetMinutes) == day)
        .toList()
      ..sort((a, b) => a.takenAt.compareTo(b.takenAt));
    return result;
  }
}
