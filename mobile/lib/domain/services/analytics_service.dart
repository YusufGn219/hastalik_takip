// Analitik hesapları. Eski `services/health/analytics.py` dosyasının
// düzeltilmiş Dart karşılığıdır.
//
// Eski kodun altı tuhaflığı bilerek düzeltildi (ayrıntı ve örnekler:
// test/golden/FARKLAR.md). Doğruluk, Django'dan bağımsız yazılmış
// `scripts/golden/generate_golden_v2.py` çıktısıyla karşılaştırılarak kanıtlanır
// (test/golden/analytics_golden_test.dart).
//
//  [T1] Günler, kaydın kendi UTC farkıyla yerel güne göre gruplanır.
//  [T2] 0 geçerli bir değerdir; ortalama yalnız hiç kayıt yoksa boş.
//  [T3] Geçersiz gün adı ilaç eklenirken reddedilir (MedicationService). Eski
//       veride yine de bulunursa burada yok sayılır; kalan boşsa her gün.
//  [T4] Uyum yalnız programlı günler üzerinden; programdışı günler `extraDays`.
//  [T5] Pencere = bugün dahil son N yerel gün, gün başından.
//  [T6] Rahatlama = dozdan sonraki 2 saatte şiddetin, dozdan önceki ortalamanın
//       altına ilk indiği kayıt. "Önce" penceresi alım anını içerir, "sonra"
//       içermez. Bilinen sınır: iki doz 2 saatten yakınsa pencereleri üst üste
//       biner.
//
// Yuvarlama: yarım değer yukarı yuvarlanır (Dart `round`, pozitif sayılarda).

import '../../data/database/app_database.dart';
import '../../data/repositories/daily_log_repository.dart';
import '../../data/repositories/medication_log_repository.dart';
import '../../data/repositories/medication_repository.dart';
import '../../data/repositories/support.dart';
import '../../data/repositories/symptom_entry_repository.dart';
import '../../data/repositories/symptom_repository.dart';
import '../local_day.dart';
import '../weekdays.dart';

double _round1(double x) => (x * 10).round() / 10;

double? _avgOrNull(Iterable<num> values) {
  if (values.isEmpty) return null;
  return values.fold<double>(0, (a, b) => a + b) / values.length;
}

// ------------------------------------------------------------ sonuç türleri

class SymptomFrequency {
  const SymptomFrequency(this.symptomName, this.count, this.avgSeverity);
  final String symptomName;
  final int count;
  final double avgSeverity;

  Map<String, dynamic> toJson() => {
        'symptom_name': symptomName,
        'count': count,
        'avg_severity': avgSeverity,
      };
}

class SeverityPoint {
  const SeverityPoint(this.date, this.avgSeverity);
  final String date;
  final double avgSeverity;

  Map<String, dynamic> toJson() =>
      {'date': date, 'avg_severity': avgSeverity};
}

class SymptomAnalytics {
  const SymptomAnalytics(this.periodDays, this.frequency, this.severityTrend);
  final int periodDays;
  final List<SymptomFrequency> frequency;
  final List<SeverityPoint> severityTrend;

  Map<String, dynamic> toJson() => {
        'period_days': periodDays,
        'symptom_frequency': frequency.map((e) => e.toJson()).toList(),
        'severity_trend': severityTrend.map((e) => e.toJson()).toList(),
      };
}

class DailyTrendPoint {
  const DailyTrendPoint(
    this.date,
    this.sleepHours,
    this.waterIntake,
    this.mood,
    this.energyLevel,
  );
  final String date;
  final double sleepHours;
  final double waterIntake;
  final int mood;
  final int energyLevel;

  Map<String, dynamic> toJson() => {
        'date': date,
        'sleep_hours': sleepHours,
        'water_intake': waterIntake,
        'mood': mood,
        'energy_level': energyLevel,
      };
}

class DailyTrends {
  const DailyTrends(this.periodDays, this.trends, this.averages);
  final int periodDays;
  final List<DailyTrendPoint> trends;

  /// Anahtarlar: sleep_hours, water_intake, mood, energy_level. Dönemde hiç
  /// kayıt yoksa değerler null.
  final Map<String, double?> averages;

  Map<String, dynamic> toJson() => {
        'period_days': periodDays,
        'trends': trends.map((e) => e.toJson()).toList(),
        'averages': averages,
      };
}

class MedicationEffectItem {
  const MedicationEffectItem({
    required this.medicationName,
    required this.usageCount,
    required this.avgSeverityBefore,
    required this.avgSeverityAfter,
    required this.avgReliefMinutes,
  });
  final String medicationName;
  final int usageCount;
  final double avgSeverityBefore;
  final double avgSeverityAfter;

  /// Rahatlama görülen dozların ortalaması; hiçbirinde görülmediyse null.
  final int? avgReliefMinutes;

  Map<String, dynamic> toJson() => {
        'medication_name': medicationName,
        'usage_count': usageCount,
        'avg_severity_before': avgSeverityBefore,
        'avg_severity_after': avgSeverityAfter,
        'avg_relief_minutes': avgReliefMinutes,
      };
}

