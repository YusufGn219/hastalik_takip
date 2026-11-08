// Ek günlük alanları: kafein, spor, ağrı düzeyi gibi hazır alanlar ve kullanıcının
// kendi alanları. Alan tanımı `daily_fields` tablosunda, değerler genel
// `measurements` tablosunda tutulur (günde alan başına tek değer). Alan
// kapatılınca eski değerleri silinmez. Dört çekirdek günlük alanı (uyku, su, ruh
// hali, enerji) `daily_logs` içinde kalır ve bu servisin konusu değildir.

import 'package:drift/drift.dart' show Value;

import '../../core/utils/turkish_text.dart';
import '../../data/database/app_database.dart';
import '../../data/database/enums.dart';
import '../../data/repositories/daily_field_repository.dart';
import '../../data/repositories/measurement_repository.dart';
import '../../data/repositories/support.dart';
import '../errors.dart';
import '../local_day.dart';
import 'episode_service.dart' show Transactor;

/// Bir alanın belirli bir günkü değeri (yoksa null).
class DailyFieldValue {
  const DailyFieldValue({required this.field, required this.value});

  final DailyField field;
  final double? value;
}

class DailyFieldService {
  DailyFieldService({
    required DailyFieldRepository fields,
    required MeasurementRepository measurements,
    required Clock clock,
    Transactor? transactor,
  }) : _fields = fields,
       _measurements = measurements,
       _clock = clock,
       _tx = transactor ?? _runDirect;

  final DailyFieldRepository _fields;
  final MeasurementRepository _measurements;
  final Clock _clock;
  final Transactor _tx;

  static Future<T> _runDirect<T>(Future<T> Function() action) => action();

  static const maxNameLength = 40;
  static const maxUnitLength = 12;

  /// Kullanıcının ekleyebileceği alan sayısı üst sınırı (hazır alanlar hariç).
  static const maxCustomFields = 30;

  /// En eski kabul edilen gün yılı.
  static const minYear = 1900;

  /// Sayı alanında sınır verilmezse kullanılan aralık.
  static const defaultMin = 0.0;
  static const defaultMax = 1000.0;

  /// Sınırların mutlak üst değeri.
  static const hardLimit = 1000000.0;

  /// Hazır alanlar: kapalı gelir, kullanıcı açar.
  static const presets = <DailyFieldPreset>[
    DailyFieldPreset(
      key: MeasurementTypes.caffeine,
      name: 'Kafein',
      kind: DailyFieldKinds.number,
      unit: 'bardak',
      min: 0,
      max: 20,
    ),
    DailyFieldPreset(
      key: MeasurementTypes.exercise,
      name: 'Spor',
      kind: DailyFieldKinds.number,
      unit: 'dk',
      min: 0,
      max: 1440,
    ),
    DailyFieldPreset(
      key: MeasurementTypes.pain,
      name: 'Ağrı düzeyi',
      kind: DailyFieldKinds.number,
      unit: '',
      min: 0,
      max: 10,
    ),
  ];

  /// Alanın `measurements` tablosundaki tür anahtarı.
  static String measurementTypeOf(DailyField f) =>
      f.builtinKey ?? '${MeasurementTypes.customFieldPrefix}${f.id}';

  /// Hazır alanları (yoksa) kapalı olarak ekler. Tekrar çağırmak zararsızdır.
  Future<void> ensurePresets() async {
    await _tx(() async {
      final all = await _fields.listAll();
      final existing = all.map((f) => f.builtinKey).whereType<String>().toSet();
      var order = all.fold<int>(0, (m, f) => f.sortOrder > m ? f.sortOrder : m);
      for (final p in presets) {
        if (existing.contains(p.key)) continue;
        await _fields.insert(
          name: await _freeName(all, p.name),
          kind: p.kind,
          unit: p.unit,
          minValue: p.min,
          maxValue: p.max,
          isActive: false,
          sortOrder: ++order,
          builtinKey: p.key,
        );
      }
    });
  }

  /// Hazır alanın adını kullanıcı aynı adda bir alan açtıysa çakışmasın diye
  /// sonuna ' (hazır)' ekler.
  Future<String> _freeName(List<DailyField> all, String name) async {
    final taken = all.map((f) => foldTr(f.name)).toSet();
    return taken.contains(foldTr(name)) ? '$name (hazır)' : name;
  }

  /// Tüm alanlar (kapalılar dahil), sıraya göre.
  Future<List<DailyField>> list() => _fields.listAll();

  /// Yalnız açık alanlar, sıraya göre.
  Future<List<DailyField>> listActive() async =>
      (await _fields.listAll()).where((f) => f.isActive).toList();

