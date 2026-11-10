// Sağlık ölçümlerinin gösterim yardımcıları: tür/bağlam adları ve sayı biçimi.
// Ekran ve zaman çizelgesi aynı biçimi kullanır. Değerler veritabanında temel
// birimdedir; gösterimde seçili birime çevrilir.

import 'package:intl/intl.dart';

import '../../data/database/app_database.dart';
import '../../data/database/enums.dart';
import '../../domain/reading_catalog.dart';
import '../../l10n/app_localizations.dart';

String readingTypeName(AppLocalizations l10n, String type) => switch (type) {
  MeasurementTypes.bloodPressure => l10n.readingTypeBloodPressure,
  MeasurementTypes.pulse => l10n.readingTypePulse,
  MeasurementTypes.bloodGlucose => l10n.readingTypeGlucose,
  _ => type,
};

String readingContextName(AppLocalizations l10n, String code) => switch (code) {
  ReadingContexts.fasting => l10n.readingContextFasting,
  ReadingContexts.afterMeal => l10n.readingContextAfterMeal,
  ReadingContexts.beforeSleep => l10n.readingContextBeforeSleep,
  ReadingContexts.other => l10n.readingContextOther,
  _ => code,
};

/// [value] sayısını birimin ondalık basamağıyla yazar (binlik ayırıcı yok;
/// geri okunabilir: virgül ya da nokta).
String formatReadingNumber(double value, ReadingUnit unit, String locale) {
  final pattern = unit.decimals == 0 ? '0' : '0.${'0' * unit.decimals}';
  return NumberFormat(pattern, locale).format(value);
}

/// Ölçümün değeri [unitCode] biriminde, birimsiz: "120/80", "99", "5,5".
String formatReadingValue(
  ReadingKind kind,
  Measurement m,
  String unitCode,
  String locale,
) {
  final unit = kind.unitOf(unitCode);
  final first = formatReadingNumber(kind.fromBase(m.value, unitCode), unit, locale);
  final second = m.value2;
  if (kind.hasSecond && second != null) {
    return '$first/${formatReadingNumber(kind.fromBase(second, unitCode), unit, locale)}';
  }
  return first;
}

/// Ölçümün kendi yerel saati ('HH:mm'); kayıt anındaki UTC farkıyla.
String readingClock(Measurement m, String locale) => DateFormat.Hm(
  locale,
).format(m.measuredAt.toUtc().add(Duration(minutes: m.utcOffsetMinutes)));

/// 'YYYY-MM-DD' gününü yerel `DateTime`'a çevirir (biçimlemek için).
DateTime readingDay(String day) {
  final p = day.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}
