// Sağlık ölçümleri (tansiyon, nabız, kan şekeri): ekleme, düzenleme, silme,
// listeleme ve gösterim birimi tercihi. Türlerin kuralları `ReadingCatalog`'tan
// gelir. Değer veritabanına her zaman türün TEMEL biriminde ve dönüşümden sonra
// yuvarlanmadan yazılır (şeker: mg/dL); kullanıcının girdiği sayı, dönüşümden
// ÖNCE girdiği birimin ondalık basamağına yuvarlanır (mmol/L 5,55 → 5,6).
// Boy-kilo (`BodyMeasurementService`) ve günlük alanlar bu serviste değildir.

import 'dart:math' as math;

import '../../data/database/app_database.dart';
import '../../data/repositories/measurement_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/support.dart';
import '../errors.dart';
import '../local_day.dart';
import '../reading_catalog.dart';

class ReadingService {
  ReadingService({
    required MeasurementRepository measurements,
    required SettingsRepository settings,
    required Clock clock,
  }) : _measurements = measurements,
       _settings = settings,
       _clock = clock;

  final MeasurementRepository _measurements;
  final SettingsRepository _settings;
  final Clock _clock;

  static const maxNoteLength = 500;

  /// Saat seçerken "şimdi"den bu kadar ileri bir an hâlâ kabul edilir.
  static const futureTolerance = Duration(minutes: 5);

  /// En eski kabul edilen ölçüm yılı.
  static const minYear = 1900;

  /// Gösterim birimi tercihinin ayar anahtarı öneki (`reading_unit:<tür>`).
  static const unitSettingPrefix = 'reading_unit:';

  /// Yeni ölçüm ekler. [value] ve [value2] [unit] biriminde girilir ([unit]
  /// boşsa temel birim). [measuredAt] boşsa şimdi. Kural ihlalinde
  /// [RuleViolation] (kodlar `RuleCodes.reading*`, gün için `measurementDay*`).
  Future<Measurement> add({
    required String type,
    required double value,
    double? value2,
    String? unit,
    String? context,
    DateTime? measuredAt,
    String? notes,
  }) {
    final kind = _kindOf(type);
    final v = _validate(
      kind,
      value: value,
      value2: value2,
      unit: unit,
      context: context,
      measuredAt: measuredAt ?? _clock(),
      notes: notes,
    );
    return _measurements.add(
      type: type,
      value: v.value,
      value2: v.value2,
      unit: kind.baseUnit.code,
      context: v.context,
      measuredAt: v.measuredAt,
      notes: v.notes,
    );
  }

  /// Var olan ölçümü değiştirir. Tür değişmez. [value2], [context] ve [notes]
  /// verilmezse boşalır; [measuredAt] verilmezse eski an kalır. Kayıt yoksa,
  /// silinmişse ya da bu servisin bir türünden değilse `readingNotFound`.
  Future<Measurement> update(
    String id, {
    required double value,
    double? value2,
    String? unit,
    String? context,
    DateTime? measuredAt,
    String? notes,
  }) async {
    final existing = await _existing(id);
    final kind = _kindOf(existing.type);
    final v = _validate(
      kind,
      value: value,
      value2: value2,
      unit: unit,
      context: context,
      measuredAt: measuredAt ?? existing.measuredAt,
      notes: notes,
    );
    final updated = await _measurements.update(
      id,
      value: v.value,
      value2: v.value2,
      unit: kind.baseUnit.code,
      context: v.context,
      measuredAt: v.measuredAt,
      notes: v.notes,
    );
    if (updated == null) throw _notFound(id);
    return updated;
  }

  /// Ölçümü siler (silme işareti). Bu servisin türlerinden biri değilse
  /// (ör. kilo) `readingNotFound`; boy-kilo kendi servisiyle silinir.
  Future<void> delete(String id) async {
    await _existing(id);
    await _measurements.softDelete(id);
  }

  /// [type] için ölçümler, en yeni önce. [fromDay]/[toDay] dahil ('YYYY-MM-DD').
  Future<List<Measurement>> list(String type, {String? fromDay, String? toDay}) async {
    _kindOf(type);
    final rows = await _measurements.listByType(type, fromDate: fromDay, toDate: toDay);
    return rows.reversed.toList();
  }

  /// Bir günün tüm sağlık ölçümleri (tüm türler), saat sırasıyla (eskiden yeniye).
  Future<List<Measurement>> listForDay(String day) async {
    final all = <Measurement>[];
    for (final kind in ReadingCatalog.all) {
      all.addAll(await _measurements.listByType(kind.type, fromDate: day, toDate: day));
    }
    all.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    return all;
  }

  /// Türün en son ölçümü (yoksa null).
  Future<Measurement?> latest(String type) {
    _kindOf(type);
    return _measurements.latest(type);
  }