  /// Kullanıcının kendi alanını ekler (açık başlar).
  Future<DailyField> create({
    required String name,
    required String kind,
    String unit = '',
    double? min,
    double? max,
  }) {
    return _tx(() async {
      final all = await _fields.listAll();
      if (all.where((f) => f.builtinKey == null).length >= maxCustomFields) {
        throw const RuleViolation(
          RuleCodes.dailyFieldTooMany,
          'En çok $maxCustomFields özel alan eklenebilir.',
        );
      }
      final cleanName = _validName(name, all, exceptId: null);
      final spec = _validSpec(kind: kind, unit: unit, min: min, max: max);
      final order = all.fold<int>(0, (m, f) => f.sortOrder > m ? f.sortOrder : m);
      return _fields.insert(
        name: cleanName,
        kind: kind,
        unit: spec.unit,
        minValue: spec.min,
        maxValue: spec.max,
        isActive: true,
        sortOrder: order + 1,
      );
    });
  }

  /// Kendi alanının adını, birimini ve sınırlarını değiştirir; tür değişmez.
  /// Hazır alanda [RuleCodes.dailyFieldBuiltin]. Eski değerler sınır dışında
  /// kalsa da silinmez.
  Future<DailyField> update(
    String id, {
    required String name,
    String unit = '',
    double? min,
    double? max,
  }) {
    return _tx(() async {
      final all = await _fields.listAll();
      final field = _find(all, id);
      if (field.builtinKey != null) {
        throw const RuleViolation(
          RuleCodes.dailyFieldBuiltin,
          'Hazır alan değiştirilemez; yalnız açılıp kapatılır.',
        );
      }
      final cleanName = _validName(name, all, exceptId: id);
      final spec =
          _validSpec(kind: field.kind, unit: unit, min: min, max: max);
      return _fields.update(
        id,
        DailyFieldsCompanion(
          name: Value(cleanName),
          unit: Value(spec.unit),
          minValue: Value(spec.min),
          maxValue: Value(spec.max),
        ),
      );
    });
  }

  /// Alanı açar ya da kapatır. Kapatmak değerleri silmez.
  Future<DailyField> setActive(String id, bool active) async {
    _find(await _fields.listAll(), id);
    return _fields.update(id, DailyFieldsCompanion(isActive: Value(active)));
  }

  /// [day] ('YYYY-MM-DD') için tüm alanların değerleri (kapalılar dahil).
  Future<List<DailyFieldValue>> valuesForDay(String day) async {
    _checkDay(day, allowFuture: true);
    final fields = await _fields.listAll();
    final result = <DailyFieldValue>[];
    for (final f in fields) {
      final rows = await _measurements.listByType(
        measurementTypeOf(f),
        fromDate: day,
        toDate: day,
      );
      result.add(
        DailyFieldValue(field: f, value: rows.isEmpty ? null : rows.last.value),
      );
    }
    return result;
  }

  /// Alanın [day] günündeki değerini yazar; o güne ait eski değer yerine geçer.
  /// Kapalı alana yazılmaz ([RuleCodes.dailyFieldInactive]).
  Future<void> setValue(String fieldId, String day, double value) async {
    final measuredAt = _checkDay(day);
    await _tx(() async {
      final field = _find(await _fields.listAll(), fieldId);
      if (!field.isActive) {
        throw const RuleViolation(
          RuleCodes.dailyFieldInactive,
          'Alan kapalı; önce açın.',
        );
      }
      final v = _validValue(field, value);
      await _replace(field, day, v, measuredAt);
    });
  }

  /// Alanın [day] günündeki değerini siler (silme işaretiyle).
  Future<void> clearValue(String fieldId, String day) async {
    _checkDay(day);
    await _tx(() async {
      final field = _find(await _fields.listAll(), fieldId);
      await _clearDay(field, day);
    });
  }

  // ------------------------------------------------------------------ iç

  Future<void> _replace(
    DailyField field,
    String day,
    double value,
    DateTime measuredAt,
  ) async {
    await _clearDay(field, day);
    await _measurements.add(
      type: measurementTypeOf(field),
      value: value,
      unit: field.unit,
      measuredAt: measuredAt,
    );
  }

  Future<void> _clearDay(DailyField field, String day) async {
    final rows = await _measurements.listByType(
      measurementTypeOf(field),
      fromDate: day,
      toDate: day,
    );
    for (final r in rows) {
      await _measurements.softDelete(r.id);
    }
  }

  DailyField _find(List<DailyField> all, String id) {
    for (final f in all) {
      if (f.id == id) return f;
    }
    throw RuleViolation(RuleCodes.dailyFieldNotFound, 'Alan bulunamadı: $id');
  }

