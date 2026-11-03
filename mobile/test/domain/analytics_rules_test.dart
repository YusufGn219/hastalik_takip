// Analitik düzeltmelerinin (T1–T6) tek tek kuralları. Altın veri bütün çıktıyı
// bağımsız hesapla doğrular; bu dosya her kuralı konuşulan örnekle sabitler.

import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/seed_loader.dart';
import 'package:mobile/data/repositories/daily_log_repository.dart';
import 'package:mobile/data/repositories/medication_log_repository.dart';
import 'package:mobile/data/repositories/medication_repository.dart';
import 'package:mobile/data/repositories/symptom_entry_repository.dart';
import 'package:mobile/data/repositories/symptom_repository.dart';
import 'package:mobile/domain/errors.dart';
import 'package:mobile/domain/services/analytics_service.dart';
import 'package:mobile/domain/services/medication_service.dart';

import '../data/test_support.dart';

const _offset = 180; // UTC+3

void main() {
  late AppDatabase db;
  late DriftMedicationRepository medications;
  late MedicationService medicationService;
  late AnalyticsService Function(DateTime now) analyticsAt;
  final headache = SeedLoader.symptomId('headache');
  final base = utc(2026, 1, 1);

  // 2026-11-01 Pazar, 13:00 yerel.
  final now = utc(2026, 11, 1, 10);

  setUp(() async {
    db = createTestDb();
    await seedLoaderFor(db).seedIfNeeded();
    medications = DriftMedicationRepository(db);
    medicationService = MedicationService(
      medications: medications,
      logs: DriftMedicationLogRepository(db),
    );
    analyticsAt = (t) => AnalyticsService(
          entries: DriftSymptomEntryRepository(db),
          symptoms: DriftSymptomRepository(db),
          medicationLogs: DriftMedicationLogRepository(db),
          medications: medications,
          dailyLogs: DriftDailyLogRepository(db),
          clock: () => t,
          currentOffsetMinutes: () => _offset,
        );
  });
  tearDown(() => db.close());

  var seq = 0;
  String id(String p) => '$p-${++seq}';

  Future<void> addEntry(DateTime at, int severity, {String? episodeId}) =>
      db.into(db.symptomEntries).insert(SymptomEntriesCompanion.insert(
            id: id('se'),
            createdAt: base,
            updatedAt: base,
            symptomId: headache,
            episodeId: Value(episodeId),
            severity: severity,
            timestamp: at,
            utcOffsetMinutes: _offset,
          ));

  Future<String> addEpisode(DateTime start) async {
    final eid = id('ep');
    await db.into(db.episodes).insert(EpisodesCompanion.insert(
          id: eid,
          createdAt: base,
          updatedAt: base,
          symptomId: headache,
          startTime: start,
          startUtcOffsetMinutes: _offset,
        ));
    return eid;
  }

  Future<void> addDose(String medId, DateTime at, {String? episodeId}) =>
      db.into(db.medicationLogs).insert(MedicationLogsCompanion.insert(
            id: id('ml'),
            createdAt: base,
            updatedAt: base,
            medicationId: medId,
            takenAt: at,
            utcOffsetMinutes: _offset,
            episodeId: Value(episodeId),
          ));

  Future<void> addDaily(String day, double sleep, double water) =>
      db.into(db.dailyLogs).insert(DailyLogsCompanion.insert(
            id: id('dl'),
            createdAt: base,
            updatedAt: base,
            logDate: day,
            sleepHours: sleep,
            waterIntake: water,
            mood: 3,
            energyLevel: 3,
          ));

  group('T1 — yerel gün', () {
    test('gece 01:30 (UTC 22:30) kaydı yerel günün noktasına yazılır', () async {
      await addEntry(utc(2026, 10, 31, 22, 30), 8); // yerelde 1 Kasım 01:30
      await addEntry(utc(2026, 11, 1, 6), 4); // yerelde 1 Kasım 09:00

      final r = await analyticsAt(now).symptomAnalytics(7);
      expect(r.severityTrend.map((p) => p.date), ['2026-11-01']);
      expect(r.severityTrend.single.avgSeverity, 6.0);
    });
  });

  group('T2 — sıfır geçerli değer', () {
    test('su 0 gösterilir, ortalamaya girer, null olmaz', () async {
      await addDaily('2026-10-31', 8, 0);
      await addDaily('2026-11-01', 6, 2);

      final r = await analyticsAt(now).dailyTrends(7);
      expect(r.trends.first.waterIntake, 0.0);
      expect(r.averages['water_intake'], 1.0);
    });

    test('hiç kayıt yoksa ortalamalar boş', () async {
      final r = await analyticsAt(now).dailyTrends(7);
      expect(r.trends, isEmpty);
      expect(r.averages.values, everyElement(isNull));
    });
  });

  group('T3 — gün adı doğrulama', () {
    test('geçersiz ad reddedilir, kayıt oluşmaz', () async {
      await expectLater(
        medicationService.create(
          name: 'Deneme',
          isRecurring: true,
          recurringDays: ['monday', 'funday'],
        ),
        throwsA(isA<RuleViolation>().having(
            (e) => e.code, 'code', RuleCodes.invalidRecurringDay)),
      );
      expect(
        (await medications.listAvailable()).where((m) => m.name == 'Deneme'),
        isEmpty,
      );
    });

    test('tekrarlar tek sayılır, hafta sırasına dizilir', () async {
      final m = await medicationService.create(
        name: 'Deneme',
        isRecurring: true,
        recurringDays: ['friday', 'monday', 'friday'],
      );
      expect(jsonDecode(m.recurringDays!), ['monday', 'friday']);
    });

    test('boş liste "her gün" demektir ve null saklanır', () async {
      final m = await medicationService.create(
        name: 'Deneme',
        isRecurring: true,
        recurringDays: [],
      );
      expect(m.recurringDays, isNull);
    });
  });

  group('T4 — uyum yalnız programlı günlerde', () {
    test('programdışı gün "ekstra"dır, oran şişmez', () async {
      // Pazartesi, çarşamba, cuma. 7 günlük pencere: 26 Ekim (Pzt) – 1 Kasım.
      final med = await medicationService.create(
        name: 'Hafta ici',
        isRecurring: true,
        recurringDays: ['monday', 'wednesday', 'friday'],
      );
      await addDose(med.id, utc(2026, 10, 26, 6)); // Pzt: programlı
      await addDose(med.id, utc(2026, 10, 31, 6)); // Cmt: programdışı

      final r = await analyticsAt(now).medicationAdherence(7);
      final item = r.adherence.singleWhere((a) => a.medicationName == 'Hafta ici');
      expect(item.expectedDays, 3);
      expect(item.takenDays, 1);
      expect(item.extraDays, 1);
      expect(item.missedDays, 2);
      expect(item.adherenceRate, 33.3);
    });

    test('programdışı dozlar oranı %100 üstüne çıkarmaz', () async {
      final med = await medicationService.create(
        name: 'Hafta ici',
        isRecurring: true,
        recurringDays: ['monday', 'wednesday', 'friday'],
      );
      for (final d in [26, 28, 30, 31]) {
        await addDose(med.id, utc(2026, 10, d, 6));
      }
      final r = await analyticsAt(now).medicationAdherence(7);
      final item = r.adherence.singleWhere((a) => a.medicationName == 'Hafta ici');
      expect(item.adherenceRate, 100.0);
      expect(item.extraDays, 1);
      expect(item.missedDays, 0);
    });
  });

  group('T5 — bugün dahil son N gün', () {
    test('7 günlük pencere tam 7 gün sayar', () async {
      for (var d = 24; d <= 31; d++) {
        await addDaily('2026-10-$d', 7, 2);
      }
      await addDaily('2026-11-01', 7, 2);

      final r = await analyticsAt(now).dailyTrends(7);
      expect(r.trends.map((t) => t.date), [
        '2026-10-26',
        '2026-10-27',
        '2026-10-28',
        '2026-10-29',
        '2026-10-30',
        '2026-10-31',
        '2026-11-01',
      ]);
    });

    test('her gün alınacak ilaçta beklenen gün N olur', () async {
      await medicationService.create(name: 'Vitamin', isRecurring: true);
      for (final days in [1, 7, 30]) {
        final r = await analyticsAt(now).medicationAdherence(days);
        expect(r.adherence.single.expectedDays, days);
      }
    });

    test('"bugün" yerel güne göre: UTC 22:30 yerelde ertesi gündür', () async {
      await addDaily('2026-10-31', 7, 2);
      await addDaily('2026-11-01', 7, 2);

      final r = await analyticsAt(utc(2026, 10, 31, 22, 30)).dailyTrends(1);
      expect(r.trends.map((t) => t.date), ['2026-11-01']);
    });

    test('pencere dışındaki kayıt sayılmaz, günün ilk saatindeki sayılır',
        () async {
      await addEntry(utc(2026, 10, 25, 20, 59), 9); // yerelde 25 Ekim 23:59: dışarıda
      await addEntry(utc(2026, 10, 25, 21, 0), 5); // yerelde 26 Ekim 00:00: içeride

      final r = await analyticsAt(now).symptomAnalytics(7);
      expect(r.frequency.single.count, 1);
      expect(r.frequency.single.avgSeverity, 5.0);
    });
  });

  group('T6 — rahatlama gerçek düşüşe bağlı', () {
    late String med;

    setUp(() async {
      med = (await medicationService.available()).first.id;
    });

    test('ilk kayıt kötüleşmeyse sayılmaz; 7 → 8 → 3 örneğinde 90 dakika',
        () async {
      final ep = await addEpisode(utc(2026, 10, 31, 9, 30));
      await addEntry(utc(2026, 10, 31, 9, 30), 7, episodeId: ep); // önce
      await addDose(med, utc(2026, 10, 31, 10), episodeId: ep);
      await addEntry(utc(2026, 10, 31, 10, 20), 8, episodeId: ep); // kötüleşti
      await addEntry(utc(2026, 10, 31, 11, 30), 3, episodeId: ep); // düştü

      final r = await analyticsAt(now).medicationEffect(7);
      final item = r.effects.single;
      expect(item.avgSeverityBefore, 7.0);
      expect(item.avgSeverityAfter, 5.5);
      expect(item.avgReliefMinutes, 90);
    });

    test('düşüş yoksa süre boş, doz yine de sayılır', () async {
      final ep = await addEpisode(utc(2026, 10, 31, 9, 30));
      await addEntry(utc(2026, 10, 31, 9, 30), 5, episodeId: ep);
      await addDose(med, utc(2026, 10, 31, 10), episodeId: ep);
      await addEntry(utc(2026, 10, 31, 10, 30), 5, episodeId: ep); // eşit: düşüş değil
      await addEntry(utc(2026, 10, 31, 11, 0), 6, episodeId: ep);

      final item = (await analyticsAt(now).medicationEffect(7)).effects.single;
      expect(item.usageCount, 1);
      expect(item.avgReliefMinutes, isNull);
    });

    test('ortalama yalnız rahatlama görülen dozlardan hesaplanır', () async {
      final ep1 = await addEpisode(utc(2026, 10, 30, 9, 30));
      await addEntry(utc(2026, 10, 30, 9, 30), 6, episodeId: ep1);
      await addDose(med, utc(2026, 10, 30, 10), episodeId: ep1);
      await addEntry(utc(2026, 10, 30, 10, 30), 2, episodeId: ep1); // 30 dk

      final ep2 = await addEpisode(utc(2026, 10, 31, 9, 30));
      await addEntry(utc(2026, 10, 31, 9, 30), 4, episodeId: ep2);
      await addDose(med, utc(2026, 10, 31, 10), episodeId: ep2);
      await addEntry(utc(2026, 10, 31, 10, 30), 7, episodeId: ep2); // düşmedi

      final item = (await analyticsAt(now).medicationEffect(7)).effects.single;
      expect(item.usageCount, 2);
      expect(item.avgReliefMinutes, 30);
    });

    test('önce ya da sonra kaydı olmayan doz hesaba katılmaz', () async {
      final ep = await addEpisode(utc(2026, 10, 31, 9, 30));
      await addDose(med, utc(2026, 10, 31, 10), episodeId: ep);
      await addEntry(utc(2026, 10, 31, 10, 30), 2, episodeId: ep);

      expect((await analyticsAt(now).medicationEffect(7)).effects, isEmpty);
    });
  });
}
