import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/notifications/notification_gateway.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/seed_loader.dart';
import 'package:mobile/data/repositories/medication_log_repository.dart';
import 'package:mobile/data/repositories/medication_repository.dart';
import 'package:mobile/domain/services/medication_service.dart';
import 'package:mobile/domain/services/reminder_service.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../data/test_support.dart';
import '../support/fake_notification_gateway.dart';

void main() {
  late AppDatabase db;
  late DriftMedicationRepository meds;
  late MedicationService routines;
  late FakeNotificationGateway gateway;
  late ReminderService service;

  final texts = ReminderTexts.fromL10n(lookupAppLocalizations(const Locale('tr')));

  setUp(() {
    db = createTestDb();
    meds = DriftMedicationRepository(db);
    routines = MedicationService(
      medications: meds,
      logs: DriftMedicationLogRepository(db),
    );
    gateway = FakeNotificationGateway();
    service = ReminderService(medications: meds, gateway: gateway, texts: texts);
  });
  tearDown(() => db.close());

  /// Aspirin: 08:00 ve 20:00, Pazartesi ve Çarşamba.
  Future<Medication> aspirin({
    List<String> times = const ['08:00', '20:00'],
    List<String> days = const ['monday', 'wednesday'],
  }) async {
    final m = await meds.create(name: 'Aspirin');
    await routines.setRoutine(medicationId: m.id, times: times, days: days);
    return (await meds.getById(m.id))!;
  }

  group('kimlik kuralı', () {
    test('kimlik = numara*100 + doz sırası*10 + gün', () {
      expect(ReminderService.idFor(7, 0, 0), 700);
      expect(ReminderService.idFor(7, 1, 0), 710);
      expect(ReminderService.idFor(7, 1, 1), 711);
      expect(ReminderService.idFor(7, 9, 6), 796);
    });

    test('bir ilacın 70 kimliği hep kendi yüzlük bloğunda, ilaçlar karışmaz', () {
      final a = ReminderService.allIdsOf(7);
      final b = ReminderService.allIdsOf(8);
      expect(a, hasLength(70));
      expect(a.toSet(), hasLength(70)); // tekil
      expect(a.every((id) => id >= 700 && id <= 799), isTrue);
      expect(a.toSet().intersection(b.toSet()), isEmpty);
    });
  });

  group('rutinden hatırlatma kurma', () {
    test('her doz saati x gün için ayrı bildirim; hiçbiri diğerini ezmez',
        () async {
      final m = await aspirin();
      final nid = m.notificationId!;

      await service.rescheduleFor(m.id);

      expect(gateway.active.keys.toSet(), {
        nid * 100 + 0, nid * 100 + 2, // 08:00 Pzt, Çar
        nid * 100 + 10, nid * 100 + 12, // 20:00 Pzt, Çar
      });
      expect(gateway.scheduleCalls, hasLength(4)); // ezilen yok
      final r0 = gateway.active[nid * 100]!;
      expect((r0.weekday, r0.hour, r0.minute), (DateTime.monday, 8, 0));
      final r12 = gateway.active[nid * 100 + 12]!;
      expect((r12.weekday, r12.hour, r12.minute), (DateTime.wednesday, 20, 0));
    });

    test('metin sade: ilaç adı ve sağlık verisi yok', () async {
      final m = await aspirin();
      await service.rescheduleFor(m.id);
      for (final r in gateway.active.values) {
        expect(r.title, 'Vitapuls');
        expect(r.body, 'İlaç saatiniz geldi');
        expect('${r.title} ${r.body} ${r.channelName} ${r.channelDescription}',
            isNot(contains('Aspirin')));
      }
    });

    test('tam alarm izni yoksa "civarı" (exact=false) kurulur', () async {
      final m = await aspirin();
      gateway.exact = false;
      await service.rescheduleFor(m.id);
      expect(gateway.active.values.every((r) => !r.exact), isTrue);

      gateway.exact = true;
      await service.rescheduleFor(m.id);
      expect(gateway.active.values.every((r) => r.exact), isTrue);
    });

    test('saat silinince eski bildirimler kalkar (sıra numaraları kayar)',
        () async {
      final m = await aspirin();
      final nid = m.notificationId!;
      await service.rescheduleFor(m.id);
      expect(gateway.active, hasLength(4));

      // Yalnız 20:00 kalır: eskiden sıra 1 olan doz artık sıra 0.
      await routines.setRoutine(
          medicationId: m.id, times: ['20:00'], days: ['monday', 'wednesday']);
      await service.rescheduleFor(m.id);

      expect(gateway.active.keys.toSet(), {nid * 100, nid * 100 + 2});
      expect(gateway.active[nid * 100]!.hour, 20);
    });

    test('günler değişince eski günlerin bildirimi kalkar', () async {
      final m = await aspirin();
      await service.rescheduleFor(m.id);
      await routines.setRoutine(
          medicationId: m.id, times: ['08:00', '20:00'], days: ['friday']);
      await service.rescheduleFor(m.id);

      expect(gateway.active.values.map((r) => r.weekday).toSet(),
          {DateTime.friday});
      expect(gateway.active, hasLength(2));
    });

    test('günsüz ve eski saniyeli kayıt: her gün, 08:30', () async {
      final m = await meds.create(
        name: 'Eski',
        isRecurring: true,
        recurringTime: '08:30:00',
        recurringDays: null,
      );
      await service.rescheduleFor(m.id);
      expect(gateway.active, hasLength(7));
      expect(gateway.active.values.map((r) => r.weekday).toSet(),
          {1, 2, 3, 4, 5, 6, 7});
      expect(gateway.active.values.every((r) => r.hour == 8 && r.minute == 30),
          isTrue);
    });

    test('bozuk saat atlanır, 10\'dan fazla doz kırpılır', () async {
      final bad = await meds.create(
        name: 'Bozuk',
        isRecurring: true,
        recurringTime: 'abc,08:00',
        recurringDays: ['monday'],
      );
      await service.rescheduleFor(bad.id);
      expect(gateway.active, hasLength(1));
      expect(gateway.active.values.single.hour, 8);

      gateway.active.clear();
      final many = await meds.create(
        name: 'Çok',
        isRecurring: true,
        recurringTime: [for (var h = 0; h < 12; h++) '${h.toString().padLeft(2, '0')}:00']
            .join(','),
        recurringDays: ['monday'],
      );
      await service.rescheduleFor(many.id);
      expect(gateway.active, hasLength(10));
    });
  });

  group('katalog ilacı (numarasız gelir)', () {
    test('ilk rutinde numara atanır ve bildirim kurulur; sonra numara sabit',
        () async {
      await seedLoaderFor(db).seedIfNeeded();
      final parol = SeedLoader.medicationId('parol');
      expect((await meds.getById(parol))!.notificationId, isNull);
      await routines.setRoutine(
          medicationId: parol, times: ['08:00'], days: ['monday']);

      await service.rescheduleFor(parol);

      final nid = (await meds.getById(parol))!.notificationId;
      expect(nid, isNotNull);
      expect(gateway.active.keys.toSet(), {nid! * 100});

      await service.rescheduleFor(parol);
      expect((await meds.getById(parol))!.notificationId, nid); // değişmez
    });

    test('iki katalog ilacı aynı numarayı almaz', () async {
      await seedLoaderFor(db).seedIfNeeded();
      final a = SeedLoader.medicationId('parol');
      final b = SeedLoader.medicationId('vitamin_d');
      final ma = await meds.ensureNotificationId(a);
      final mb = await meds.ensureNotificationId(b);
      expect(ma!.notificationId, isNot(mb!.notificationId));
    });

    test('açılışta rutinli numarasız ilaç da kurulur', () async {
      await seedLoaderFor(db).seedIfNeeded();
      final parol = SeedLoader.medicationId('parol');
      await routines.setRoutine(
          medicationId: parol, times: ['08:00'], days: ['monday']);
      await service.rescheduleAll();
      expect(gateway.active, hasLength(1));
    });
  });

  group('kapatma ve silme', () {
    test('rutin kapatılınca ilacın tüm bildirimleri iptal edilir', () async {
      final m = await aspirin();
      await service.rescheduleFor(m.id);
      expect(gateway.active, isNotEmpty);

      await routines.clearRoutine(m.id);
      await service.rescheduleFor(m.id);

      expect(gateway.active, isEmpty);
    });

    test('cancelFor 70 olası kimliğin hepsini iptal eder, diğer ilaca dokunmaz',
        () async {
      final a = await aspirin();
      final b = await meds.create(name: 'Parol');
      await routines.setRoutine(
          medicationId: b.id, times: ['09:00'], days: ['friday']);
      await service.rescheduleFor(a.id);
      await service.rescheduleFor(b.id);
      final bCount = gateway.active.length - 4;
      gateway.cancelCalls.clear();

      await service.cancelFor(a.id);

      expect(gateway.cancelCalls.toSet(),
          ReminderService.allIdsOf(a.notificationId!).toSet());
      expect(gateway.cancelCalls, hasLength(70));
      expect(gateway.active, hasLength(bCount)); // yalnız Parol kaldı
    });

    test('silinmiş ilacın bildirimleri kalkar', () async {
      final m = await aspirin();
      await service.rescheduleFor(m.id);
      await meds.softDelete(m.id);
      await service.rescheduleFor(m.id);
      expect(gateway.active, isEmpty);
    });

    test('olmayan ilaç için hiçbir çağrı yapılmaz', () async {
      await service.rescheduleFor('yok');
      await service.cancelFor('yok');
      expect(gateway.scheduleCalls, isEmpty);
      expect(gateway.cancelCalls, isEmpty);
    });
  });

  group('açılışta hepsini yeniden kurma', () {
    test('önce tümü silinir, sonra yalnız rutinli ilaçlar kurulur', () async {
      final a = await aspirin();
      final plain = await meds.create(name: 'Rutinsiz');
      final deleted = await aspirin(times: ['10:00'], days: ['friday']);
      await meds.softDelete(deleted.id);
      // Eski, artık geçersiz bir bildirim (ör. önceki kurulumdan kalan).
      gateway.active[99999] = DoseReminder(
        id: 99999, title: 'x', body: 'x', weekday: 1, hour: 1, minute: 1,
        exact: true, channelName: 'x', channelDescription: 'x',
      );

      await service.rescheduleAll();

      expect(gateway.cancelAllCalls, 1);
      expect(gateway.active.containsKey(99999), isFalse);
      expect(gateway.active.keys.every((id) => id ~/ 100 == a.notificationId),
          isTrue);
      expect(gateway.active, hasLength(4));
      expect(plain.id, isNotEmpty);
    });

    test('hiç rutin yoksa yalnız temizlenir', () async {
      await meds.create(name: 'Rutinsiz');
      await service.rescheduleAll();
      expect(gateway.cancelAllCalls, 1);
      expect(gateway.active, isEmpty);
    });
  });

  test('bildirim sistemi hata verirse hata yukarı iletilir (çağıran uyarır)',
      () async {
    final m = await aspirin();
    gateway.failSchedule = StateError('izin yok');
    await expectLater(service.rescheduleFor(m.id), throwsStateError);
  });
}