  String _validName(
    String name,
    List<DailyField> all, {
    required String? exceptId,
  }) {
    final clean = name.trim();
    if (clean.isEmpty) {
      throw const RuleViolation(
        RuleCodes.dailyFieldNameEmpty,
        'Alan adı boş olamaz.',
      );
    }
    if (clean.length > maxNameLength) {
      throw const RuleViolation(
        RuleCodes.dailyFieldNameTooLong,
        'Alan adı en çok $maxNameLength karakter olabilir.',
      );
    }
    final folded = foldTr(clean);
    for (final f in all) {
      if (f.id != exceptId && foldTr(f.name) == folded) {
        throw RuleViolation(
          RuleCodes.dailyFieldNameExists,
          'Bu adda bir alan var: $clean',
        );
      }
    }
    return clean;
  }

  ({String unit, double min, double max}) _validSpec({
    required String kind,
    required String unit,
    required double? min,
    required double? max,
  }) {
    if (!DailyFieldKinds.all.contains(kind)) {
      throw RuleViolation(
        RuleCodes.dailyFieldKindInvalid,
        'Geçersiz alan türü: $kind',
      );
    }
    if (kind == DailyFieldKinds.scale) {
      return (unit: '', min: 1, max: 5);
    }
    if (kind == DailyFieldKinds.yesNo) {
      return (unit: '', min: 0, max: 1);
    }
    final cleanUnit = unit.trim();
    if (cleanUnit.length > maxUnitLength) {
      throw const RuleViolation(
        RuleCodes.dailyFieldUnitTooLong,
        'Birim en çok $maxUnitLength karakter olabilir.',
      );
    }
    final lo = min ?? defaultMin;
    final hi = max ?? defaultMax;
    if (!lo.isFinite ||
        !hi.isFinite ||
        lo.abs() > hardLimit ||
        hi.abs() > hardLimit ||
        lo >= hi) {
      throw RuleViolation(
        RuleCodes.dailyFieldRangeInvalid,
        'Sınırlar geçersiz: $lo - $hi',
      );
    }
    return (unit: cleanUnit, min: lo, max: hi);
  }

  double _validValue(DailyField field, double value) {
    if (!value.isFinite) {
      throw RuleViolation(
        RuleCodes.dailyFieldValueInvalid,
        'Geçersiz değer: $value',
      );
    }
    var v = value;
    if (field.kind == DailyFieldKinds.scale) {
      if (v != v.roundToDouble()) {
        throw RuleViolation(
          RuleCodes.dailyFieldValueInvalid,
          'Ölçek tam sayı olmalı: $value',
        );
      }
    } else if (field.kind == DailyFieldKinds.yesNo) {
      if (v != 0 && v != 1) {
        throw RuleViolation(
          RuleCodes.dailyFieldValueInvalid,
          'Evet/hayır değeri 0 ya da 1 olmalı: $value',
        );
      }
    } else {
      v = (v * 10).roundToDouble() / 10;
    }
    if (v < field.minValue || v > field.maxValue) {
      throw RuleViolation(
        RuleCodes.dailyFieldValueInvalid,
        '${field.name} ${field.minValue}-${field.maxValue} arasında olmalı: $value',
      );
    }
    return v;
  }

  /// Günü doğrular ve ölçümün zamanını döner: bugünse şimdi, geçmiş gün için yerel
  /// öğlen. [allowFuture] yalnız okumada açıktır.
  DateTime _checkDay(String day, {bool allowFuture = false}) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(day);
    DateTime? parsed;
    if (m != null) {
      final y = int.parse(m[1]!);
      final mo = int.parse(m[2]!);
      final d = int.parse(m[3]!);
      final dt = DateTime(y, mo, d);
      if (y >= minYear && dt.year == y && dt.month == mo && dt.day == d) {
        parsed = dt;
      }
    }
    if (parsed == null) {
      throw RuleViolation(
        RuleCodes.measurementDayInvalid,
        'Geçersiz gün: $day',
      );
    }
    final now = _clock();
    final today = formatDay(now.year, now.month, now.day);
    if (!allowFuture && day.compareTo(today) > 0) {
      throw RuleViolation(
        RuleCodes.measurementDayInFuture,
        'Gelecek gün: $day',
      );
    }
    return day == today
        ? now
        : DateTime(parsed.year, parsed.month, parsed.day, 12);
  }
}

class DailyFieldPreset {
  const DailyFieldPreset({
    required this.key,
    required this.name,
    required this.kind,
    required this.unit,
    required this.min,
    required this.max,
  });

  final String key;
  final String name;
  final String kind;
  final String unit;
  final double min;
  final double max;
}
