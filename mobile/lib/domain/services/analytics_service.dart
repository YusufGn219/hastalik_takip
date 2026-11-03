// Analitik hesapları: eski `services/health/analytics.py` dosyasının Dart portu.
//
// Amaç eşdeğerlik: aynı veriyle Python'la aynı sayıları üretmek
// (test/golden/analytics_golden_test.dart). Bu yüzden eski kodun bilinen
// tuhaflıkları BİLEREK korunmuştur; her biri aşağıda işaretlidir. Düzeltme
// kararı ayrı verilecek; verilirse burada değişir ve altın veri bilinçli olarak
// yeniden üretilir.
//
// Korunan eski davranışlar:
//  [T1] severity_trend günleri UTC takvim gününe göre gruplanır (yerel gün değil).
//  [T2] 0 değerli uyku/su "yok" (null) sayılır; ortalaması 0 çıkarsa da null.
//  [T3] Geçersiz gün adı yok sayılır; hiç geçerli gün kalmazsa ilaç her gün
//       beklenir.
//  [T4] Uyum: izin verilen günler dışında alınan dozlar da "alınan gün" sayılır.
//  [T5] Pencere başlangıcı dahildir (>=); gün sınırları UTC "şimdi"ye göre.
//  [T6] İlaç etkisi: "önce" penceresi alım anını içerir, "sonra" içermez.