class MedicationEffect {
  const MedicationEffect(this.periodDays, this.effects);
  final int periodDays;
  final List<MedicationEffectItem> effects;

  Map<String, dynamic> toJson() => {
        'period_days': periodDays,
        'effects': effects.map((e) => e.toJson()).toList(),
      };
}

class AdherenceItem {
  const AdherenceItem({
    required this.medicationName,
    required this.expectedDays,
    required this.takenDays,
    required this.extraDays,
    required this.missedDays,
    required this.adherenceRate,
  });
  final String medicationName;

  /// Programlı gün sayısı.
  final int expectedDays;

  /// Programlı günlerden doz alınanların sayısı.
  final int takenDays;

  /// Programda olmayan günlerden doz alınanların sayısı.
  final int extraDays;
  final int missedDays;

  /// 0–100; yalnız programlı günler üzerinden.
  final double adherenceRate;

  Map<String, dynamic> toJson() => {
        'medication_name': medicationName,
        'expected_days': expectedDays,
        'taken_days': takenDays,
        'extra_days': extraDays,
        'missed_days': missedDays,
        'adherence_rate': adherenceRate,
      };
}

class MedicationAdherence {
  const MedicationAdherence(this.periodDays, this.adherence);
  final int periodDays;
  final List<AdherenceItem> adherence;

  Map<String, dynamic> toJson() => {
        'period_days': periodDays,
        'adherence': adherence.map((e) => e.toJson()).toList(),
      };
}

// ------------------------------------------------------------------ servis

class AnalyticsService {
  /// [currentOffsetMinutes] "bugün"ün hangi yerel güne düştüğünü belirler;
  /// verilmezse [clock] değerinin cihaz UTC farkı kullanılır.
  AnalyticsService({
    required SymptomEntryRepository entries,
    required SymptomRepository symptoms,
    required MedicationLogRepository medicationLogs,
    required MedicationRepository medications,
    required DailyLogRepository dailyLogs,
    Clock? clock,
    int Function()? currentOffsetMinutes,
  })  : _entries = entries,
        _symptoms = symptoms,
        _medicationLogs = medicationLogs,
        _medications = medications,
        _dailyLogs = dailyLogs,
        _clock = clock ?? DateTime.now,
        _offset = currentOffsetMinutes;

  final SymptomEntryRepository _entries;
  final SymptomRepository _symptoms;
  final MedicationLogRepository _medicationLogs;
  final MedicationRepository _medications;
  final DailyLogRepository _dailyLogs;
  final Clock _clock;
  final int Function()? _offset;

  String _today() {
    final now = _clock();
    return localDayOf(now, _offset?.call() ?? now.timeZoneOffset.inMinutes);
  }

  /// [T5] Pencerenin ilk günü: bugün dahil son [days] gün.
  String _startDay(int days) => addDays(_today(), -(days - 1));

  /// Veritabanından geniş çekim için alt sınır; kesin süzme yerel günle yapılır.
  DateTime _fetchFrom(String startDay) =>
      parseDay(startDay).subtract(const Duration(hours: 14));

  bool _fromDay(String day, String startDay) => day.compareTo(startDay) >= 0;

  // -------------------------------------------------- semptom sıklığı/trend

  Future<SymptomAnalytics> symptomAnalytics(int days) async {
    final startDay = _startDay(days);
    final entries = (await _entries.listSince(_fetchFrom(startDay)))
        .where((e) =>
            _fromDay(localDayOf(e.timestamp, e.utcOffsetMinutes), startDay))
        .toList();

    final names = <String, String>{};
    for (final id in entries.map((e) => e.symptomId).toSet()) {
      names[id] = (await _symptoms.getById(id))?.name ?? '';
    }

    final bySymptom = <String, List<int>>{};
    for (final e in entries) {
      bySymptom.putIfAbsent(names[e.symptomId]!, () => []).add(e.severity);
    }
    final frequency = [
      for (final kv in bySymptom.entries)
        SymptomFrequency(
          kv.key,
          kv.value.length,
          _round1(_avgOrNull(kv.value)!),
        ),
    ]..sort((a, b) {
        final c = b.count.compareTo(a.count);
        return c != 0 ? c : a.symptomName.compareTo(b.symptomName);
      });

    // [T1] Kaydın kendi UTC farkıyla yerel gün.
    final byDay = <String, List<int>>{};
    for (final e in entries) {
      byDay
          .putIfAbsent(localDayOf(e.timestamp, e.utcOffsetMinutes), () => [])
          .add(e.severity);
    }
    final sortedDays = byDay.keys.toList()..sort();
    final trend = [
      for (final d in sortedDays)
        SeverityPoint(d, _round1(_avgOrNull(byDay[d]!)!)),
    ];

    return SymptomAnalytics(days, frequency, trend);
  }

  // --------------------------------------------------------- günlük eğilim

