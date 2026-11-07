import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/seed_loader.dart';
import 'package:mobile/data/repositories/dose_skip_repository.dart';
import 'package:mobile/data/repositories/medication_log_repository.dart';
import 'package:mobile/data/repositories/medication_repository.dart';
import 'package:mobile/domain/services/dose_service.dart';
import 'package:mobile/domain/services/medication_service.dart';
import 'package:mobile/domain/services/reminder_service.dart';
import 'package:mobile/features/medication/screens/recurring_screen.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../data/test_support.dart';
import '../support/fake_notification_gateway.dart';

/// Saat: 2026-11-06 Cuma 10:30.
DateTime _now() => DateTime(2026, 11, 6, 10, 30);

/// Rutinler okunamıyormuş gibi davranan servis.
class _BrokenService extends MedicationService {
  _BrokenService(AppDatabase db)
      : super(
          medications: DriftMedicationRepository(db),
          logs: DriftMedicationLogRepository(db),
        );

  @override
  Future<List<Routine>> routines() => throw StateError('okunamadı');
}

/// Rutini kapatamayan servis.
class _FailingCloseService extends MedicationService {
  _FailingCloseService(AppDatabase db)
      : super(
          medications: DriftMedicationRepository(db),
          logs: DriftMedicationLogRepository(db),
        );

  @override
  Future<void> clearRoutine(String medicationId) =>
      throw StateError('kapatılamadı');
}

/// "Aldım" kaydı yazamayan doz servisi.
class _FailingDoseService extends DoseService {
  _FailingDoseService(AppDatabase db)
      : super(
          medications: DriftMedicationRepository(db),
          logs: DriftMedicationLogRepository(db),
          skips: DriftDoseSkipRepository(db),
          clock: _now,
        );

  @override
  Future<MedicationLog> markTaken({
    required String medicationId,
    required String time,
    String? day,
  }) =>
      throw StateError('yazılamadı');
}