import '../../data/database/app_database.dart';
import '../../data/repositories/daily_log_repository.dart';
import '../../data/repositories/medication_log_repository.dart';
import '../../data/repositories/medication_repository.dart';
import '../../data/repositories/support.dart';
import '../../data/repositories/symptom_entry_repository.dart';
import '../../data/repositories/symptom_repository.dart';
import '../local_day.dart';

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
  final double? sleepHours;
  final double? waterIntake;
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

  /// Anahtarlar: sleep_hours, water_intake, mood, energy_level.
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
    required this.missedDays,
    required this.adherenceRate,
  });
  final String medicationName;
  final int expectedDays;
  final int takenDays;
  final int missedDays;
  final double adherenceRate;

  Map<String, dynamic> toJson() => {
        'medication_name': medicationName,
        'expected_days': expectedDays,
        'taken_days': takenDays,
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
  AnalyticsService({
    required SymptomEntryRepository entries,
    required SymptomRepository symptoms,
    required MedicationLogRepository medicationLogs,
    required MedicationRepository medications,
    required DailyLogRepository dailyLogs,
    Clock? clock,
  })  : _entries = entries,
        _symptoms = symptoms,
        _medicationLogs = medicationLogs,
        _medications = medications,
        _dailyLogs = dailyLogs,
        _clock = clock ?? DateTime.now;

  final SymptomEntryRepository _entries;
  final SymptomRepository _symptoms;
  final MedicationLogRepository _medicationLogs;
  final MedicationRepository _medications;
  final DailyLogRepository _dailyLogs;
  final Clock _clock;

  /// Pencere başlangıcı: şimdi − [days] gün (an olarak).
  DateTime _windowStart(int days) =>
      _clock().toUtc().subtract(Duration(days: days));

  // -------------------------------------------------- semptom sıklığı/trend

  Future<SymptomAnalytics> symptomAnalytics(int days) async {
    final entries = await _entries.listSince(_windowStart(days));

    final names = <String, String>{};
    for (final id in entries.map((e) => e.symptomId).toSet()) {
      final s = await _symptoms.getById(id);
      names[id] = s?.name ?? '';
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

    // [T1] UTC takvim günü.
    final byDay = <String, List<int>>{};
    for (final e in entries) {
      byDay.putIfAbsent(utcDayOf(e.timestamp), () => []).add(e.severity);
    }
    final days_ = byDay.keys.toList()..sort();
    final trend = [
      for (final d in days_) SeverityPoint(d, _round1(_avgOrNull(byDay[d]!)!)),
    ];

    return SymptomAnalytics(days, frequency, trend);
  }

  // --------------------------------------------------------- günlük eğilim

  Future<DailyTrends> dailyTrends(int days) async {
    // [T5] başlangıç günü UTC "şimdi − days" gününün tarihi.
    final startDay = utcDayOf(_windowStart(days));
    final logs = await _dailyLogs.listInRange(startDay, '9999-12-31');

    // [T2] 0 → null.
    double? orNull(double v) => v == 0 ? null : v;
    final trends = [
      for (final l in logs)
        DailyTrendPoint(
          l.logDate,
          orNull(l.sleepHours),
          orNull(l.waterIntake),
          l.mood,
          l.energyLevel,
        ),
    ];

    double? avg(Iterable<num> v) {
      final a = _avgOrNull(v);
      return (a == null || a == 0) ? null : _round1(a);
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
    final logs = (await _medicationLogs.listSince(_windowStart(days)))
        .where((l) => l.episodeId != null);

    final episodeEntries = <String, List<SymptomEntry>>{};
    final medNames = <String, String>{};
    final effects = <String, _EffectAcc>{}; // ekleme sırası korunur

    for (final log in logs) {
      final medName = medNames[log.medicationId] ??=
          (await _medications.getById(log.medicationId))?.name ?? '';
      final all = episodeEntries[log.episodeId!] ??=
          await _entries.listForEpisode(log.episodeId!);
      final taken = log.takenAt;

      // [T6]
      final before = all.where((e) =>
          !e.timestamp.isBefore(taken.subtract(window)) &&
          !e.timestamp.isAfter(taken));
      final after = all.where((e) =>
          e.timestamp.isAfter(taken) &&
          !e.timestamp.isAfter(taken.add(window)));
      if (before.isEmpty || after.isEmpty) continue;

      final first = after.reduce(
        (a, b) => b.timestamp.isBefore(a.timestamp) ? b : a,
      );
      final relief = (first.timestamp.difference(taken).inSeconds / 60).truncate();

      final acc = effects.putIfAbsent(medName, _EffectAcc.new);
      acc.usage++;
      acc.before.add(_avgOrNull(before.map((e) => e.severity))!);
      acc.after.add(_avgOrNull(after.map((e) => e.severity))!);
      acc.relief.add(relief);
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

  static const _dayIndex = {
    'monday': 0,
    'tuesday': 1,
    'wednesday': 2,
    'thursday': 3,
    'friday': 4,
    'saturday': 5,
    'sunday': 6,
  };

  Future<MedicationAdherence> medicationAdherence(int days) async {
    final now = _clock().toUtc();
    final startDay = utcDayOf(_windowStart(days));
    final todayDay = utcDayOf(now);
    final start = parseDay(startDay);
    final today = parseDay(todayDay);

    final recurring =
        (await _medications.listAvailable()).where((m) => m.isRecurring);
    final logs = await _medicationLogs.listSince(
      start.subtract(const Duration(hours: 14)),
    );

    final result = <AdherenceItem>[];
    for (final med in recurring) {
      // [T3]
      final allowed = [
        for (final d in recurringDaysOf(med) ?? const <String>[])
          if (_dayIndex.containsKey(d)) _dayIndex[d]!,
      ];

      var expected = 0;
      for (var cur = start;
          !cur.isAfter(today);
          cur = DateTime.utc(cur.year, cur.month, cur.day + 1)) {
        if (allowed.isEmpty || allowed.contains(cur.weekday - 1)) expected++;
      }
      if (expected == 0) continue;

      // [T4] Yerel gün, kaydın kendi UTC farkıyla.
      final takenDays = <String>{
        for (final l in logs)
          if (l.medicationId == med.id)
            localDayOf(l.takenAt, l.utcOffsetMinutes),
      }.where((d) => d.compareTo(startDay) >= 0 && d.compareTo(todayDay) <= 0);
      final taken = takenDays.length;

      result.add(AdherenceItem(
        medicationName: med.name,
        expectedDays: expected,
        takenDays: taken,
        missedDays: expected - taken < 0 ? 0 : expected - taken,
        adherenceRate: _round1(taken / expected * 100),
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
