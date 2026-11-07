import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/repositories/dose_skip_repository.dart';
import 'package:mobile/data/repositories/medication_log_repository.dart';
import 'package:mobile/data/repositories/medication_repository.dart';

import 'test_support.dart';

void main() {
  late AppDatabase db;
  late DriftMedicationRepository meds;
  late DriftMedicationLogRepository logs;
  late DriftDoseSkipRepository skips;

  setUp(() {
    db = createTestDb();
    meds = DriftMedicationRepository(db);
    logs = DriftMedicationLogRepository(db);
    skips = DriftDoseSkipRepository(db);
  });
  tearDown(() => db.close());

  final taken = DateTime(2026, 11, 6, 10, 30);

  group('alım kaydında doz alanları', () {
    test('doz saati ve günü birlikte yazılır; plansız alımda ikisi de boş',
        () async {
      final m = await meds.create(name: 'Zeta');
      final scheduled = await logs.create(
        medicationId: m.id,
        takenAt: taken,
        scheduledTime: '08:00',
        scheduledDay: '2026-11-06',
      );
      final extra = await logs.create(medicationId: m.id, takenAt: taken);

      expect(scheduled.scheduledTime, '08:00');
      expect(scheduled.scheduledDay, '2026-11-06');
      expect(extra.scheduledTime, isNull);
      expect(extra.scheduledDay, isNull);
    });

    test('yalnız biri verilirse reddedilir', () async {
      final m = await meds.create(name: 'Zeta');
      expect(
        () => logs.create(
            medicationId: m.id, takenAt: taken, scheduledTime: '08:00'),
        throwsArgumentError,
      );
      expect(
        () => logs.create(
            medicationId: m.id, takenAt: taken, scheduledDay: '2026-11-06'),
        throwsArgumentError,
      );
    });

    test('aynı doz için ikinci kayıt dizinde reddedilir; plansız alımlar serbest',
        () async {
      final m = await meds.create(name: 'Zeta');
      await logs.create(
        medicationId: m.id,
        takenAt: taken,
        scheduledTime: '08:00',
        scheduledDay: '2026-11-06',
      );
      await expectLater(
        logs.create(
          medicationId: m.id,
          takenAt: taken,
          scheduledTime: '08:00',
          scheduledDay: '2026-11-06',
        ),
        throwsA(anything),
      );
      // Başka saat, başka gün ve plansız alımlar serbest.
      await logs.create(
          medicationId: m.id,
          takenAt: taken,
          scheduledTime: '20:00',
          scheduledDay: '2026-11-06');
      await logs.create(
          medicationId: m.id,
          takenAt: taken,
          scheduledTime: '08:00',
          scheduledDay: '2026-11-07');
      await logs.create(medicationId: m.id, takenAt: taken);
      await logs.create(medicationId: m.id, takenAt: taken);
    });

    test('silinen kayıt dozu yeniden serbest bırakır', () async {
      final m = await meds.create(name: 'Zeta');
      final l = await logs.create(
        medicationId: m.id,
        takenAt: taken,
        scheduledTime: '08:00',
        scheduledDay: '2026-11-06',
      );
      await logs.softDelete(l.id);
      await logs.create(
        medicationId: m.id,
        takenAt: taken,
        scheduledTime: '08:00',
        scheduledDay: '2026-11-06',
      );
    });

    test('listScheduledForDay yalnız o günün planlı, silinmemiş kayıtlarını verir',
        () async {
      final m = await meds.create(name: 'Zeta');
      final a = await logs.create(
          medicationId: m.id,
          takenAt: taken,
          scheduledTime: '08:00',
          scheduledDay: '2026-11-06');
      final deleted = await logs.create(
          medicationId: m.id,
          takenAt: taken,
          scheduledTime: '20:00',
          scheduledDay: '2026-11-06');
      await logs.softDelete(deleted.id);
      await logs.create(
          medicationId: m.id,
          takenAt: taken,
          scheduledTime: '08:00',
          scheduledDay: '2026-11-07');
      await logs.create(medicationId: m.id, takenAt: taken); // plansız

      final list = await logs.listScheduledForDay('2026-11-06');
      expect(list.map((l) => l.id), [a.id]);
    });
  });

  group('atlama kaydı', () {
    test('yazılır, güne göre listelenir, silinen listelenmez', () async {
      final m = await meds.create(name: 'Zeta');
      final s = await skips.create(
        medicationId: m.id,
        scheduledDay: '2026-11-06',
        scheduledTime: '08:00',
        skippedAt: taken,
      );
      await skips.create(
        medicationId: m.id,
        scheduledDay: '2026-11-07',
        scheduledTime: '08:00',
        skippedAt: taken,
      );

      expect((await skips.listForDay('2026-11-06')).map((x) => x.id), [s.id]);
      await skips.softDelete(s.id);
      expect(await skips.listForDay('2026-11-06'), isEmpty);
    });

    test('aynı doz için ikinci atlama dizinde reddedilir; silinince serbest',
        () async {
      final m = await meds.create(name: 'Zeta');
      final s = await skips.create(
        medicationId: m.id,
        scheduledDay: '2026-11-06',
        scheduledTime: '08:00',
        skippedAt: taken,
      );
      await expectLater(
        skips.create(
          medicationId: m.id,
          scheduledDay: '2026-11-06',
          scheduledTime: '08:00',
          skippedAt: taken,
        ),
        throwsA(anything),
      );
      await skips.softDelete(s.id);
      await skips.create(
        medicationId: m.id,
        scheduledDay: '2026-11-06',
        scheduledTime: '08:00',
        skippedAt: taken,
      );
    });

    test('atlama kaydı alım kaydı tablosuna yazılmaz', () async {
      final m = await meds.create(name: 'Zeta');
      await skips.create(
        medicationId: m.id,
        scheduledDay: '2026-11-06',
        scheduledTime: '08:00',
        skippedAt: taken,
      );
      expect(await logs.listSince(DateTime(2000)), isEmpty);
      expect(await logs.listScheduledForDay('2026-11-06'), isEmpty);
    });
  });

  group('şema 2 → 3 geçişi', () {
    test('eski alım kayıtları aynen kalır (plansız), yeni yapı çalışır',
        () async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final raw = NativeDatabase.memory(setup: (rdb) {
        rdb.execute('''
CREATE TABLE "medications" ("id" TEXT NOT NULL, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, "deleted_at" INTEGER NULL, "name" TEXT NOT NULL, "category_id" TEXT NULL, "is_catalog" INTEGER NOT NULL DEFAULT 0 CHECK ("is_catalog" IN (0, 1)), "is_recurring" INTEGER NOT NULL DEFAULT 0 CHECK ("is_recurring" IN (0, 1)), "recurring_time" TEXT NULL, "recurring_days" TEXT NULL, "notification_id" INTEGER NULL, PRIMARY KEY ("id"))''');
        rdb.execute('''
CREATE TABLE "medication_logs" ("id" TEXT NOT NULL, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, "deleted_at" INTEGER NULL, "medication_id" TEXT NOT NULL REFERENCES medications (id), "taken_at" INTEGER NOT NULL, "utc_offset_minutes" INTEGER NOT NULL, "dose_amount" REAL NULL, "dose_unit" TEXT NOT NULL DEFAULT 'tablet', "episode_id" TEXT NULL, "condition_id" TEXT NULL, "notes" TEXT NOT NULL DEFAULT '', PRIMARY KEY ("id"))''');
        rdb.execute(
            "INSERT INTO medications (id, created_at, updated_at, name, is_recurring, recurring_time, recurring_days, notification_id) VALUES ('m1', 1000, 1000, 'Eski ilaç', 1, '08:30:00', '[\"monday\"]', 7)");
        rdb.execute(
            "INSERT INTO medication_logs (id, created_at, updated_at, medication_id, taken_at, utc_offset_minutes, dose_amount, dose_unit, notes) VALUES ('l1', 1000, 1000, 'm1', 2000, 180, 2.5, 'ml', 'not')");
        rdb.execute('PRAGMA user_version = 2');
      });
      final old = AppDatabase(raw);
      addTearDown(old.close);

      // Eski veri korunur; yeni sütunlar boş.
      final list = await old.select(old.medicationLogs).get();
      expect(list.single.doseAmount, 2.5);
      expect(list.single.notes, 'not');
      expect(list.single.scheduledTime, isNull);
      expect(list.single.scheduledDay, isNull);
      final med = await old.select(old.medications).getSingle();
      expect(med.recurringTime, '08:30:00'); // eski yazım değişmez
      expect(recurringTimesOf(med), ['08:30']); // ama okunur

      final tables = await old
          .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
          .get();
      expect(tables.map((r) => r.read<String>('name')), contains('dose_skips'));
      final idx = await old
          .customSelect("SELECT name FROM sqlite_master WHERE type='index'")
          .get();
      final idxNames = idx.map((r) => r.read<String>('name')).toSet();
      expect(idxNames, contains('uq_medication_logs_dose'));
      expect(idxNames, contains('uq_dose_skips_dose'));

      // Geçişten sonra yeni yapı çalışır, dizinler korur.
      final l = DriftMedicationLogRepository(old);
      final s = DriftDoseSkipRepository(old);
      await l.create(
        medicationId: 'm1',
        takenAt: taken,
        scheduledTime: '08:30',
        scheduledDay: '2026-11-02',
      );
      await expectLater(
        l.create(
          medicationId: 'm1',
          takenAt: taken,
          scheduledTime: '08:30',
          scheduledDay: '2026-11-02',
        ),
        throwsA(anything),
      );
      await s.create(
        medicationId: 'm1',
        scheduledDay: '2026-11-09',
        scheduledTime: '08:30',
        skippedAt: taken,
      );
      final v = await old.customSelect('PRAGMA user_version').getSingle();
      expect(v.read<int>('user_version'), 3);
    });
  });

  group('rutin saat listesi okuyucusu', () {
    test('virgüllü liste, eski tek saat ve saniyeli yazım', () async {
      Future<List<String>> read(String? raw) async {
        final m = await meds.create(
            name: 'X${raw ?? 'null'}', isRecurring: true, recurringTime: raw);
        return recurringTimesOf(m);
      }

      expect(await read('08:00,20:00'), ['08:00', '20:00']);
      expect(await read('20:00,08:00,08:00'), ['08:00', '20:00']); // sıralı, tekil
      expect(await read('08:30'), ['08:30']);
      expect(await read('08:30:00'), ['08:30']);
      expect(await read(' 08:30 , '), ['08:30']);
      expect(await read(''), isEmpty);
      expect(await read(null), isEmpty);
    });
  });
}
