// Ek günlük alanların (kafein, spor, ağrı düzeyi, kendi alanları) analizi.
//
// `AnalyticsService` ve altın veri testleri bilerek ayrı tutuldu: çekirdek
// dört alanın hesabı değişmez. Burada her alanın dönem içindeki değerleri ve
// "semptom kaydı olan günler / olmayan günler" ortalaması hesaplanır. Bu bir
// birliktelik özetidir, nedensellik kanıtı değildir.

import '../../data/database/app_database.dart';
import '../../data/repositories/measurement_repository.dart';
import '../../data/repositories/support.dart';
import '../../data/repositories/symptom_entry_repository.dart';
import '../local_day.dart';
import 'daily_field_service.dart';

/// Bir gruptaki (ör. semptomlu günler) gün sayısı ve ortalama değer.
class FieldGroup {
  const FieldGroup(this.days, this.average);

  /// Değeri girilmiş gün sayısı.
  final int days;

  /// Ortalama; grupta gün yoksa null.
  final double? average;
}

/// Alanın semptomlu ve semptomsuz günlerdeki ortalaması.
class FieldRelation {
  const FieldRelation(this.withSymptom, this.withoutSymptom);

  final FieldGroup withSymptom;
  final FieldGroup withoutSymptom;

  /// Her iki grupta da en az [minDays] gün varsa gösterilebilir.
  bool isReliable(int minDays) =>
      withSymptom.days >= minDays && withoutSymptom.days >= minDays;
}

/// Bir alanın dönemdeki değerleri ('YYYY-MM-DD' artan; yalnız değer girilen günler).
class FieldSeries {
  const FieldSeries({
    required this.field,
    required this.dates,
    required this.values,
    required this.relation,
  });

  final DailyField field;
  final List<String> dates;
  final List<double> values;
  final FieldRelation relation;
}

class FieldAnalytics {
  const FieldAnalytics(this.periodDays, this.series);

  final int periodDays;

  /// Dönemde en az bir değeri olan alanlar (kapalılar dahil), alan sırasıyla.
  final List<FieldSeries> series;
}

class FieldAnalyticsService {
  FieldAnalyticsService({
    required DailyFieldService fields,
    required MeasurementRepository measurements,
    required SymptomEntryRepository entries,
    Clock? clock,
  })  : _fields = fields,
        _measurements = measurements,
        _entries = entries,
        _clock = clock ?? DateTime.now;

  final DailyFieldService _fields;
  final MeasurementRepository _measurements;
  final SymptomEntryRepository _entries;
  final Clock _clock;

  /// Bir ilişki satırının gösterilmesi için her grupta gereken en az gün.
  static const minRelationDays = 5;

  Future<FieldAnalytics> analyze(int days) async {
    final now = _clock();
    final today = localDayOf(now, now.timeZoneOffset.inMinutes);
    final start = addDays(today, -(days - 1));

    final entries = await _entries.listSince(
      parseDay(start).subtract(const Duration(hours: 14)),
    );
    // Pencere dışı günler zaten alan değeri aramasında yer almadığından ayrıca
    // süzülmez; geniş çekimden gelen fazla günler hesabı etkilemez.
    final symptomDays = <String>{
      for (final e in entries) localDayOf(e.timestamp, e.utcOffsetMinutes),
    };

    final result = <FieldSeries>[];
    for (final field in await _fields.list()) {
      final rows = await _measurements.listByType(
        DailyFieldService.measurementTypeOf(field),
        fromDate: start,
        toDate: today,
      );
      // Günde tek değer tutulur; yine de eski veride çift varsa sonuncusu geçerli.
      final byDay = <String, double>{};
      for (final m in rows) {
        byDay[m.logDate] = m.value;
      }
      if (byDay.isEmpty) continue;
      final dates = byDay.keys.toList()..sort();
      final values = [for (final d in dates) byDay[d]!];

      final withSymptom = <double>[];
      final without = <double>[];
      for (var i = 0; i < dates.length; i++) {
        (symptomDays.contains(dates[i]) ? withSymptom : without).add(values[i]);
      }
      result.add(
        FieldSeries(
          field: field,
          dates: dates,
          values: values,
          relation: FieldRelation(_group(withSymptom), _group(without)),
        ),
      );
    }
    return FieldAnalytics(days, result);
  }

  FieldGroup _group(List<double> v) => FieldGroup(
        v.length,
        v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length,
      );
}
