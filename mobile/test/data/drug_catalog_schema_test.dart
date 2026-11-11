// Şema 8: `drug_catalog` tablosu, deposu ve 7 → 8 geçişi.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/repositories/drug_catalog_repository.dart';

import 'test_support.dart';

DrugCatalogRow _row(String name, {String active = 'madde', String atc = 'N02', String? key}) =>
    DrugCatalogRow(name: name, activeIngredient: active, atc: atc, searchKey: key ?? name.toLowerCase());

void main() {
  group('yeni veritabanı', () {
    late AppDatabase db;
    late DriftDrugCatalogRepository repo;
    setUp(() {
      db = createTestDb();
      repo = DriftDrugCatalogRepository(db);
    });
    tearDown(() => db.close());

    test('drug_catalog beklenen sütunlarla açılır ve kullanıcı verisi sütunu taşımaz', () async {
      final columns = await db.customSelect('PRAGMA table_info(drug_catalog)').get();
      final names = columns.map((r) => r.read<String>('name')).toSet();
      expect(names, {'id', 'name', 'active_ingredient', 'atc', 'search_key'});
    });

    test('replaceAll eski içeriği tümden değiştirir ve sayı doğru olur', () async {
      await repo.replaceAll([_row('A'), _row('B')]);
      expect(await repo.count(), 2);
      await repo.replaceAll([_row('C')]);
      expect(await repo.count(), 1);
      expect((await repo.search(['c'])).single.name, 'C');
    });

    test('parça parça yazma (küçük chunk) tüm satırları yazar', () async {
      await repo.replaceAll([for (var i = 0; i < 25; i++) _row('İLAÇ $i')], chunkSize: 7);
      expect(await repo.count(), 25);
    });

    test('onCommitted hata verirse işlem geri alınır: eski içerik aynen kalır', () async {
      await repo.replaceAll([_row('ESKİ')]);
      await expectLater(
        repo.replaceAll([_row('YENİ 1'), _row('YENİ 2')], onCommitted: () async => throw StateError('yazılamadı')),
        throwsA(isA<StateError>()),
      );
      expect(await repo.count(), 1);
      expect((await repo.search(['eski'])).single.name, 'ESKİ');
    });
  });

  group('şema 7 → 8 geçişi', () {
    test('eski veri korunur, drug_catalog eklenir ve çalışır', () async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final raw = NativeDatabase.memory(setup: (rdb) {
        rdb.execute(
            'CREATE TABLE "app_settings" ("key" TEXT NOT NULL, "value" TEXT NOT NULL, '
            '"updated_at" INTEGER NOT NULL, PRIMARY KEY ("key"))');
        rdb.execute("INSERT INTO app_settings (key, value, updated_at) VALUES ('k', 'v', 1000)");
        rdb.execute('PRAGMA user_version = 7');
      });
      final old = AppDatabase(raw);
      addTearDown(old.close);

      final settings = await old.select(old.appSettings).get();
      expect(settings.single.value, 'v');

      final repo = DriftDrugCatalogRepository(old);
      await repo.replaceAll([_row('PAROL 500 MG TABLET')]);
      expect(await repo.count(), 1);
      final v = await old.customSelect('PRAGMA user_version').getSingle();
      expect(v.read<int>('user_version'), 8);
    });
  });
}