  Future<DailyTrends> dailyTrends(int days) async {
    final logs = await _dailyLogs.listInRange(_startDay(days), '9999-12-31');

    // [T2] 0 geçerli değerdir; olduğu gibi gösterilir.
    final trends = [
      for (final l in logs)
        DailyTrendPoint(
          l.logDate,
          l.sleepHours,
          l.waterIntake,
          l.mood,
          l.energyLevel,
        ),
    ];

    double? avg(Iterable<num> v) {
      final a = _avgOrNull(v);
      return a == null ? null : _round1(a);
    }

    return DailyTrends(days, trends, {
      'sleep_hours': avg(logs.map((l) => l.sleepHours)),
      'water_intake': avg(logs.map((l) => l.waterIntake)),
      'mood': avg(logs.map((l) => l.mood)),
      'energy_level': avg(logs.map((l) => l.energyLevel)),
    });
  }

  // ---------------------------------------------------------- ilaç etkisi

  Future<MedicationEffect> medicationEffect(int days) async {
    const window = Duration(hours: 2);
    final startDay = _startDay(days);
    final logs = (await _medicationLogs.listSince(_fetchFrom(startDay)))
        .where((l) =>
            l.episodeId != null &&
            _fromDay(localDayOf(l.takenAt, l.utcOffsetMinutes), startDay));

    final episodeEntries = <String, List<SymptomEntry>>{};
    final medNames = <String, String>{};
    final effects = <String, _EffectAcc>{}; // ekleme sırası korunur

    for (final log in logs) {
      final medName = medNames[log.medicationId] ??=
          (await _medications.getById(log.medicationId))?.name ?? '';
      final all = episodeEntries[log.episodeId!] ??=
          await _entries.listForEpisode(log.episodeId!);
      final taken = log.takenAt;

      // [T6] "önce" alım anını içerir, "sonra" içermez.
      final before = all.where((e) =>
          !e.timestamp.isBefore(taken.subtract(window)) &&
          !e.timestamp.isAfter(taken));
      final after = all
          .where((e) =>
              e.timestamp.isAfter(taken) &&
              !e.timestamp.isAfter(taken.add(window)))
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      if (before.isEmpty || after.isEmpty) continue;

      final beforeAvg = _avgOrNull(before.map((e) => e.severity))!;
      final afterAvg = _avgOrNull(after.map((e) => e.severity))!;

      // [T6] İlk gerçek düşüş: şiddet önceki ortalamanın altına inince.
      int? relief;
      for (final e in after) {
        if (e.severity < beforeAvg) {
          relief =
              (e.timestamp.difference(taken).inSeconds / 60).truncate();
          break;
        }
      }

      final acc = effects.putIfAbsent(medName, _EffectAcc.new);
      acc.usage++;
      acc.before.add(beforeAvg);
      acc.after.add(afterAvg);
      if (relief != null) acc.relief.add(relief);
    }

    return MedicationEffect(days, [
      for (final kv in effects.entries)
        MedicationEffectItem(
          medicationName: kv.key,
          usageCount: kv.value.usage,
          avgSeverityBefore: _round1(_avgOrNull(kv.value.before)!),
          avgSeverityAfter: _round1(_avgOrNull(kv.value.after)!),
          avgReliefMinutes: kv.value.relief.isEmpty
              ? null
              : _avgOrNull(kv.value.relief)!.round(),
        ),
    ]);
  }

  // ------------------------------------------------------------------ uyum

  Future<MedicationAdherence> medicationAdherence(int days) async {
    final today = _today();
    final startDay = _startDay(days);
    final allDays = <String>[];
    for (var d = startDay; d.compareTo(today) <= 0; d = addDays(d, 1)) {
      allDays.add(d);
    }

    final recurring =
        (await _medications.listAvailable()).where((m) => m.isRecurring);
    final logs = await _medicationLogs.listSince(_fetchFrom(startDay));

    final result = <AdherenceItem>[];
    for (final med in recurring) {
      // [T3] Geçersiz ad (yeni kayıtta olamaz) yok sayılır; boşsa her gün.
      final allowed = <int>{
        for (final d in recurringDaysOf(med) ?? const <String>[])
          if (weekdayIndex.containsKey(d)) weekdayIndex[d]!,
      };
      bool scheduled(String day) =>
          allowed.isEmpty || allowed.contains(parseDay(day).weekday - 1);

      final expected = allDays.where(scheduled).length;
      if (expected == 0) continue;

      // [T4] Alınan günler yerel gün, kaydın kendi farkıyla; programlı olanlar
      // "alınan", olmayanlar "ekstra".
      final takenDays = <String>{
        for (final l in logs)
          if (l.medicationId == med.id)
            localDayOf(l.takenAt, l.utcOffsetMinutes),
      }.where((d) => _fromDay(d, startDay) && d.compareTo(today) <= 0);
      final onSchedule = takenDays.where(scheduled).length;

      result.add(AdherenceItem(
        medicationName: med.name,
        expectedDays: expected,
        takenDays: onSchedule,
        extraDays: takenDays.length - onSchedule,
        missedDays: expected - onSchedule,
        adherenceRate: _round1(onSchedule / expected * 100),
      ));
    }
    return MedicationAdherence(days, result);
  }
}

class _EffectAcc {
  int usage = 0;
  final List<double> before = [];
  final List<double> after = [];
  final List<int> relief = [];
}
