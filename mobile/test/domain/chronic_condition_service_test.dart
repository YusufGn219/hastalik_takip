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
  late DriftMedicationLogRepository logs;
  late MedicationService service;

  final parol = SeedLoader.medicationId('parol');
  final aspirin = SeedLoader.medicationId('aspirin');
  final vitD = SeedLoader.medicationId('vitamin_d');

  setUp(() async {
    db = createTestDb();
    await seedLoaderFor(db).seedIfNeeded();
    repo = DriftMedicationRepository(db);
    logs = DriftMedicationLogRepository(db);
    service = MedicationService(medications: repo, logs: logs);
  });
  tearDown(() => db.close());

  group('kronik hastalık kuralları', () {
    test('ekleme: ad kırpılır, ilaçlar bağlanır ve Türkçe sıralı gelir',
        () async {
      await service.createCondition(
        name: '  Migren ',
        medicationIds: [vitD, parol, aspirin],
      );
      final list = await service.conditions();
      expect(list.single.condition.name, 'Migren');
      expect(list.single.medications.map((m) => m.name),
          ['Aspirin', 'D Vitamini', 'Parol']);
    });

    test('boş ve 200 karakterden uzun ad reddedilir, hiçbir şey yazılmaz',
        () async {
      await expectLater(service.createCondition(name: '  '),
          violation(RuleCodes.conditionNameEmpty));
      await expectLater(service.createCondition(name: 'a' * 201),
          violation(RuleCodes.conditionNameTooLong));
      expect(await service.conditions(), isEmpty);
      expect((await service.createCondition(name: 'b' * 200)).name.length, 200);
    });

    test('aynı ad (harf farkı gözetmeden) tekrar eklenmez', () async {
      await service.createCondition(name: 'Işık hassasiyeti');
      await expectLater(service.createCondition(name: 'IŞIK HASSASİYETİ'),
          violation(RuleCodes.conditionNameExists));
      expect(await service.conditions(), hasLength(1));
    });

    test('olmayan ya da silinmiş ilaç reddedilir ve hastalık hiç oluşmaz',
        () async {
      await expectLater(
        service.createCondition(name: 'Astım', medicationIds: [parol, 'yok']),
        violation(RuleCodes.medicationNotFound),
      );
      expect(await service.conditions(), isEmpty);

      await repo.softDelete(aspirin);
      await expectLater(
        service.createCondition(name: 'Astım', medicationIds: [aspirin]),
        violation(RuleCodes.medicationNotFound),
      );
    });

    test('liste Türkçe sıralıdır', () async {
      for (final n in ['Tansiyon', 'Çölyak', 'Astım', 'Diyabet']) {
        await service.createCondition(name: n);
      }
      expect((await service.conditions()).map((c) => c.condition.name),
          ['Astım', 'Çölyak', 'Diyabet', 'Tansiyon']);
    });

    test('silinmiş ilaç hastalığın ilaç listesinde görünmez', () async {
      await service.createCondition(name: 'Astım', medicationIds: [parol, vitD]);
      await repo.softDelete(parol);
      expect((await service.conditions()).single.medications.map((m) => m.id),
          [vitD]);
    });

    test('güncelleme: ad ve ilaçlar değişir; kendi adı serbest, başkasınınki yasak',
        () async {
      final a = await service.createCondition(
          name: 'Astım', medicationIds: [parol]);
      await service.createCondition(name: 'Diyabet');

      await service.updateCondition(
          id: a.id, name: 'ASTIM', medicationIds: [vitD, aspirin]);
      final updated = (await service.conditions())
          .singleWhere((c) => c.condition.id == a.id);
      expect(updated.condition.name, 'ASTIM');
      expect(updated.medications.map((m) => m.id).toSet(), {vitD, aspirin});

      await expectLater(
        service.updateCondition(id: a.id, name: 'diyabet', medicationIds: []),
        violation(RuleCodes.conditionNameExists),
      );
      await expectLater(
        service.updateCondition(id: a.id, name: ' ', medicationIds: []),
        violation(RuleCodes.conditionNameEmpty),
      );
      await expectLater(
        service.updateCondition(id: 'yok', name: 'X', medicationIds: []),
        violation(RuleCodes.conditionNotFound),
      );
    });

    test('güncellemede geçersiz ilaç varsa ad da ilaçlar da değişmez', () async {
      final a = await service.createCondition(
          name: 'Astım', medicationIds: [parol]);
      await expectLater(
        service.updateCondition(
            id: a.id, name: 'Yeni ad', medicationIds: [aspirin, 'yok']),
        violation(RuleCodes.medicationNotFound),
      );
      final c = (await service.conditions()).single;
      expect(c.condition.name, 'Astım');
      expect(c.medications.map((m) => m.id), [parol]);
    });

    test('ilaç listesi boşaltılabilir', () async {
      final a = await service.createCondition(
          name: 'Astım', medicationIds: [parol]);
      await service.updateCondition(id: a.id, name: 'Astım', medicationIds: []);
      expect((await service.conditions()).single.medications, isEmpty);
    });

    test('silme: ilaçlar ve eski alım kayıtları kalır, ad yeniden kullanılabilir',
        () async {
      final a = await service.createCondition(
          name: 'Astım', medicationIds: [parol]);
      await service.logIntake(
        medicationId: parol,
        takenAt: utc(2026, 11, 1, 8),
        conditionId: a.id,
      );

      await service.deleteCondition(a.id);

      expect(await service.conditions(), isEmpty);
      expect((await repo.getById(parol))!.deletedAt, isNull);
      final all = await logs.listInRange(DateTime.utc(2000), DateTime.utc(2100));
      expect(all.single.conditionId, a.id); // kayıt bozulmadı
      await expectLater(
          service.deleteCondition(a.id), violation(RuleCodes.conditionNotFound));
      expect((await service.createCondition(name: 'Astım')).id, isNot(a.id));
    });
  });
}
