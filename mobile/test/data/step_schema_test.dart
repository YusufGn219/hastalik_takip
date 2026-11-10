// Şema 7: `step_samples` tablosu, deposu ve 6 → 7 geçişi.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/enums.dart';
import 'package:mobile/data/repositories/step_sample_repository.dart';

import 'test_support.dart';

/// Şema 6'daki `measurements` tablosu (geçiş testi için eski veri).
const _measurementsTableV6 =
    'CREATE TABLE "measurements" ("id" TEXT NOT NULL, "created_at" INTEGER NOT NULL, '
    '"updated_at" INTEGER NOT NULL, "deleted_at" INTEGER NULL, '
    '"type" TEXT NOT NULL, "value" REAL NOT NULL, "unit" TEXT NOT NULL DEFAULT \'\', '
    '"log_date" TEXT NOT NULL, "measured_at" INTEGER NOT NULL, '
    '"utc_offset_minutes" INTEGER NOT NULL, "notes" TEXT NULL, '
    '"value2" REAL NULL, "context" TEXT NULL, PRIMARY KEY ("id"))';

void main() {
  group('yeni veritabanı', () {
    late AppDatabase db;
    late DriftStepSampleRepository repo;
    setUp(() {
      db = createTestDb();
      repo = DriftStepSampleRepository(db, newId: sequentialIds('s'));
    });
    tearDown(() => db.close());

    test('step_samples beklenen sütunlar ve dizinle açılır', () async {
      final columns = await db.customSelect('PRAGMA table_info(step_samples)').get();
      final names = columns.map((r) => r.read<String>('name')).toSet();
      expect(
        names,
        containsAll([
          'id', 'counter', 'boot_count', 'uptime_ms', 'sampled_at',
          'utc_offset_minutes', 'log_date', 'source', 'deleted_at',
        ]),
      );
      final idx = await db.customSelect("SELECT name FROM sqlite_master WHERE type = 'index'").get();
      expect(idx.map((r) => r.read<String>('name')), contains('ix_step_samples_sampled_at'));
    });

    test('okuma yazılıp aynen okunur; gün ve saat farkı örnek anından türetilir', () async {
      final at = DateTime(2026, 11, 10, 8, 30);
      final s = await repo.add(
        counter: 12345, bootCount: 7, uptimeMs: 9876543, sampledAt: at, source: StepSampleSources.routine,
      );
      expect((s.counter, s.bootCount, s.uptimeMs, s.source), (12345, 7, 9876543, 'routine'));
      expect(s.logDate, '2026-11-10');
      expect(s.sampledAt, at);
      expect(s.utcOffsetMinutes, at.timeZoneOffset.inMinutes);

      final unknownBoot = await repo.add(
        counter: 1, bootCount: null, uptimeMs: 1000, sampledAt: DateTime(2026, 11, 10, 9), source: StepSampleSources.open,
      );
      expect(unknownBoot.bootCount, isNull);
    });

    test('listBetween [from, to) dahil/hariç; latestBefore kesin önce; firstAtOrAfter dahil; latest', () async {
      Future<void> add(int counter, DateTime at) => repo.add(
            counter: counter, bootCount: 1, uptimeMs: 1, sampledAt: at, source: StepSampleSources.open,
          );
      await add(1, DateTime(2026, 11, 9, 23));
      await add(2, DateTime(2026, 11, 10, 0));
      await add(3, DateTime(2026, 11, 10, 12));
      await add(4, DateTime(2026, 11, 11, 0));

      final from = DateTime(2026, 11, 10);
      final to = DateTime(2026, 11, 11);
      expect((await repo.listBetween(from, to)).map((s) => s.counter), [2, 3]);
      expect((await repo.latestBefore(from))!.counter, 1, reason: 'tam gece yarısındaki okuma "önce" sayılmaz');
      expect((await repo.firstAtOrAfter(to))!.counter, 4, reason: 'tam sınırdaki okuma dahil');
      expect((await repo.latest())!.counter, 4);
      expect(await repo.latestBefore(DateTime(2026, 11, 9)), isNull);
      expect(await repo.firstAtOrAfter(DateTime(2026, 11, 12)), isNull);
    });

    test('silinen okuma hiçbir sorguda görünmez', () async {
      final s = await repo.add(
        counter: 5, bootCount: 1, uptimeMs: 1, sampledAt: DateTime(2026, 11, 10, 10), source: StepSampleSources.open,
      );
      await (db.update(db.stepSamples)..where((t) => t.id.equals(s.id)))
          .write(StepSamplesCompanion(deletedAt: Value(DateTime(2026, 11, 10, 11))));
      expect(await repo.latest(), isNull);
      expect(await repo.listBetween(DateTime(2026, 11, 10), DateTime(2026, 11, 11)), isEmpty);
    });
  });

  group('şema 6 → 7 geçişi', () {
    test('eski veri korunur, step_samples eklenir ve çalışır', () async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final raw = NativeDatabase.memory(setup: (rdb) {
        rdb.execute(_measurementsTableV6);
        rdb.execute(
            "INSERT INTO measurements (id, created_at, updated_at, type, value, unit, log_date, measured_at, utc_offset_minutes) "
            "VALUES ('m1', 1000, 1000, 'weight', 72.5, 'kg', '2026-11-03', 2000, 180)");
        rdb.execute('PRAGMA user_version = 6');
      });
      final old = AppDatabase(raw);
      addTearDown(old.close);

      final weights = await old.select(old.measurements).get();
      expect(weights.single.value, 72.5);

      final repo = DriftStepSampleRepository(old, newId: sequentialIds('n'));
      await repo.add(
        counter: 100, bootCount: 2, uptimeMs: 5000, sampledAt: DateTime(2026, 11, 10, 9), source: StepSampleSources.routine,
      );
      expect((await repo.latest())!.counter, 100);

      final idx = await old.customSelect("SELECT name FROM sqlite_master WHERE type = 'index'").get();
      expect(idx.map((r) => r.read<String>('name')), contains('ix_step_samples_sampled_at'));
      final v = await old.customSelect('PRAGMA user_version').getSingle();
      expect(v.read<int>('user_version'), 7);
    });
  });
}