void main() {
  late AppDatabase db;
  late DriftMedicationRepository repo;
  late DriftMedicationLogRepository logRepo;
  late DriftDoseSkipRepository skipRepo;
  late MedicationService service;
  late DoseService doses;
  late FakeNotificationGateway gateway;

  setUp(() {
    gateway = FakeNotificationGateway();
    db = createTestDb();
    repo = DriftMedicationRepository(db);
    logRepo = DriftMedicationLogRepository(db);
    skipRepo = DriftDoseSkipRepository(db);
    service = MedicationService(medications: repo, logs: logRepo);
    doses = DoseService(
      medications: repo,
      logs: logRepo,
      skips: skipRepo,
      transactor: db.transaction,
      clock: _now,
    );
  });
  tearDown(() => db.close());

  /// Dozun kartındaki durum metni, ör. "08:00 · Kaydedilmedi".
  String stateText(WidgetTester t, String med, String time) => t
      .widget<Text>(find.byKey(ValueKey('dose-state-$med-$time')))
      .data!;

  final parol = SeedLoader.medicationId('parol');
  final vitD = SeedLoader.medicationId('vitamin_d');

  Future<void> openApp(WidgetTester tester, {List<Override>? extra}) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => seedLoaderFor(db).seedIfNeeded());
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(_now),
        notificationGatewayProvider.overrideWithValue(gateway),
        ...?extra,
      ],
      child: MaterialApp(
        // Uygulamanın gerçek teması: düğmeler tam genişlik ister, ListTile
        // içindeki düğme bu yüzden bozulabilir (telefonda görüldü).
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const RecurringScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<T> run<T>(WidgetTester tester, Future<T> Function() f) =>
      tester.runAsync(f).then((v) => v as T);

  Future<void> seedAnd(WidgetTester tester, Future<void> Function() f) async {
    await run(tester, () => seedLoaderFor(db).seedIfNeeded());
    await run(tester, f);
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
    await tester.pumpAndSettle();
  }

  Future<void> openAddDialog(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Rutin ekle'));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String med) async {
    await tester.tap(find.byKey(const ValueKey('routine-med')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(med).last);
    await tester.pumpAndSettle();
  }

  group('liste', () {
    testWidgets('boşken iki ipucu da çıkar', (tester) async {
      await openApp(tester);
      expect(find.text('Bugün için rutin yok.'), findsOneWidget);
      expect(find.text('Henüz rutin tanımlanmamış.'), findsOneWidget);
    });

    testWidgets('bugünün rutini "Aldım" ile; tüm rutinler saat ve günle',
        (tester) async {
      await seedAnd(tester, () async {
        await service.setRoutine(
            medicationId: parol, times: ['08:30'], days: ['monday', 'friday']);
        await service.setRoutine(
            medicationId: vitD, times: ['21:00'], days: ['monday']);
      });
      await openApp(tester);

      // Bugün Cuma: yalnız Parol.
      expect(find.byKey(ValueKey('dose-$parol-08:30')), findsOneWidget);
      expect(find.byKey(ValueKey('dose-$vitD-21:00')), findsNothing);
      expect(find.text('Aldım'), findsOneWidget);
      // Tüm rutinler: ikisi de, günleriyle.
      expect(find.text('08:30 · Pzt, Cum'), findsOneWidget);
      expect(find.text('21:00 · Pzt'), findsOneWidget);
    });

    testWidgets('günsüz eski rutin "Her gün" görünür ve bugün listede',
        (tester) async {
      await seedAnd(tester, () async {
        await repo.setRecurrence(parol,
            isRecurring: true, recurringTime: '08:30:00', recurringDays: null);
      });
      await openApp(tester);
      expect(find.byKey(ValueKey('dose-$parol-08:30')), findsOneWidget);
      expect(find.text('08:30 · Her gün'), findsOneWidget);
    });

    testWidgets('kullanıcının bağladığı hastalığa göre gruplanır, "Diğer" sonda',
        (tester) async {
      await seedAnd(tester, () async {
        await service.setRoutine(
            medicationId: parol, times: ['08:30'], days: ['friday']);
        await service.setRoutine(
            medicationId: vitD, times: ['09:00'], days: ['friday']);
        await service.createCondition(
            name: 'Tansiyon', medicationIds: [parol]);
      });
      await openApp(tester);

      final tansiyonY = tester.getTopLeft(find.text('Tansiyon')).dy;
      final digerY = tester.getTopLeft(find.text('Diğer')).dy;
      expect(tansiyonY, lessThan(digerY));
      final parolY = tester
          .getTopLeft(find.byKey(ValueKey('routine-${await _condId(tester)}-$parol')))
          .dy;
      final vitY =
          tester.getTopLeft(find.byKey(ValueKey('routine-other-$vitD'))).dy;
      expect(tansiyonY, lessThan(parolY));
      expect(parolY, lessThan(digerY));
      expect(digerY, lessThan(vitY));
    });

    testWidgets('liste okunamazsa uyarı çıkar, ekleme kapalı', (tester) async {
      await openApp(tester, extra: [
        medicationServiceProvider.overrideWithValue(_BrokenService(db)),
      ]);
      expect(find.textContaining('Rutinler okunamadı'), findsOneWidget);
      expect(
        tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add)).onPressed,
        isNull,
      );
    });
  });

  group('ekleme', () {
    testWidgets('mevcut ilaca yazılır; yeni ilaç açılmaz, rutin listede belirir',
        (tester) async {
      await openApp(tester);
      final before = (await run(tester, () => repo.listAvailable())).length;

      await openAddDialog(tester);
      await choose(tester, 'Parol');
      await tester.tap(find.byKey(const ValueKey('day-monday')));
      await tester.tap(find.byKey(const ValueKey('day-friday')));
      await tester.pumpAndSettle();
      await tapSave(tester);

      expect(find.text('Rutin eklendi.'), findsOneWidget);
      final routines = await run(tester, () => service.routines());
      expect(routines, hasLength(1));
      expect(routines.single.medication.id, parol);
      expect(routines.single.times, ['08:00']);
      expect(routines.single.days, ['monday', 'friday']);
      expect((await run(tester, () => repo.listAvailable())).length, before);
      expect(find.text('08:00 · Pzt, Cum'), findsOneWidget); // liste yenilendi
    });

    testWidgets('ilaç seçilmezse ve gün seçilmezse hata, pencere açık kalır; '
        'hata alanların üstünde', (tester) async {
      await openApp(tester);
      await openAddDialog(tester);

      await tapSave(tester);
      expect(find.text('Önce bir ilaç seçin.'), findsOneWidget);
      expect(find.text('Yeni rutin'), findsOneWidget);

      await choose(tester, 'Parol');
      expect(find.text('Önce bir ilaç seçin.'), findsNothing); // seçince kalkar
      await tapSave(tester);
      expect(find.text('En az bir gün seçin.'), findsOneWidget);
      expect(find.text('Yeni rutin'), findsOneWidget);
      expect(await run(tester, () => service.routines()), isEmpty);

      final errorTop =
          tester.getTopLeft(find.byKey(const ValueKey('routine-dialog-error'))).dy;
      final dropdownTop =
          tester.getTopLeft(find.byKey(const ValueKey('routine-med'))).dy;
      expect(errorTop, lessThan(dropdownTop));

      // Gün seçince hata kalkar ve kayıt olur.
      await tester.tap(find.byKey(const ValueKey('day-sunday')));
      await tester.pumpAndSettle();
      expect(find.text('En az bir gün seçin.'), findsNothing);
      await tapSave(tester);
      expect(await run(tester, () => service.routines()), hasLength(1));
    });

    /// "Saat ekle" ile seçiciyi açıp önerilen saati (son saat + 1 saat) onaylar.
    Future<void> addSuggestedTime(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('routine-add-time')));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await tester.tap(find.text('Tamam'));
      await tester.pumpAndSettle();
    }

    testWidgets('birden fazla doz saati eklenir ve hepsi kaydedilir',
        (tester) async {
      await openApp(tester);
      await openAddDialog(tester);
      expect(find.byKey(const ValueKey('time-08:00')), findsOneWidget);

      await addSuggestedTime(tester); // 08:00 + 1 saat
      expect(find.byKey(const ValueKey('time-09:00')), findsOneWidget);

      await choose(tester, 'Parol');
      await tester.tap(find.byKey(const ValueKey('day-friday')));
      await tester.pumpAndSettle();
      await tapSave(tester);

      final routine = (await run(tester, () => service.routines())).single;
      expect(routine.times, ['08:00', '09:00']);
      expect(find.text('08:00, 09:00 · Cum'), findsOneWidget);
      // Bugün (Cuma) iki ayrı doz kartı var.
      expect(find.byKey(ValueKey('dose-$parol-08:00')), findsOneWidget);
      expect(find.byKey(ValueKey('dose-$parol-09:00')), findsOneWidget);
    });

    testWidgets('saat silinir; hepsi silinirse kayıtta hata çıkar', (tester) async {
      await openApp(tester);
      await openAddDialog(tester);
      await choose(tester, 'Parol');
      await tester.tap(find.byKey(const ValueKey('day-friday')));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Saati sil'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('time-08:00')), findsNothing);

      await tapSave(tester);
      expect(find.text('En az bir doz saati seçin.'), findsOneWidget);
      expect(find.text('Yeni rutin'), findsOneWidget);
      expect(await run(tester, () => service.routines()), isEmpty);

      // Saat eklenince hata kalkar.
      await addSuggestedTime(tester);
      expect(find.text('En az bir doz saati seçin.'), findsNothing);
    });

    testWidgets('en çok 10 doz saati: onuncudan sonra "Saat ekle" kapanır',
        (tester) async {
      await openApp(tester);
      await openAddDialog(tester);
      for (var i = 0; i < 9; i++) {
        await addSuggestedTime(tester); // 09:00 ... 17:00
      }
      expect(find.byKey(const ValueKey('time-17:00')), findsOneWidget);
      expect(
        tester
            .widget<ActionChip>(find.byKey(const ValueKey('routine-add-time')))
            .onPressed,
        isNull,
      );
    });

    testWidgets('rutini olan ilaç seçenekte yoktur; hepsinin rutini varsa '
        'uyarı çıkar, Kaydet kapalı', (tester) async {
      await seedAnd(tester, () async {
        await service.setRoutine(
            medicationId: parol, times: ['08:30'], days: ['monday']);
      });
      await openApp(tester);
      await openAddDialog(tester);
      await tester.tap(find.byKey(const ValueKey('routine-med')));
      await tester.pumpAndSettle();
      // Menüde Parol yok (listede arka planda 1 tane var, menüde olsaydı 2 olurdu).
      expect(find.text('Parol'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5)); // menüyü kapat
      await tester.pumpAndSettle();
      await tester.tap(find.text('İptal'));
      await tester.pumpAndSettle();

      await run(tester, () async {
        for (final m in await service.available()) {
          await service.setRoutine(
              medicationId: m.id, times: ['08:30'], days: ['monday']);
        }
      });
      // Ekranı yeniden aç (liste yeniden okunsun).
      await tester.pumpWidget(const SizedBox());
      await openApp(tester);
      await openAddDialog(tester);
      expect(find.textContaining('Rutin kurulacak ilaç yok'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Kaydet'))
            .onPressed,
        isNull,
      );
    });

    testWidgets('İptal hiçbir şey yazmaz', (tester) async {
      await openApp(tester);
      await openAddDialog(tester);
      await choose(tester, 'Parol');
      await tester.tap(find.byKey(const ValueKey('day-monday')));
      await tester.tap(find.text('İptal'));
      await tester.pumpAndSettle();
      expect(await run(tester, () => service.routines()), isEmpty);
    });
  });

  group('günün dozları: "Aldım" ve "Atladım"', () {
    /// Parol: Cuma 08:00 ve 20:00 (saat 10:30: sabah geçti, akşam gelmedi).
    Future<void> twoDoses(WidgetTester tester) => seedAnd(tester, () async {
          await service.setRoutine(
              medicationId: parol,
              times: ['08:00', '20:00'],
              days: ['friday']);
        });

    testWidgets('her doz kendi kartında; geçmiş doz "Kaydedilmedi", gelecek '
        'doz "Bekliyor", ikisinde de iki düğme', (tester) async {
      await twoDoses(tester);
      await openApp(tester);

      expect(stateText(tester, parol, '08:00'), '08:00 · Kaydedilmedi');
      expect(stateText(tester, parol, '20:00'), '20:00 · Bekliyor');
      for (final t in ['08:00', '20:00']) {
        expect(find.byKey(ValueKey('take-$parol-$t')), findsOneWidget);
        expect(find.byKey(ValueKey('skip-$parol-$t')), findsOneWidget);
      }
    });

    testWidgets('akşam dozu "Aldım": yalnız akşam alındı olur, sabah dozu '
        '"Kaydedilmedi" kalır ve doz bilgisiyle yazılır', (tester) async {
      await twoDoses(tester);
      await openApp(tester);

      await tester.tap(find.byKey(ValueKey('take-$parol-20:00')));
      await tester.pumpAndSettle();

      expect(find.text('Parol alındı olarak kaydedildi.'), findsOneWidget);
      expect(stateText(tester, parol, '20:00'), '20:00 · Alındı ✓');
      expect(find.byKey(ValueKey('take-$parol-20:00')), findsNothing);
      expect(find.byKey(ValueKey('skip-$parol-20:00')), findsNothing);
      expect(stateText(tester, parol, '08:00'), '08:00 · Kaydedilmedi');
      expect(find.byKey(ValueKey('take-$parol-08:00')), findsOneWidget);

      final logs = await run(tester, () => logRepo.listScheduledForDay('2026-11-06'));
      expect(logs, hasLength(1));
      expect(logs.single.medicationId, parol);
      expect(logs.single.scheduledTime, '20:00');
      expect(logs.single.scheduledDay, '2026-11-06');
      expect(logs.single.takenAt.toLocal(), _now());
    });

    testWidgets('"Atladım": doz "Atlandı" olur, alım kaydı yazılmaz; '
        '"Aldım" hâlâ mümkün', (tester) async {
      await twoDoses(tester);
      await openApp(tester);

      await tester.tap(find.byKey(ValueKey('skip-$parol-08:00')));
      await tester.pumpAndSettle();

      expect(find.text('Parol atlandı olarak kaydedildi.'), findsOneWidget);
      expect(stateText(tester, parol, '08:00'), '08:00 · Atlandı');
      expect(find.byKey(ValueKey('skip-$parol-08:00')), findsNothing);
      expect(find.byKey(ValueKey('take-$parol-08:00')), findsOneWidget);
      expect(await run(tester, () => skipRepo.listForDay('2026-11-06')),
          hasLength(1));
      // Alım kaydı okuyan yerler atlananı görmez.
      expect(await run(tester, () => service.logsForDay('2026-11-06')), isEmpty);
      // Diğer doz etkilenmez.
      expect(stateText(tester, parol, '20:00'), '20:00 · Bekliyor');
    });

    testWidgets('atlanan doz sonradan "Aldım": alındı olur, atlama silinir',
        (tester) async {
      await twoDoses(tester);
      await openApp(tester);
      await tester.tap(find.byKey(ValueKey('skip-$parol-08:00')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ValueKey('take-$parol-08:00')));
      await tester.pumpAndSettle();

      expect(stateText(tester, parol, '08:00'), '08:00 · Alındı ✓');
      expect(await run(tester, () => skipRepo.listForDay('2026-11-06')), isEmpty);
      expect(
          await run(tester, () => logRepo.listScheduledForDay('2026-11-06')),
          hasLength(1));
    });

    testWidgets('kayıt yazılamazsa hata gösterilir, hiçbir şey yazılmaz',
        (tester) async {
      await twoDoses(tester);
      await openApp(tester, extra: [
        doseServiceProvider.overrideWithValue(_FailingDoseService(db)),
      ]);

      await tester.tap(find.byKey(ValueKey('take-$parol-08:00')));
      await tester.pumpAndSettle();

      expect(find.text('İşlem yapılamadı. Tekrar deneyin.'), findsOneWidget);
      expect(stateText(tester, parol, '08:00'), '08:00 · Kaydedilmedi');
      expect(
          await run(tester, () => logRepo.listScheduledForDay('2026-11-06')),
          isEmpty);
    });

    testWidgets('durum başka yerden değişmişse anlaşılır mesaj çıkar ve '
        'ekran güncel duruma döner', (tester) async {
      await twoDoses(tester);
      await openApp(tester);
      // Ekran eski durumu gösterirken doz başka yoldan alındı.
      await run(tester,
          () => doses.markTaken(medicationId: parol, time: '08:00'));

      await tester.tap(find.byKey(ValueKey('take-$parol-08:00')));
      await tester.pumpAndSettle();

      expect(find.text('Bu doz zaten alındı olarak kaydedilmiş.'),
          findsOneWidget);
      expect(stateText(tester, parol, '08:00'), '08:00 · Alındı ✓');
      expect(
          await run(tester, () => logRepo.listScheduledForDay('2026-11-06')),
          hasLength(1)); // çift kayıt yok
    });
  });

  group('kapatma', () {
    testWidgets('onay ister; iptalde kalır, onayda rutin kalkar ama ilaç kalır',
        (tester) async {
      await seedAnd(tester, () async {
        await service.setRoutine(
            medicationId: parol, times: ['08:30'], days: ['friday']);
      });
      await openApp(tester);

      await tester.tap(find.byTooltip('Rutini kapat'));
      await tester.pumpAndSettle();
      expect(find.text('Rutin kapatılsın mı?'), findsOneWidget);
      expect(find.textContaining('"Parol" rutini kapatılır'), findsOneWidget);
      await tester.tap(find.text('İptal'));
      await tester.pumpAndSettle();
      expect(await run(tester, () => service.routines()), hasLength(1));

      await tester.tap(find.byTooltip('Rutini kapat'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Kapat'));
      await tester.pumpAndSettle();

      expect(find.text('Rutin kapatıldı.'), findsOneWidget);
      expect(await run(tester, () => service.routines()), isEmpty);
      expect((await run(tester, () => service.available())).map((m) => m.id),
          contains(parol));
      expect(find.text('Henüz rutin tanımlanmamış.'), findsOneWidget);
    });

    testWidgets('kapatma başarısız olursa hata gösterilir, rutin kalır',
        (tester) async {
      await seedAnd(tester, () async {
        await service.setRoutine(
            medicationId: parol, times: ['08:30'], days: ['friday']);
      });
      await openApp(tester, extra: [
        medicationServiceProvider.overrideWithValue(_FailingCloseService(db)),
      ]);
      await tester.tap(find.byTooltip('Rutini kapat'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Kapat'));
      await tester.pumpAndSettle();

      expect(find.text('İşlem yapılamadı. Tekrar deneyin.'), findsOneWidget);
      expect(await run(tester, () => service.routines()), hasLength(1));
      expect(find.text('08:30 · Cum'), findsOneWidget);
    });
  });

  group('izinler', () {
    Future<void> addParol(WidgetTester tester) async {
      await openAddDialog(tester);
      await choose(tester, 'Parol');
      await tester.tap(find.byKey(const ValueKey('day-monday')));
      await tester.pumpAndSettle();
      await tapSave(tester);
    }

    testWidgets('bildirim kapalıysa kayıttan sonra açıklama sorulur, sonra '
        'sistem izni istenir', (tester) async {
      gateway.notificationsEnabled = false;
      await openApp(tester);
      await addParol(tester);

      expect(find.text('Bildirim izni'), findsOneWidget);
      expect(gateway.notificationRequests, 0); // açıklamadan önce sistem sorusu yok
      await tester.tap(find.byKey(const ValueKey('perm-continue')));
      await tester.pumpAndSettle();

      expect(gateway.notificationRequests, 1);
      expect(gateway.active, hasLength(1));
      expect(find.byKey(const ValueKey('reminder-off-banner')), findsNothing);
    });

    testWidgets('"Şimdi değil" dersek sistem sorusu açılmaz, uyarı kartı kalır',
        (tester) async {
      gateway.notificationsEnabled = false;
      await openApp(tester);
      await addParol(tester);
      await tester.tap(find.byKey(const ValueKey('perm-later')));
      await tester.pumpAndSettle();

      expect(gateway.notificationRequests, 0);
      expect(find.byKey(const ValueKey('reminder-off-banner')), findsOneWidget);
      expect(find.textContaining('Bildirimler kapalı'), findsOneWidget);
    });

    testWidgets('sistem izni reddedilirse uyarı kartı görünür, rutin kayıtlı',
        (tester) async {
      gateway.notificationsEnabled = false;
      gateway.grantOnRequest = false;
      await openApp(tester);
      await addParol(tester);
      await tester.tap(find.byKey(const ValueKey('perm-continue')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('reminder-off-banner')), findsOneWidget);
      expect(await run(tester, () => service.routines()), hasLength(1));
    });

    testWidgets('izin zaten varsa hiçbir soru çıkmaz', (tester) async {
      await openApp(tester);
      await addParol(tester);

      expect(find.text('Bildirim izni'), findsNothing);
      expect(gateway.notificationRequests, 0);
      expect(find.byKey(const ValueKey('reminder-off-banner')), findsNothing);
      expect(find.byKey(const ValueKey('reminder-inexact-banner')), findsNothing);
    });

    testWidgets('tam alarm yoksa uyarı ve düğme; düğme ayar ekranını ister',
        (tester) async {
      await seedAnd(tester, () async {
        await service.setRoutine(
            medicationId: parol, times: ['08:30'], days: ['friday']);
      });
      gateway.exact = false;
      await openApp(tester);

      expect(find.byKey(const ValueKey('reminder-inexact-banner')),
          findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reminder-exact-button')));
      await tester.pumpAndSettle();
      expect(gateway.exactRequests, 1);
    });

    testWidgets('rutin yokken uyarı kartı gösterilmez', (tester) async {
      gateway.notificationsEnabled = false;
      await openApp(tester);
      expect(find.byKey(const ValueKey('reminder-off-banner')), findsNothing);
    });

    testWidgets('ayarlardan dönünce izin açılmışsa hatırlatmalar kurulur',
        (tester) async {
      await seedAnd(tester, () async {
        await service.setRoutine(
            medicationId: parol, times: ['08:30'], days: ['friday']);
      });
      gateway.notificationsEnabled = false;
      await openApp(tester);
      expect(find.byKey(const ValueKey('reminder-off-banner')), findsOneWidget);
      expect(gateway.active, isEmpty);

      gateway.notificationsEnabled = true; // kullanıcı ayarlardan açtı
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('reminder-off-banner')), findsNothing);
      expect(gateway.active, hasLength(1));
    });
  });

  group('hatırlatma bağlantısı', () {
    testWidgets('kaydedince ilacın doz bildirimleri kurulur', (tester) async {
      await openApp(tester);
      await openAddDialog(tester);
      await choose(tester, 'Parol');
      await tester.tap(find.byKey(const ValueKey('day-monday')));
      await tester.tap(find.byKey(const ValueKey('day-friday')));
      await tester.pumpAndSettle();
      await tapSave(tester);

      expect(find.text('Rutin eklendi.'), findsOneWidget);
      expect(gateway.active, hasLength(2));
      expect(gateway.active.values.map((r) => r.weekday).toSet(),
          {DateTime.monday, DateTime.friday});
      expect(gateway.active.values.every((r) => r.hour == 8 && r.minute == 0),
          isTrue);
    });

    testWidgets('kurulamazsa rutin yine kayıtlı kalır, uyarı gösterilir',
        (tester) async {
      gateway.failSchedule = StateError('izin yok');
      await openApp(tester);
      await openAddDialog(tester);
      await choose(tester, 'Parol');
      await tester.tap(find.byKey(const ValueKey('day-monday')));
      await tester.pumpAndSettle();
      await tapSave(tester);

      expect(find.text('Rutin eklendi.'), findsNothing);
      expect(find.text('Rutin eklendi ama hatırlatma kurulamadı.'),
          findsOneWidget);
      expect(await run(tester, () => service.routines()), hasLength(1));
    });

    testWidgets('rutin kapatılınca bildirimler iptal edilir', (tester) async {
      await seedAnd(tester, () async {
        await service.setRoutine(
            medicationId: parol, times: ['08:30'], days: ['friday']);
        await _reminders(repo, gateway).rescheduleFor(parol);
      });
      await openApp(tester);
      gateway.cancelCalls.clear();

      await tester.tap(find.byTooltip('Rutini kapat'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Kapat'));
      await tester.pumpAndSettle();

      expect(find.text('Rutin kapatıldı.'), findsOneWidget);
      expect(gateway.cancelCalls, hasLength(70));
    });

    testWidgets('iptal edilemezse kapatma yine olur, uyarı gösterilir',
        (tester) async {
      await seedAnd(tester, () async {
        await service.setRoutine(
            medicationId: parol, times: ['08:30'], days: ['friday']);
        await _reminders(repo, gateway).rescheduleFor(parol);
      });
      await openApp(tester);
      gateway.failCancel = StateError('hata');

      await tester.tap(find.byTooltip('Rutini kapat'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Kapat'));
      await tester.pumpAndSettle();

      expect(find.text('Rutin kapatıldı.'), findsNothing);
      expect(find.text('Rutin kapatıldı ama hatırlatma iptal edilemedi.'),
          findsOneWidget);
      expect(await run(tester, () => service.routines()), isEmpty);
    });
  });
}

/// "Tansiyon" hastalığının kimliği (grup kartının anahtarı için).
Future<String> _condId(WidgetTester tester) async {
  final element = tester.element(find.byType(RecurringScreen));
  final container = ProviderScope.containerOf(element);
  final list = await tester
      .runAsync(() => container.read(medicationServiceProvider).conditions());
  return list!.firstWhere((s) => s.condition.name == 'Tansiyon').condition.id;
}

ReminderService _reminders(
        DriftMedicationRepository repo, FakeNotificationGateway gateway) =>
    ReminderService(
      medications: repo,
      gateway: gateway,
      texts: ReminderTexts.fromL10n(lookupAppLocalizations(const Locale('tr'))),
    );