  /// Türün gösterim birimi: kayıtlı tercih, yoksa ya da geçersizse temel birim.
  /// (Cihaz diline göre varsayılan, çok dilli yapı gelince eklenecek.)
  Future<String> preferredUnit(String type) async {
    final kind = _kindOf(type);
    final stored = await _settings.get('$unitSettingPrefix$type');
    return stored != null && kind.hasUnit(stored) ? stored : kind.baseUnit.code;
  }

  Future<void> setPreferredUnit(String type, String unit) async {
    final kind = _kindOf(type);
    if (!kind.hasUnit(unit)) {
      throw RuleViolation(RuleCodes.readingUnitInvalid, 'Bu tür için birim yok: $unit');
    }
    await _settings.set('$unitSettingPrefix$type', unit);
  }

  // --- iç yardımcılar ---

  ReadingKind _kindOf(String type) {
    final kind = ReadingCatalog.of(type);
    if (kind == null) {
      throw RuleViolation(RuleCodes.readingTypeUnknown, 'Bilinmeyen ölçüm türü: $type');
    }
    return kind;
  }

  RuleViolation _notFound(String id) =>
      RuleViolation(RuleCodes.readingNotFound, 'Ölçüm bulunamadı: $id');

  Future<Measurement> _existing(String id) async {
    final m = await _measurements.findById(id);
    if (m == null || ReadingCatalog.of(m.type) == null) throw _notFound(id);
    return m;
  }

  double _roundTo(double v, int decimals) {
    final f = math.pow(10, decimals).toDouble();
    return (v * f).roundToDouble() / f;
  }

  _Validated _validate(
    ReadingKind kind, {
    required double value,
    required double? value2,
    required String? unit,
    required String? context,
    required DateTime measuredAt,
    required String? notes,
  }) {
    final unitCode = (unit == null || unit.isEmpty) ? kind.baseUnit.code : unit;
    if (!kind.hasUnit(unitCode)) {
      throw RuleViolation(RuleCodes.readingUnitInvalid, '${kind.type} için birim geçersiz: $unitCode');
    }
    final unitDef = kind.unitOf(unitCode);

    if (!value.isFinite) {
      throw RuleViolation(RuleCodes.readingValueOutOfRange, 'Değer sayı değil: $value');
    }
    final base = kind.toBase(_roundTo(value, unitDef.decimals), unitCode);
    if (base < kind.min || base > kind.max) {
      throw RuleViolation(
        RuleCodes.readingValueOutOfRange,
        '${kind.type} ${kind.min}-${kind.max} ${kind.baseUnit.code} arasında olmalı: $value $unitCode',
      );
    }

    double? base2;
    if (kind.hasSecond) {
      if (value2 == null) {
        throw RuleViolation(RuleCodes.readingSecondValueRequired, '${kind.type} için ikinci değer gerekli');
      }
      if (!value2.isFinite) {
        throw RuleViolation(RuleCodes.readingSecondValueOutOfRange, 'İkinci değer sayı değil: $value2');
      }
      base2 = kind.toBase(_roundTo(value2, unitDef.decimals), unitCode);
      if (base2 < kind.min2! || base2 > kind.max2!) {
        throw RuleViolation(
          RuleCodes.readingSecondValueOutOfRange,
          '${kind.type} ikinci değer ${kind.min2}-${kind.max2} ${kind.baseUnit.code} arasında olmalı: $value2',
        );
      }
      if (base <= base2) {
        throw RuleViolation(
          RuleCodes.readingFirstNotAboveSecond,
          'Büyük değer küçük değerden yüksek olmalı: $value / $value2',
        );
      }
    } else if (value2 != null) {
      throw RuleViolation(RuleCodes.readingSecondValueNotAllowed, '${kind.type} tek değerlidir');
    }

    final ctx = (context == null || context.isEmpty) ? null : context;
    if (ctx != null && !kind.contexts.contains(ctx)) {
      throw RuleViolation(RuleCodes.readingContextInvalid, '${kind.type} için bağlam geçersiz: $ctx');
    }

    final note = notes?.trim();
    if (note != null && note.length > maxNoteLength) {
      throw RuleViolation(RuleCodes.readingNoteTooLong, 'Not en çok $maxNoteLength karakter olabilir');
    }

    final at = measuredAt.toLocal();
    if (at.year < minYear) {
      throw RuleViolation(RuleCodes.measurementDayInvalid, 'Geçersiz tarih: $at');
    }
    if (at.isAfter(_clock().add(futureTolerance))) {
      throw RuleViolation(
        RuleCodes.measurementDayInFuture,
        'Gelecek an: ${formatDay(at.year, at.month, at.day)}',
      );
    }

    return _Validated(
      value: base,
      value2: base2,
      context: ctx,
      notes: (note == null || note.isEmpty) ? null : note,
      measuredAt: at,
    );
  }
}

class _Validated {
  const _Validated({
    required this.value,
    required this.value2,
    required this.context,
    required this.notes,
    required this.measuredAt,
  });

  final double value;
  final double? value2;
  final String? context;
  final String? notes;
  final DateTime measuredAt;
}
