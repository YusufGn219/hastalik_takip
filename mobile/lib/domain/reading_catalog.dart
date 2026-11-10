// Sağlık ölçümlerinin (tansiyon, nabız, kan şekeri) kodda tanımlı kataloğu.
// Kullanıcı ölçüm türü oluşturmaz; yeni tür (ateş, SpO2...) buraya bir satır
// eklenerek gelir. Veritabanında değer her zaman türün TEMEL biriminde,
// yuvarlanmadan saklanır; gösterim birimi (ör. şekerde mmol/L) yalnızca
// dönüşümdür. Etiket metinleri burada değil çeviri dosyalarında olacak; burada
// yalnızca kodlar ve evrensel birim simgeleri vardır.

import '../data/database/enums.dart';

/// Bir ölçümün gösterim/giriş birimi.
class ReadingUnit {
  const ReadingUnit(this.code, {this.factorToBase = 1, this.decimals = 0});

  /// Evrensel birim simgesi (ör. 'mg/dL'); aynı zamanda ayarda saklanan kod.
  final String code;

  /// Bu birimdeki değer × [factorToBase] = temel birimdeki değer.
  final double factorToBase;

  /// Ekranda gösterilecek ondalık basamak sayısı (saklanan değer yuvarlanmaz).
  final int decimals;
}

/// Ölçüm bağlamı kodları (`measurements.context`).
abstract final class ReadingContexts {
  static const fasting = 'fasting';
  static const afterMeal = 'after_meal';
  static const beforeSleep = 'before_sleep';
  static const other = 'other';
}

class ReadingKind {
  const ReadingKind({
    required this.type,
    required this.units,
    required this.min,
    required this.max,
    this.hasSecond = false,
    this.min2,
    this.max2,
    this.contexts = const [],
  });

  /// `MeasurementTypes` anahtarı.
  final String type;

  /// İlki temel birimdir (çarpanı 1); veritabanındaki değer bu birimdedir.
  final List<ReadingUnit> units;

  /// Temel birimde kabul edilen aralık (dahil), birinci değer için.
  final double min;
  final double max;

  /// İki sayılı ölçüm mü (tansiyon). Doluysa [min2]/[max2] ikinci değerin aralığı.
  final bool hasSecond;
  final double? min2;
  final double? max2;

  /// Kabul edilen bağlam kodları; boşsa bağlam sorulmaz.
  final List<String> contexts;

  ReadingUnit get baseUnit => units.first;

  /// [code] bu türün birimi mi.
  bool hasUnit(String code) => units.any((u) => u.code == code);

  ReadingUnit unitOf(String code) =>
      units.firstWhere((u) => u.code == code, orElse: () => throw ArgumentError('Bilinmeyen birim: $code'));

  /// [value]'yu [unit] biriminden temel birime çevirir (yuvarlamaz).
  double toBase(double value, String unit) => value * unitOf(unit).factorToBase;

  /// Temel birimdeki [base] değerini [unit] birimine çevirir (yuvarlamaz).
  double fromBase(double base, String unit) => base / unitOf(unit).factorToBase;
}

abstract final class ReadingCatalog {
  /// 1 mmol/L glikoz = 18,016 mg/dL.
  static const glucoseMgPerMmol = 18.016;

  static const bloodPressure = ReadingKind(
    type: MeasurementTypes.bloodPressure,
    units: [ReadingUnit('mmHg')],
    min: 60,
    max: 260,
    hasSecond: true,
    min2: 30,
    max2: 150,
  );

  static const pulse = ReadingKind(
    type: MeasurementTypes.pulse,
    units: [ReadingUnit('bpm')],
    min: 20,
    max: 250,
  );

  static const bloodGlucose = ReadingKind(
    type: MeasurementTypes.bloodGlucose,
    units: [
      ReadingUnit('mg/dL'),
      ReadingUnit('mmol/L', factorToBase: glucoseMgPerMmol, decimals: 1),
    ],
    min: 20,
    max: 600,
    contexts: [
      ReadingContexts.fasting,
      ReadingContexts.afterMeal,
      ReadingContexts.beforeSleep,
      ReadingContexts.other,
    ],
  );

  static const all = [bloodPressure, pulse, bloodGlucose];

  /// Türün tanımı; bilinmeyen tür için null.
  static ReadingKind? of(String type) {
    for (final kind in all) {
      if (kind.type == type) return kind;
    }
    return null;
  }
}
