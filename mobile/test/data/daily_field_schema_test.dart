// Şema 5: ek günlük alanları (`daily_fields`) ve 4 → 5 geçişi.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/repositories/daily_field_repository.dart';
import 'package:mobile/data/repositories/measurement_repository.dart';

import 'test_support.dart';

/// Şema 4'teki `measurements` tablosu (geçiş testi için eski veri).
const _measurementsTableV4 =
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

    test('daily_fields tablosu beklenen sütunlarla açılır, sürüm 5', () async {
      final columns = await db.customSelect('PRAGMA table_info(daily_fields)').get();
      final names = columns.map((r) => r.read<String>('name')).toSet();
      expect(
        names,
        containsAll([
          'id', 'name', 'kind', 'unit', 'min_value', 'max_value',
          'is_active', 'sort_order', 'builtin_key', 'deleted_at',
        ]),
      );
      final v = await db.customSelect('PRAGMA user_version').getSingle();
      expect(v.read<int>('user_version'), 5);
    });

    test('aynı ad ve aynı hazır anahtar ikinci kez yazılamaz; silinenin adı yeniden kullanılır', () async {
      final repo = DriftDailyFieldRepository(db, newId: sequentialIds('f'));
      Future<void> add(String name, {String? key}) => repo.insert(
            name: name, kind: 'number', unit: '', minValue: 0, maxValue: 10,
            isActive: true, sortOrder: 1, builtinKey: key,
          );
      await add('Çay');
      expect(() => add('Çay'), throwsA(anything));
      await add('Kafein', key: 'caffeine');
      expect(() => add('Başka', key: 'caffeine'), throwsA(anything));

      // Silinen alanın adı yeniden alınabilir.
      await (db.update(db.dailyFields)..where((t) => t.name.equals('Çay')))
          .write(DailyFieldsCompanion(deletedAt: Value(DateTime(2026, 11, 8))));
      await add('Çay');
    });
  });

  group('şema 4 → 5 geçişi', () {
    test('eski veri korunur, daily_fields eklenir ve çalışır', () async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final raw = NativeDatabase.memory(setup: (rdb) {
        rdb.execute(_measurementsTableV4);
        rdb.execute(
            "INSERT INTO measurements (id, created_at, updated_at, type, value, unit, log_date, measured_at, utc_offset_minutes) "
            "VALUES ('m1', 1000, 1000, 'weight', 72.5, 'kg', '2026-11-03', 2000, 180)");
        rdb.execute('PRAGMA user_version = 4');
      });
      final old = AppDatabase(raw);
      addTearDown(old.close);

      // Eski ölçüm yerinde ve okunabilir.
      final weights = await DriftMeasurementRepository(old).listByType('weight');
      expect(weights, hasLength(1));
      expect(weights.single.value, 72.5);

      // Yeni tablo yazılabilir; dizinler geçişte de kuruldu.
      final repo = DriftDailyFieldRepository(old);
      await repo.insert(
        name: 'Kafein', kind: 'number', unit: 'bardak', minValue: 0, maxValue: 20,
        isActive: false, sortOrder: 1, builtinKey: 'caffeine',
      );
      expect((await repo.listAll()).single.builtinKey, 'caffeine');
      expect(
        () => repo.insert(
          name: 'Kafein 2', kind: 'number', unit: '', minValue: 0, maxValue: 5,
          isActive: true, sortOrder: 2, builtinKey: 'caffeine',
        ),
        throwsA(anything),
      );

      final indexes = await old
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
          .get();
      final names = indexes.map((r) => r.read<String>('name')).toSet();
      expect(names, containsAll(['uq_daily_fields_name', 'uq_daily_fields_builtin']));

      final v = await old.customSelect('PRAGMA user_version').getSingle();
      expect(v.read<int>('user_version'), 5);
    });
  });
}
