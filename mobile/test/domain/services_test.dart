import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/enums.dart';
import 'package:mobile/data/database/seed_loader.dart';
import 'package:mobile/data/repositories/daily_log_repository.dart';
import 'package:mobile/data/repositories/episode_repository.dart';
import 'package:mobile/data/repositories/medication_log_repository.dart';
import 'package:mobile/data/repositories/medication_repository.dart';
import 'package:mobile/data/repositories/symptom_entry_repository.dart';
import 'package:mobile/domain/errors.dart';
import 'package:mobile/domain/local_day.dart';
import 'package:mobile/domain/services/episode_service.dart';
import 'package:mobile/domain/services/medication_service.dart';
import 'package:mobile/domain/services/timeline_service.dart';

import '../data/test_support.dart';

void main() {
  late AppDatabase db;
  late DriftEpisodeRepository episodes;
  late DriftSymptomEntryRepository entries;
  late DriftMedicationLogRepository logs;
  late DriftMedicationRepository medications;
  late EpisodeService episodeService;
  late MedicationService medicationService;

  final headache = SeedLoader.symptomId('headache');

  setUp(() async {
    db = createTestDb();
    await seedLoaderFor(db).seedIfNeeded();
    episodes = DriftEpisodeRepository(db);
    entries = DriftSymptomEntryRepository(db);
    logs = DriftMedicationLogRepository(db);
    medications = DriftMedicationRepository(db);
    episodeService = EpisodeService(
      episodes: episodes,
      entries: entries,
      transactor: db.transaction,
      clock: () => utc(2026, 11, 1, 12),
    );
    medicationService =
        MedicationService(medications: medications, logs: logs);
  });
  tearDown(() => db.close());

  group('EpisodeService', () {
    test('start: atak girişin zamanında başlar, giriş bağlanır, konum eklenir',
        () async {
      final entry = await entries.create(
        symptomId: headache,
        severity: 6,
        timestamp: utc(2026, 11, 1, 8),
        location: 'alın',
      );

      final ep = await episodeService.start(entry);

      expect(ep.startTime.toUtc(), utc(2026, 11, 1, 8));
      expect(ep.status, EpisodeStatus.ongoing);
      expect((await entries.getById(entry.id))!.episodeId, ep.id);
      expect(
        (await episodes.listLocations(ep.id)).map((l) => l.location),
        ['alın'],
      );
      expect((await episodeService.activeEpisode(headache))!.id, ep.id);
    });

    test('start: konumsuz girişte konum eklenmez', () async {
      final entry = await entries.create(
        symptomId: headache,
        severity: 3,
        timestamp: utc(2026, 11, 1, 8),
      );
      final ep = await episodeService.start(entry);
      expect(await episodes.listLocations(ep.id), isEmpty);
    });

    test('addEntry: yeni konum yalnız bir kez eklenir', () async {
      final first = await entries.create(
        symptomId: headache,
        severity: 5,
        timestamp: utc(2026, 11, 1, 8),
        location: 'alın',
      );
      final ep = await episodeService.start(first);

      final second = await entries.create(
        symptomId: headache,
        severity: 6,
        timestamp: utc(2026, 11, 1, 9),
        location: 'alın',
      );
      await episodeService.addEntry(ep, second, isNewLocation: true);
      expect(await episodes.listLocations(ep.id), hasLength(1));

      final third = await entries.create(
        symptomId: headache,
        severity: 4,
        timestamp: utc(2026, 11, 1, 10),
        location: 'şakak',
      );
      await episodeService.addEntry(ep, third, isNewLocation: true);
      expect(await episodes.listLocations(ep.id), hasLength(2));
      expect((await entries.getById(third.id))!.episodeId, ep.id);
    });

    test('addEntry: isNewLocation yanlışsa konum eklenmez', () async {
      final first = await entries.create(
        symptomId: headache,
        severity: 5,
        timestamp: utc(2026, 11, 1, 8),
      );
      final ep = await episodeService.start(first);
      final second = await entries.create(
        symptomId: headache,
        severity: 5,
        timestamp: utc(2026, 11, 1, 9),
        location: 'şakak',
      );
      await episodeService.addEntry(ep, second);
      expect(await episodes.listLocations(ep.id), isEmpty);
    });

    test('close: süre hesaplanır, saat verilmezse şimdi kullanılır', () async {
      final entry = await entries.create(
        symptomId: headache,
        severity: 5,
        timestamp: utc(2026, 11, 1, 8),
      );
      final ep = await episodeService.start(entry);
      await episodeService.close(ep, resolutionNotes: 'geçti');

      final closed = (await episodes.getById(ep.id))!;
      expect(closed.status, EpisodeStatus.resolved);
      expect(closed.endedAt!.toUtc(), utc(2026, 11, 1, 12));
      expect(closed.resolutionNotes, 'geçti');
      expect(EpisodeService.durationMinutes(closed), 240);
      expect(await episodeService.activeEpisode(headache), isNull);
    });

    test('close: süre kesirli dakikayı atar, açık atakta null', () async {
      final entry = await entries.create(
        symptomId: headache,
        severity: 5,
        timestamp: utc(2026, 11, 1, 8),
      );
      final ep = await episodeService.start(entry);
      expect(EpisodeService.durationMinutes(ep), isNull);

      await episodeService.close(ep, endedAt: utc(2026, 11, 1, 8, 1, 59));
      expect(
        EpisodeService.durationMinutes((await episodes.getById(ep.id))!),
        1,
      );
    });

    test('close: zaten kapalı atak reddedilir', () async {
      final entry = await entries.create(
        symptomId: headache,
        severity: 5,
        timestamp: utc(2026, 11, 1, 8),
      );
      final ep = await episodeService.start(entry);
      await episodeService.close(ep);
      final closed = (await episodes.getById(ep.id))!;

      await expectLater(
        episodeService.close(closed),
        throwsA(isA<RuleViolation>()
            .having((e) => e.code, 'code', RuleCodes.episodeAlreadyClosed)),
      );
    });

    test('close: bitiş başlangıca eşit ya da önceyse reddedilir', () async {
      final entry = await entries.create(
        symptomId: headache,
        severity: 5,
        timestamp: utc(2026, 11, 1, 8),
      );
      final ep = await episodeService.start(entry);

      for (final end in [utc(2026, 11, 1, 8), utc(2026, 11, 1, 7)]) {
        await expectLater(
          episodeService.close(ep, endedAt: end),
          throwsA(isA<RuleViolation>().having(
              (e) => e.code, 'code', RuleCodes.episodeEndBeforeStart)),
        );
      }
      // Reddedilen kapatma atağı değiştirmemeli.
      expect((await episodes.getById(ep.id))!.status, EpisodeStatus.ongoing);
    });
  });

  group('MedicationService', () {
    test('logIntake: atak ve kronik hastalık birlikte verilirse reddedilir',
        () async {
      final med = (await medicationService.available()).first;
      await expectLater(
        medicationService.logIntake(
          medicationId: med.id,
          takenAt: utc(2026, 11, 1, 8),
          episodeId: 'e',
          conditionId: 'c',
        ),
        throwsA(isA<RuleViolation>().having(
            (e) => e.code, 'code', RuleCodes.episodeAndConditionBoth)),
      );
      expect(await logs.listSince(utc(2020, 1, 1)), isEmpty);
    });

    test('logIntake: tek bağlantıyla kaydedilir', () async {
      final med = (await medicationService.available()).first;
      final entry = await entries.create(
        symptomId: headache,
        severity: 5,
        timestamp: utc(2026, 11, 1, 8),
      );
      final ep = await episodeService.start(entry);

      final log = await medicationService.logIntake(
        medicationId: med.id,
        takenAt: utc(2026, 11, 1, 9),
        doseAmount: 500,
        episodeId: ep.id,
      );
      expect(log.episodeId, ep.id);
      expect(log.conditionId, isNull);
    });

    test('logsForDay: gün, kaydın kendi UTC farkıyla belirlenir', () async {
      final med = (await medicationService.available()).first;
      Future<void> add(DateTime at, int offset) =>
          db.into(db.medicationLogs).insert(MedicationLogsCompanion.insert(
                id: 'log-${at.toIso8601String()}-$offset',
                createdAt: at,
                updatedAt: at,
                medicationId: med.id,
                takenAt: at,
                utcOffsetMinutes: offset,
              ));

      // UTC+3'te 1 Kasım 00:30 (UTC'de 31 Ekim 21:30) → 1 Kasım.
      await add(utc(2026, 10, 31, 21, 30), 180);
      // UTC'de 1 Kasım 05:00, UTC-8'de 31 Ekim 21:00 → 31 Ekim.
      await add(utc(2026, 11, 1, 5), -480);
      // UTC+3'te 1 Kasım 10:00.
      await add(utc(2026, 11, 1, 7), 180);

      final nov1 = await medicationService.logsForDay('2026-11-01');
      expect(nov1.map((l) => l.takenAt.toUtc()),
          [utc(2026, 10, 31, 21, 30), utc(2026, 11, 1, 7)]);

      final oct31 = await medicationService.logsForDay('2026-10-31');
      expect(oct31.map((l) => l.takenAt.toUtc()), [utc(2026, 11, 1, 5)]);
    });
  });

  group('TimelineService', () {
    test('forDay: günlük kayıt, girişler ve ilaçlar o yerel günden gelir',
        () async {
      final dailyLogs = DriftDailyLogRepository(db);
      await dailyLogs.upsert(
        logDate: '2026-11-01',
        sleepHours: 7,
        waterIntake: 2,
        mood: 3,
        energyLevel: 4,
      );
      final med = (await medicationService.available()).first;

      Future<void> addEntry(String id, DateTime at, int offset) =>
          db.into(db.symptomEntries).insert(SymptomEntriesCompanion.insert(
                id: id,
                createdAt: at,
                updatedAt: at,
                symptomId: headache,
                severity: 5,
                timestamp: at,
                utcOffsetMinutes: offset,
              ));
      await addEntry('b', utc(2026, 11, 1, 9), 180);
      await addEntry('a', utc(2026, 10, 31, 21, 30), 180); // yerelde 1 Kasım
      await addEntry('c', utc(2026, 11, 1, 22), 180); // yerelde 2 Kasım

      await db.into(db.medicationLogs).insert(MedicationLogsCompanion.insert(
            id: 'm1',
            createdAt: utc(2026, 11, 1, 6),
            updatedAt: utc(2026, 11, 1, 6),
            medicationId: med.id,
            takenAt: utc(2026, 11, 1, 6),
            utcOffsetMinutes: 180,
          ));

      final service = TimelineService(
        dailyLogs: dailyLogs,
        entries: entries,
        medications: medicationService,
      );
      final t = await service.forDay('2026-11-01');

      expect(t.dailyLog!.logDate, '2026-11-01');
      expect(t.symptomEntries.map((e) => e.id), ['a', 'b']);
      expect(t.medicationLogs.map((l) => l.id), ['m1']);

      final empty = await service.forDay('2026-12-25');
      expect(empty.dailyLog, isNull);
      expect(empty.symptomEntries, isEmpty);
      expect(empty.medicationLogs, isEmpty);
    });
  });

  group('local_day', () {
    test('localDayOf ve utcDayOf', () {
      final t = utc(2026, 10, 31, 22);
      expect(utcDayOf(t), '2026-10-31');
      expect(localDayOf(t, 180), '2026-11-01');
      expect(localDayOf(t, -480), '2026-10-31');
    });

    test('utcWindowForLocalDay en uç farkları kapsar', () {
      final w = utcWindowForLocalDay('2026-11-01');
      // UTC+14'te 1 Kasım 00:00 = UTC'de 31 Ekim 10:00.
      expect(w.from.isAfter(utc(2026, 10, 31, 10)), isFalse);
      // UTC-12'de 1 Kasım 23:59 = UTC'de 2 Kasım 11:59.
      expect(w.to.isBefore(utc(2026, 11, 2, 11, 59)), isFalse);
    });
  });
}
