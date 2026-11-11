// Şema 6: `measurements.value2` ve `context` sütunları ve 5 → 6 geçişi.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/enums.dart';
import 'package:mobile/data/repositories/measurement_repository.dart';

import 'test_support.dart';

/// Şema 5'teki `measurements` tablosu (geçiş testi için eski veri).
const _measurementsTableV5 =
    'CREATE TABLE "measurements" ("id" TEXT NOT NULL, "created_at" INTEGER NOT NULL, '
    '"updated_at" INTEGER NOT NULL, "deleted_at" INTEGER NULL, '
    '"type" TEXT NOT NULL, "value" REAL NOT NULL, "unit" TEXT NOT NULL DEFAULT \'\', '
    '"log_date" TEXT NOT NULL, "measured_at" INTEGER NOT NULL, '
    '"utc_offset_minutes" INTEGER NOT NULL, "notes" TEXT NULL, PRIMARY KEY ("id"))';

void main() {
  group('yeni veritabanı', () {
    late AppDatabase db;
    setUp(() => db = createTestDb());
    tearDown(() => db.close());

    test('measurements value2 ve context sütunlarını içerir', () async {
      final columns = await db.customSelect('PRAGMA table_info(measurements)').get();
      final names = columns.map((r) => r.read<String>('name')).toSet();
      expect(names, containsAll(['value', 'value2', 'context']));
    });

    test('iki sayılı ve bağlamlı ölçüm yazılıp aynen okunur; eski çağrı boş bırakır', () async {
      final repo = DriftMeasurementRepository(db, newId: sequentialIds('m'));
      final at = DateTime(2026, 11, 10, 8, 30);

      await repo.add(
        type: MeasurementTypes.bloodPressure,
        value: 120,
        value2: 80,
        unit: 'mmHg',
        measuredAt: at,
      );
      await repo.add(
        type: MeasurementTypes.bloodGlucose,
        value: 99.088,
        unit: 'mg/dL',
        context: 'fasting',
        measuredAt: at,
      );
      await repo.add(type: MeasurementTypes.weight, value: 72.5, unit: 'kg', measuredAt: at);

      final bp = (await repo.listByType(MeasurementTypes.bloodPressure)).single;
      expect((bp.value, bp.value2, bp.context), (120.0, 80.0, null));

      final glucose = (await repo.listByType(MeasurementTypes.bloodGlucose)).single;
      expect(glucose.value, 99.088); // yuvarlanmadan saklanır
      expect(glucose.value2, null);
      expect(glucose.context, 'fasting');

      final weight = (await repo.listByType(MeasurementTypes.weight)).single;
      expect((weight.value2, weight.context), (null, null));
    });

    test('aynı gün birden fazla tansiyon ölçümü olabilir', () async {
      final repo = DriftMeasurementRepository(db, newId: sequentialIds('m'));
      await repo.add(
        type: MeasurementTypes.bloodPressure,
        value: 118,
        value2: 76,
        measuredAt: DateTime(2026, 11, 10, 8),
      );
      await repo.add(
        type: MeasurementTypes.bloodPressure,
        value: 126,
        value2: 82,
        measuredAt: DateTime(2026, 11, 10, 20),
      );
      final all = await repo.listByType(MeasurementTypes.bloodPressure, fromDate: '2026-11-10');
      expect(all.map((m) => m.value), [118.0, 126.0]);
    });
  });

  group('şema 5 → 6 geçişi', () {
    test('eski ölçümler korunur, yeni sütunlar boş gelir ve yazılabilir', () async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final raw = NativeDatabase.memory(setup: (rdb) {
        rdb.execute(_measurementsTableV5);
        rdb.execute(
            "INSERT INTO measurements (id, created_at, updated_at, type, value, unit, log_date, measured_at, utc_offset_minutes) "
            "VALUES ('m1', 1000, 1000, 'weight', 72.5, 'kg', '2026-11-03', 2000, 180)");
        rdb.execute('PRAGMA user_version = 5');
      });
      final old = AppDatabase(raw);
      addTearDown(old.close);

      final repo = DriftMeasurementRepository(old, newId: sequentialIds('n'));
      final weights = await repo.listByType('weight');
      expect(weights, hasLength(1));
      expect(weights.single.value, 72.5);
      expect(weights.single.value2, null);
      expect(weights.single.context, null);

      await repo.add(
        type: MeasurementTypes.bloodPressure,
        value: 130,
        value2: 85,
        measuredAt: DateTime(2026, 11, 10, 9),
      );
      final bp = (await repo.listByType('blood_pressure')).single;
      expect((bp.value, bp.value2), (130.0, 85.0));

      final v = await old.customSelect('PRAGMA user_version').getSingle();
      expect(v.read<int>('user_version'), 8);
    });
  });
}
