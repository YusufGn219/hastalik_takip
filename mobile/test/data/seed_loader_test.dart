import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/seed_loader.dart';
import 'package:mobile/data/repositories/medication_repository.dart';
import 'package:mobile/data/repositories/symptom_repository.dart';

import 'test_support.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDb());
  tearDown(() => db.close());

  test('başlangıç verisi: 8 semptom, 10 ilaç yüklenir', () async {
    await seedLoaderFor(db).seedIfNeeded();

    final symptoms = await DriftSymptomRepository(db).listActive();
    expect(symptoms.length, 8);
    expect(symptoms.every((s) => !s.isCustom), isTrue);
    expect(symptoms.map((s) => s.name), contains('Baş ağrısı'));

    final meds = await DriftMedicationRepository(db).listAvailable();
    expect(meds.length, 10);
    expect(meds.every((m) => m.isCatalog), isTrue);
    expect(meds.every((m) => m.categoryId == null), isTrue);
  });

  test('yükleme tekrarlanabilir ve kimlikler sabit', () async {
    final loader = seedLoaderFor(db);
    await loader.seedIfNeeded();
    await loader.seedIfNeeded();

    expect((await DriftSymptomRepository(db).listActive()).length, 8);
    expect(
      await DriftSymptomRepository(db)
          .getById(SeedLoader.symptomId('headache')),
      isNotNull,
    );
    // Aynı anahtar her çağrıda aynı kimliği verir (cihazlar arası tutarlılık).
    expect(SeedLoader.symptomId('headache'), SeedLoader.symptomId('headache'));
    expect(
      SeedLoader.symptomId('headache'),
      isNot(SeedLoader.symptomId('fever')),
    );
  });

  test('kullanıcının sildiği katalog kaydı yeniden yüklemede geri gelmez',
      () async {
    final loader = seedLoaderFor(db);
    await loader.seedIfNeeded();
    final repo = DriftSymptomRepository(db);
    await repo.softDelete(SeedLoader.symptomId('cough'));

    await loader.seedIfNeeded();
    final names = (await repo.listActive()).map((s) => s.name);
    expect(names, isNot(contains('Öksürük')));
    expect(names.length, 7);
  });
}
