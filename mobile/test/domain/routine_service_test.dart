import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/repositories/medication_log_repository.dart';
import 'package:mobile/data/repositories/medication_repository.dart';
import 'package:mobile/domain/errors.dart';
import 'package:mobile/domain/services/medication_service.dart';
import 'package:mobile/domain/weekdays.dart';

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

  Future<Medication> med(String name) => repo.create(name: name);

  group('rutin kurma', () {
    test('mevcut ilaca yazılır; yeni ilaç açılmaz, bildirim numarası değişmez',
        () async {
      final m = await med('Zeta');
      final before = (await repo.listAvailable()).length;

      await service.setRoutine(
        medicationId: m.id,
        time: '08:30',
        days: ['friday', 'monday', 'monday'],
      );

      expect((await repo.listAvailable()).length, before); // kopya yok
      final after = (await repo.getById(m.id))!;
      expect(after.isRecurring, isTrue);
      expect(after.recurringTime, '08:30');
      expect(recurringDaysOf(after), ['monday', 'friday']); // tekil, hafta sırası
      expect(after.notificationId, m.notificationId);
    });

    test('yeniden kurmak eskisini değiştirir (ilacın tek rutini olur)',
        () async {
      final m = await med('Zeta');
      await service.setRoutine(
          medicationId: m.id, time: '08:30', days: ['monday']);
      await service.setRoutine(
          medicationId: m.id, time: '21:00', days: ['sunday', 'saturday']);

      final list = await service.routines();
      expect(list, hasLength(1));
      expect(list.single.time, '21:00');
      expect(list.single.days, ['saturday', 'sunday']);
    });

    test('geçersiz saat, boş gün, geçersiz gün ve olmayan ilaç reddedilir; '
        'hiçbir şey yazılmaz', () async {
      final m = await med('Zeta');
      for (final bad in ['8:30', '24:00', '08:60', '', '08:30:00', 'abc']) {
        await expectLater(
          service.setRoutine(medicationId: m.id, time: bad, days: ['monday']),
          violation(RuleCodes.routineTimeInvalid),
          reason: bad,
        );
      }
      await expectLater(
        service.setRoutine(medicationId: m.id, time: '08:30', days: []),
        violation(RuleCodes.routineDaysEmpty),
      );
      await expectLater(
        service.setRoutine(
            medicationId: m.id, time: '08:30', days: ['monday', 'pazartesi']),
        violation(RuleCodes.invalidRecurringDay),
      );
      await expectLater(
        service.setRoutine(medicationId: 'yok', time: '08:30', days: ['monday']),
        violation(RuleCodes.medicationNotFound),
      );
      expect((await repo.getById(m.id))!.isRecurring, isFalse);
      expect(await service.routines(), isEmpty);
    });

    test('silinmiş ilaca rutin kurulamaz', () async {
      final m = await med('Zeta');
      await repo.softDelete(m.id);
      await expectLater(
        service.setRoutine(
            medicationId: m.id, time: '08:30', days: ['monday']),
        violation(RuleCodes.medicationNotFound),
      );
    });
  });

  group('rutini kapatma', () {
    test('saat ve günler temizlenir; ilaç silinmez, yeniden kurulabilir',
        () async {
      final m = await med('Zeta');
      await service.setRoutine(
          medicationId: m.id, time: '08:30', days: ['monday']);
      await service.clearRoutine(m.id);

      final after = (await repo.getById(m.id))!;
      expect(after.isRecurring, isFalse);
      expect(after.recurringTime, isNull);
      expect(after.recurringDays, isNull);
      expect(after.deletedAt, isNull);
      expect(await service.routines(), isEmpty);
      expect((await service.available()).map((x) => x.id), contains(m.id));

      await service.setRoutine(
          medicationId: m.id, time: '09:00', days: ['tuesday']);
      expect(await service.routines(), hasLength(1));
    });

    test('olmayan ilaç hata verir', () async {
      await expectLater(
          service.clearRoutine('yok'), violation(RuleCodes.medicationNotFound));
    });
  });

  group('rutin listesi', () {
    test('saate, sonra Türkçe ada göre sıralı; rutini olmayanlar yok', () async {
      final a = await med('Işık');
      final b = await med('Çinko');
      final c = await med('Aspirin2');
      await med('Rutinsiz');
      await service.setRoutine(
          medicationId: a.id, time: '20:00', days: ['monday']);
      await service.setRoutine(
          medicationId: b.id, time: '08:00', days: ['monday']);
      await service.setRoutine(
          medicationId: c.id, time: '08:00', days: ['monday']);

      expect((await service.routines()).map((r) => r.medication.name),
          ['Aspirin2', 'Çinko', 'Işık']);
    });

    test('eski kayıt: saniyeli saat kırpılır, günsüz kayıt her gün sayılır',
        () async {
      await repo.create(
        name: 'Eski',
        isRecurring: true,
        recurringTime: '08:30:00',
        recurringDays: null,
      );
      final r = (await service.routines()).single;
      expect(r.time, '08:30');
      expect(r.days, weekdayKeys);
    });

    test('silinmiş ilaç listede görünmez', () async {
      final m = await med('Zeta');
      await service.setRoutine(
          medicationId: m.id, time: '08:30', days: ['monday']);
      await repo.softDelete(m.id);
      expect(await service.routines(), isEmpty);
    });
  });

  group('hastalığa göre gruplama (kullanıcının kendi bağlantısı)', () {
    test('hastalıklar Türkçe sıralı, bağlı olmayanlar sonda; boş grup yok',
        () async {
      final tansiyonIlaci = await med('Zeta');
      final migrenIlaci = await med('Mu');
      final serbest = await med('Serbest');
      final bagsiz = await med('Rutinsiz');
      for (final m in [tansiyonIlaci, migrenIlaci, serbest]) {
        await service.setRoutine(
            medicationId: m.id, time: '08:00', days: ['monday']);
      }
      await service.createCondition(
          name: 'Tansiyon', medicationIds: [tansiyonIlaci.id]);
      await service.createCondition(
          name: 'Çölyak', medicationIds: [bagsiz.id]); // rutini yok -> grup yok
      await service.createCondition(
          name: 'Migren', medicationIds: [migrenIlaci.id]);

      final groups = await service.routineGroups();
      expect(groups.map((g) => g.condition?.name), ['Migren', 'Tansiyon', null]);
      expect(groups[0].routines.map((r) => r.medication.name), ['Mu']);
      expect(groups[1].routines.map((r) => r.medication.name), ['Zeta']);
      expect(groups[2].routines.map((r) => r.medication.name), ['Serbest']);
    });

    test('iki hastalığa bağlı ilaç iki grupta da görünür, "Diğer"de görünmez',
        () async {
      final m = await med('Zeta');
      await service.setRoutine(
          medicationId: m.id, time: '08:00', days: ['monday']);
      await service.createCondition(name: 'A', medicationIds: [m.id]);
      await service.createCondition(name: 'B', medicationIds: [m.id]);

      final groups = await service.routineGroups();
      expect(groups.map((g) => g.condition?.name), ['A', 'B']);
    });

    test('silinen hastalık gruplamada görünmez; ilaç "Diğer"e düşer', () async {
      final m = await med('Zeta');
      await service.setRoutine(
          medicationId: m.id, time: '08:00', days: ['monday']);
      final c = await service.createCondition(name: 'A', medicationIds: [m.id]);
      await service.deleteCondition(c.id);

      final groups = await service.routineGroups();
      expect(groups.map((g) => g.condition), [null]);
      expect(groups.single.routines.single.medication.id, m.id);
    });

    test('rutin yoksa grup da yok', () async {
      await service.createCondition(name: 'A');
      expect(await service.routineGroups(), isEmpty);
    });
  });
}
