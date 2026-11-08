import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/seed_loader.dart';
import 'package:mobile/data/repositories/medication_log_repository.dart';
import 'package:mobile/data/repositories/medication_repository.dart';
import 'package:mobile/domain/errors.dart';
import 'package:mobile/domain/services/medication_service.dart';

import '../data/test_support.dart';

Matcher violation(String code) => throwsA(
      isA<RuleViolation>().having((e) => e.code, 'code', code),
    );

void main() {
  late AppDatabase db;
  late DriftMedicationRepository repo;
  late MedicationService service;

  setUp(() async {
    db = createTestDb();
    await seedLoaderFor(db).seedIfNeeded();
    repo = DriftMedicationRepository(db);
    service = MedicationService(
      medications: repo,
      logs: DriftMedicationLogRepository(db),
    );
  });
  tearDown(() => db.close());

  group('kategori kuralları', () {
    test('ad kırpılır; boş ve 100 karakterden uzun ad reddedilir', () async {
      final c = await service.createCategory('  Ağrı ');
      expect(c.name, 'Ağrı');
      await expectLater(
          service.createCategory('   '), violation(RuleCodes.categoryNameEmpty));
      await expectLater(service.createCategory('a' * 101),
          violation(RuleCodes.categoryNameTooLong));
      expect((await service.createCategory('b' * 100)).name.length, 100);
    });

    test('aynı ad (büyük/küçük ve Türkçe harf farkı gözetmeden) tekrar eklenmez',
        () async {
      await service.createCategory('Işık');
      await expectLater(service.createCategory('  ışık'),
          violation(RuleCodes.categoryNameExists));
      await expectLater(service.createCategory('IŞIK'),
          violation(RuleCodes.categoryNameExists));
    });

    test('liste Türkçe sıralıdır', () async {
      for (final n in ['Vitamin', 'Çinko', 'Ağrı', 'Dikkat']) {
        await service.createCategory(n);
      }
      expect((await service.categories()).map((c) => c.name),
          ['Ağrı', 'Çinko', 'Dikkat', 'Vitamin']);
    });

    test('yeniden adlandırma: kendi adı serbest, başkasının adı yasak', () async {
      final a = await service.createCategory('Ağrı');
      await service.createCategory('Vitamin');
      await service.renameCategory(a.id, 'AĞRI'); // kendi adı, harf değişimi
      expect((await service.categories()).first.name, 'AĞRI');
      await expectLater(service.renameCategory(a.id, 'vitamin'),
          violation(RuleCodes.categoryNameExists));
      await expectLater(service.renameCategory(a.id, ' '),
          violation(RuleCodes.categoryNameEmpty));
      await expectLater(service.renameCategory('yok', 'X'),
          violation(RuleCodes.categoryNotFound));
    });

    test('silinen kategorinin adı yeniden kullanılabilir', () async {
      final a = await service.createCategory('Ağrı');
      await service.deleteCategory(a.id);
      final again = await service.createCategory('Ağrı');
      expect(again.id, isNot(a.id));
    });

    test('ilaca kategori atanır, değiştirilir, kaldırılır', () async {
      final c = await service.createCategory('Ağrı');
      final parol = SeedLoader.medicationId('parol');
      await service.setCategory(parol, c.id);
      expect((await repo.getById(parol))!.categoryId, c.id);
      await service.setCategory(parol, null);
      expect((await repo.getById(parol))!.categoryId, isNull);
    });

    test('olmayan/silinmiş kategori ve olmayan ilaç reddedilir', () async {
      final parol = SeedLoader.medicationId('parol');
      await expectLater(service.setCategory(parol, 'yok'),
          violation(RuleCodes.categoryNotFound));
      await expectLater(service.create(name: 'X', categoryId: 'yok'),
          violation(RuleCodes.categoryNotFound));
      final c = await service.createCategory('Ağrı');
      await service.deleteCategory(c.id);
      await expectLater(service.setCategory(parol, c.id),
          violation(RuleCodes.categoryNotFound));
      await expectLater(service.deleteCategory(c.id),
          violation(RuleCodes.categoryNotFound));
      await expectLater(service.setCategory('yok', null),
          violation(RuleCodes.medicationNotFound));
    });

    test('kategoriyle ilaç oluşturulur', () async {
      final c = await service.createCategory('Vitamin');
      final m = await service.create(name: 'Çinko', categoryId: c.id);
      expect(m.categoryId, c.id);
    });

    test('kategori silinince ilaçlar silinmez, kategorisiz kalır', () async {
      final c = await service.createCategory('Ağrı');
      final other = await service.createCategory('Vitamin');
      final parol = SeedLoader.medicationId('parol');
      final aspirin = SeedLoader.medicationId('aspirin');
      final vitD = SeedLoader.medicationId('vitamin_d');
      await service.setCategory(parol, c.id);
      await service.setCategory(aspirin, c.id);
      await service.setCategory(vitD, other.id);

      await service.deleteCategory(c.id);

      expect((await service.categories()).map((e) => e.id), [other.id]);
      expect((await repo.getById(parol))!.categoryId, isNull);
      expect((await repo.getById(parol))!.deletedAt, isNull);
      expect((await repo.getById(aspirin))!.categoryId, isNull);
      expect((await repo.getById(vitD))!.categoryId, other.id); // dokunulmadı
      expect((await service.available()).length, 10);
    });
  });

  group('veritabanı kısıtı', () {
    test('silinmemiş kategori adı tekildir (dizin)', () async {
      await repo.createCategory('Ağrı');
      await expectLater(repo.createCategory('Ağrı'), throwsA(anything));
    });
  });

  group('şema 1 → 2 geçişi', () {
    test('veri korunur, type kalkar, kategori yapısı gelir', () async {
      // setUp'taki ikinci bir veritabanı açık; uyarı gereksiz.
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final raw = NativeDatabase.memory(setup: (rdb) {
        rdb.execute('''
CREATE TABLE "medications" ("id" TEXT NOT NULL, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, "deleted_at" INTEGER NULL, "name" TEXT NOT NULL, "type" TEXT NOT NULL DEFAULT 'symptomatic', "is_catalog" INTEGER NOT NULL DEFAULT 0 CHECK ("is_catalog" IN (0, 1)), "is_recurring" INTEGER NOT NULL DEFAULT 0 CHECK ("is_recurring" IN (0, 1)), "recurring_time" TEXT NULL, "recurring_days" TEXT NULL, "notification_id" INTEGER NULL, PRIMARY KEY ("id"))''');
        rdb.execute(
            'CREATE UNIQUE INDEX uq_medications_notification_id ON medications (notification_id) WHERE notification_id IS NOT NULL');
        rdb.execute('''
CREATE TABLE "medication_logs" ("id" TEXT NOT NULL, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, "deleted_at" INTEGER NULL, "medication_id" TEXT NOT NULL REFERENCES medications (id), "taken_at" INTEGER NOT NULL, "utc_offset_minutes" INTEGER NOT NULL, "dose_amount" REAL NULL, "dose_unit" TEXT NOT NULL DEFAULT 'tablet', "episode_id" TEXT NULL, "condition_id" TEXT NULL, "notes" TEXT NOT NULL DEFAULT '', PRIMARY KEY ("id"))''');
        rdb.execute(
            "INSERT INTO medications (id, created_at, updated_at, name, type, is_catalog, notification_id) VALUES ('m1', 1000, 1000, 'Eski ilaç', 'chronic', 0, 7)");
        rdb.execute(
            "INSERT INTO medication_logs (id, created_at, updated_at, medication_id, taken_at, utc_offset_minutes, dose_amount, dose_unit, notes) VALUES ('l1', 1000, 1000, 'm1', 2000, 180, 2.5, 'ml', 'not')");
        // Şema 4 adımı da çalışır; eski şemadaki profil tablosu gerekir.
        rdb.execute(oldProfilesTableV3);
        rdb.execute('PRAGMA user_version = 1');
      });
      final old = AppDatabase(raw);
      addTearDown(old.close);

      final meds = await old.select(old.medications).get();
      expect(meds.single.name, 'Eski ilaç');
      expect(meds.single.categoryId, isNull);
      expect(meds.single.notificationId, 7);
      final logs = await old.select(old.medicationLogs).get();
      expect(logs.single.doseAmount, 2.5);
      expect(logs.single.notes, 'not');

      final cols = await old
          .customSelect('PRAGMA table_info(medications)')
          .get();
      final names = cols.map((r) => r.read<String>('name')).toSet();
      expect(names.contains('type'), isFalse);
      expect(names.contains('category_id'), isTrue);

      final idx = await old
          .customSelect("SELECT name FROM sqlite_master WHERE type='index'")
          .get();
      final idxNames = idx.map((r) => r.read<String>('name')).toSet();
      expect(idxNames, contains('uq_medication_categories_name'));
      expect(idxNames, contains('uq_medications_notification_id'));

      // Geçişten sonra yeni yapı çalışır.
      final r = DriftMedicationRepository(old);
      final c = await r.createCategory('Ağrı');
      await r.setMedicationCategory('m1', c.id);
      expect((await r.getById('m1'))!.categoryId, c.id);
      final v = await old.customSelect('PRAGMA user_version').getSingle();
      // Eski v1 veritabanı güncel sürüme (3) kadar tüm adımlardan geçer.
      expect(v.read<int>('user_version'), 4);
    });
  });
}
