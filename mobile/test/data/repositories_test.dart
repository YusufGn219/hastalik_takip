import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/enums.dart';
import 'package:mobile/data/database/seed_loader.dart';
import 'package:mobile/data/repositories/cycle_repository.dart';
import 'package:mobile/data/repositories/daily_log_repository.dart';
import 'package:mobile/data/repositories/episode_repository.dart';
import 'package:mobile/data/repositories/measurement_repository.dart';
import 'package:mobile/data/repositories/medication_log_repository.dart';
import 'package:mobile/data/repositories/medication_repository.dart';
import 'package:mobile/data/repositories/profile_repository.dart';
import 'package:mobile/data/repositories/settings_repository.dart';
import 'package:mobile/data/repositories/support.dart';
import 'package:mobile/data/repositories/symptom_entry_repository.dart';
import 'package:mobile/data/repositories/symptom_repository.dart';
import 'package:mobile/data/repositories/tag_repository.dart';

import 'test_support.dart';

void main() {
  late AppDatabase db;
  final headache = SeedLoader.symptomId('headache');
  final parol = SeedLoader.medicationId('parol');

  setUp(() async {
    db = createTestDb();
    await seedLoaderFor(db).seedIfNeeded();
  });
  tearDown(() => db.close());

  group('SymptomRepository', () {
    test('özel semptom eklenir, işaretlenir, silinince listeden düşer',
        () async {
      final repo = DriftSymptomRepository(db, newId: sequentialIds('s'));
      final created = await repo.createCustom(
        name: 'Kulak çınlaması',
        category: 'nörolojik',
      );
      expect(created.id, 's-1');
      expect(created.isCustom, isTrue);
      expect((await repo.listActive()).length, 9);

      await repo.softDelete(created.id);
      expect((await repo.listActive()).length, 8);
      // Fiziksel silinmedi: kayıt hâlâ durur, yalnız işaretli.
      final row = await repo.getById(created.id);
      expect(row, isNotNull);
      expect(row!.deletedAt, isNotNull);
    });

    test('aynı adlı ikinci semptom reddedilir', () async {
      final repo = DriftSymptomRepository(db);
      await expectLater(
        repo.createCustom(name: 'Ateş'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Episode + SymptomEntry', () {
    test('atak başlar, konum eklenir, kapanır; UTC ve saat farkı saklanır',
        () async {
      final episodes = DriftEpisodeRepository(db);
      final entries = DriftSymptomEntryRepository(db);

      final start = DateTime(2026, 11, 1, 8, 30); // yerel
      final episode = await episodes.start(symptomId: headache, startTime: start);
      expect(episode.status, EpisodeStatus.ongoing);
      expect(episode.startUtcOffsetMinutes, start.timeZoneOffset.inMinutes);
      expect(episode.startTime.toUtc(), start.toUtc());

      expect((await episodes.findOngoing(headache))!.id, episode.id);

      final entry = await entries.create(
        symptomId: headache,
        severity: 7,
        timestamp: start,
        episodeId: episode.id,
        location: 'alın',
      );
      await episodes.addLocation(
        episodeId: episode.id,
        location: 'alın',
        addedAt: start,
      );
      expect((await entries.listForEpisode(episode.id)).single.id, entry.id);
      expect((await episodes.listLocations(episode.id)).single.location, 'alın');

      final end = DateTime(2026, 11, 1, 12, 0);
      await episodes.markResolved(
        id: episode.id,
        endedAt: end,
        resolutionNotes: 'geçti',
      );
      final closed = (await episodes.getById(episode.id))!;
      expect(closed.status, EpisodeStatus.resolved);
      expect(closed.endedAt!.toUtc(), end.toUtc());
      expect(closed.resolutionNotes, 'geçti');
      expect(await episodes.findOngoing(headache), isNull);
    });

    test('aralık sorgusu iki ucu da dahil eder, silinenleri saymaz', () async {
      final entries = DriftSymptomEntryRepository(db);
      Future<SymptomEntry> add(DateTime t) =>
          entries.create(symptomId: headache, severity: 3, timestamp: t);

      await add(utc(2026, 10, 25, 9, 59));
      final atFrom = await add(utc(2026, 10, 25, 10));
      await add(utc(2026, 10, 30, 10));
      final atTo = await add(utc(2026, 11, 1, 10));
      final deleted = await add(utc(2026, 10, 31, 10));
      await entries.softDelete(deleted.id);

      final inRange =
          await entries.listInRange(utc(2026, 10, 25, 10), utc(2026, 11, 1, 10));
      expect(inRange.length, 3);
      expect(inRange.first.id, atFrom.id);
      expect(inRange.last.id, atTo.id);
      expect((await entries.listSince(utc(2026, 10, 31))).length, 1);
    });

    test('girişi sonradan ataklara bağlama', () async {
      final episodes = DriftEpisodeRepository(db);
      final entries = DriftSymptomEntryRepository(db);
      final ep = await episodes.start(
        symptomId: headache,
        startTime: utc(2026, 11, 1),
      );
      final e = await entries.create(
        symptomId: headache,
        severity: 5,
        timestamp: utc(2026, 11, 1, 1),
      );
      expect(e.episodeId, isNull);
      await entries.attachToEpisode(e.id, ep.id);
      expect((await entries.getById(e.id))!.episodeId, ep.id);
    });
  });

  group('Medication + MedicationLog', () {
    test('ilaç eklenince ardışık bildirim numarası atanır, günler saklanır',
        () async {
      final repo = DriftMedicationRepository(db);
      final a = await repo.create(
        name: 'Tansiyon ilacı',
        isRecurring: true,
        recurringTime: '09:00',
        recurringDays: ['monday', 'friday'],
      );
      final b = await repo.create(name: 'Başka ilaç');
      expect(a.notificationId, 1);
      expect(b.notificationId, 2);
      expect(recurringDaysOf(a), ['monday', 'friday']);
      expect(recurringDaysOf(b), isNull);
      expect(a.isCatalog, isFalse);
    });

    test('kronik hastalık ilaçlara bağlanır', () async {
      final repo = DriftMedicationRepository(db);
      final c = await repo.createCondition(
        name: 'Migren',
        medicationIds: [parol, SeedLoader.medicationId('aspirin'), parol],
      );
      final meds = await repo.medicationsOfCondition(c.id);
      expect(meds.map((m) => m.name), ['Aspirin', 'Parol']);

      await repo.setConditionMedications(c.id, [parol]);
      expect((await repo.medicationsOfCondition(c.id)).single.name, 'Parol');
      expect((await repo.listConditions()).single.name, 'Migren');
    });

    test('ilaç kaydı: doz birimi, atak bağı, aralık ve ilaca göre listeleme',
        () async {
      final episodes = DriftEpisodeRepository(db);
      final logs = DriftMedicationLogRepository(db);
      final ep = await episodes.start(
        symptomId: headache,
        startTime: utc(2026, 11, 1),
      );

      final log = await logs.create(
        medicationId: parol,
        takenAt: utc(2026, 11, 1, 8),
        doseAmount: 500,
        doseUnit: DoseUnit.mg,
        episodeId: ep.id,
      );
      await logs.create(medicationId: parol, takenAt: utc(2026, 10, 1));

      expect(log.doseUnit, DoseUnit.mg);
      expect(log.doseAmount, 500);
      expect((await logs.listForEpisode(ep.id)).single.id, log.id);
      expect((await logs.listForMedication(parol)).length, 2);
      expect(
        (await logs.listInRange(utc(2026, 11, 1), utc(2026, 11, 2))).single.id,
        log.id,
      );
      // Varsayılan doz birimi "tablet" (Python'daki "Tablet" hatası taşınmadı).
      final plain = await logs.create(
        medicationId: parol,
        takenAt: utc(2026, 11, 3),
      );
      expect(plain.doseUnit, DoseUnit.tablet);
    });
  });

  group('DailyLog', () {
    test('günde tek kayıt: ikinci yazma günceller', () async {
      final repo = DriftDailyLogRepository(db, newId: sequentialIds('d'));
      final first = await repo.upsert(
        logDate: '2026-11-01',
        sleepHours: 7.5,
        waterIntake: 2.0,
        mood: 3,
        energyLevel: 4,
      );
      final second = await repo.upsert(
        logDate: '2026-11-01',
        sleepHours: 6.0,
        waterIntake: 3.0,
        mood: 2,
        energyLevel: 2,
        notes: 'güncellendi',
      );
      expect(second.id, first.id);
      expect(second.sleepHours, 6.0);
      expect(second.notes, 'güncellendi');
      expect((await repo.listInRange('2026-10-01', '2026-11-30')).length, 1);
    });

    test('aralık tarihe göre sıralı ve uçlar dahil', () async {
      final repo = DriftDailyLogRepository(db);
      for (final d in ['2026-11-03', '2026-11-01', '2026-11-02', '2026-11-05']) {
        await repo.upsert(
          logDate: d,
          sleepHours: 7,
          waterIntake: 2,
          mood: 3,
          energyLevel: 3,
        );
      }
      final rows = await repo.listInRange('2026-11-01', '2026-11-03');
      expect(rows.map((r) => r.logDate), ['2026-11-01', '2026-11-02', '2026-11-03']);
    });
  });

  group('Measurement', () {
    test('tür bazında zaman serisi, en sonuncusu ve gün anahtarı', () async {
      final repo = DriftMeasurementRepository(db);
      await repo.add(
        type: MeasurementTypes.weight,
        value: 70.5,
        unit: 'kg',
        measuredAt: DateTime(2026, 10, 1, 8),
      );
      final last = await repo.add(
        type: MeasurementTypes.weight,
        value: 69.0,
        unit: 'kg',
        measuredAt: DateTime(2026, 11, 1, 8),
      );
      await repo.add(
        type: MeasurementTypes.stress,
        value: 4,
        measuredAt: DateTime(2026, 11, 1, 20),
      );

      expect(last.logDate, '2026-11-01');
      final weights = await repo.listByType(MeasurementTypes.weight);
      expect(weights.map((m) => m.value), [70.5, 69.0]);
      expect((await repo.latest(MeasurementTypes.weight))!.id, last.id);
      expect(
        (await repo.listByType(
          MeasurementTypes.weight,
          fromDate: '2026-11-01',
        ))
            .length,
        1,
      );
      expect(await repo.latest(MeasurementTypes.caffeine), isNull);
    });
  });

  group('Tag', () {
    test('etiket ve zaman damgalı kayıt', () async {
      final repo = DriftTagRepository(db);
      final tag = await repo.createTag(name: 'hava değişti', kind: 'environment');
      await repo.addEntry(tagId: tag.id, occurredAt: utc(2026, 11, 1, 9));
      await repo.addEntry(tagId: tag.id, occurredAt: utc(2026, 11, 5, 9));

      expect(
        (await repo.listEntries(utc(2026, 11, 1), utc(2026, 11, 2))).length,
        1,
      );
      await repo.setActive(tag.id, false);
      expect(await repo.listActive(), isEmpty);
      // Aynı adlı ikinci etiket reddedilir.
      await expectLater(
        repo.createTag(name: 'hava değişti'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Cycle', () {
    test('dönem başlar/biter, günlük akış günde tek kayıt', () async {
      final repo = DriftCycleRepository(db);
      final period = await repo.startPeriod(startDate: '2026-10-28');
      expect(period.endDate, isNull);

      await repo.setFlow(
        flowDate: '2026-10-28',
        intensity: FlowIntensity.light,
        periodId: period.id,
      );
      final changed = await repo.setFlow(
        flowDate: '2026-10-28',
        intensity: FlowIntensity.heavy,
        periodId: period.id,
      );
      await repo.setFlow(flowDate: '2026-10-29', intensity: FlowIntensity.medium);

      final flows = await repo.listFlows('2026-10-28', '2026-10-29');
      expect(flows.length, 2);
      expect(flows.first.id, changed.id);
      expect(flows.first.intensity, FlowIntensity.heavy);

      await repo.endPeriod(period.id, '2026-11-01');
      expect((await repo.listPeriods()).single.endDate, '2026-11-01');
    });

    test('durum bilgisi eklenir ve bitirilir', () async {
      final repo = DriftCycleRepository(db);
      final s = await repo.addStatus(
        kind: CycleStatusKind.hormonalContraception,
        startDate: '2026-01-01',
      );
      await repo.endStatus(s.id, '2026-06-01');
      final listed = (await repo.listStatuses()).single;
      expect(listed.kind, CycleStatusKind.hormonalContraception);
      expect(listed.endDate, '2026-06-01');
    });
  });

  group('Profile ve Settings', () {
    test('profil ilk okumada varsayılanla açılır, tek satır kalır', () async {
      final repo = DriftProfileRepository(db);
      final p1 = await repo.get();
      final p2 = await repo.get();
      expect(p2.id, p1.id);
      expect(p1.cycleTrackingEnabled, isFalse);
      expect(p1.consentAt, isNull);

      final saved = await repo.save(
        const ProfilesCompanion(
          firstName: Value('Yusuf'),
          bloodType: Value('0 Rh+'),
          cycleTrackingEnabled: Value(true),
        ),
      );
      expect(saved.id, p1.id);
      expect(saved.firstName, 'Yusuf');
      expect(saved.cycleTrackingEnabled, isTrue);

      await repo.recordConsent(utc(2026, 11, 3, 12));
      expect((await repo.get()).consentAt!.toUtc(), utc(2026, 11, 3, 12));
      expect((await db.select(db.profiles).get()).length, 1);
    });

    test('ayar yazılır, üzerine yazılır, hepsi okunur', () async {
      final repo = DriftSettingsRepository(db);
      expect(await repo.get('x'), isNull);
      await repo.set('daily.stress', 'on');
      await repo.set('daily.stress', 'off');
      await repo.set('daily.alcohol', 'off');
      expect(await repo.get('daily.stress'), 'off');
      expect(await repo.getAll(), {
        'daily.stress': 'off',
        'daily.alcohol': 'off',
      });
    });
  });

  test('yardımcılar: gün anahtarı ve UTC farkı', () {
    expect(dayKey(DateTime(2026, 1, 5, 23, 59)), '2026-01-05');
    expect(utcOffsetOf(DateTime.utc(2026, 1, 1)), 0);
  });
}
