import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/seed_loader.dart';
import 'package:mobile/data/repositories/medication_log_repository.dart';
import 'package:mobile/data/repositories/medication_repository.dart';
import 'package:mobile/domain/services/medication_service.dart';
import 'package:mobile/features/medication/screens/recurring_screen.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../data/test_support.dart';

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

void main() {
  late AppDatabase db;
  late DriftMedicationRepository repo;
  late MedicationService service;

  setUp(() {
    db = createTestDb();
    repo = DriftMedicationRepository(db);
    service = MedicationService(
      medications: repo,
      logs: DriftMedicationLogRepository(db),
    );
  });
  tearDown(() => db.close());

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
        ...?extra,
      ],
      child: MaterialApp(
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
            medicationId: parol, time: '08:30', days: ['monday', 'friday']);
        await service.setRoutine(
            medicationId: vitD, time: '21:00', days: ['monday']);
      });
      await openApp(tester);

      // Bugün Cuma: yalnız Parol.
      expect(find.byKey(ValueKey('today-$parol')), findsOneWidget);
      expect(find.byKey(ValueKey('today-$vitD')), findsNothing);
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
      expect(find.byKey(ValueKey('today-$parol')), findsOneWidget);
      expect(find.text('08:30 · Her gün'), findsOneWidget);
    });

    testWidgets('kullanıcının bağladığı hastalığa göre gruplanır, "Diğer" sonda',
        (tester) async {
      await seedAnd(tester, () async {
        await service.setRoutine(
            medicationId: parol, time: '08:30', days: ['friday']);
        await service.setRoutine(
            medicationId: vitD, time: '09:00', days: ['friday']);
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
      expect(routines.single.time, '08:00');
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

    testWidgets('saat seçici açılır; Tamam saati korur', (tester) async {
      await openApp(tester);
      await openAddDialog(tester);
      await tester.tap(find.byKey(const ValueKey('routine-time')));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await tester.tap(find.text('Tamam'));
      await tester.pumpAndSettle();
      expect(find.text('08:00'), findsOneWidget);
    });

    testWidgets('rutini olan ilaç seçenekte yoktur; hepsinin rutini varsa '
        'uyarı çıkar, Kaydet kapalı', (tester) async {
      await seedAnd(tester, () async {
        await service.setRoutine(
            medicationId: parol, time: '08:30', days: ['monday']);
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
              medicationId: m.id, time: '08:30', days: ['monday']);
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

  group('"Aldım"', () {
    testWidgets('şimdiki zamanla alım kaydı yazar', (tester) async {
      await seedAnd(tester, () async {
        await service.setRoutine(
            medicationId: parol, time: '08:30', days: ['friday']);
      });
      await openApp(tester);
      expect(await run(tester, () => service.logsForDay('2026-11-06')), isEmpty);

      await tester.tap(find.text('Aldım'));
      await tester.pumpAndSettle();

      expect(find.text('Parol alındı olarak kaydedildi.'), findsOneWidget);
      final logs = await run(tester, () => service.logsForDay('2026-11-06'));
      expect(logs, hasLength(1));
      expect(logs.single.medicationId, parol);
      expect(logs.single.takenAt.toLocal(), _now());
    });
  });

  group('kapatma', () {
    testWidgets('onay ister; iptalde kalır, onayda rutin kalkar ama ilaç kalır',
        (tester) async {
      await seedAnd(tester, () async {
        await service.setRoutine(
            medicationId: parol, time: '08:30', days: ['friday']);
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
            medicationId: parol, time: '08:30', days: ['friday']);
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
}

/// "Tansiyon" hastalığının kimliği (grup kartının anahtarı için).
Future<String> _condId(WidgetTester tester) async {
  final element = tester.element(find.byType(RecurringScreen));
  final container = ProviderScope.containerOf(element);
  final list = await tester
      .runAsync(() => container.read(medicationServiceProvider).conditions());
  return list!.firstWhere((s) => s.condition.name == 'Tansiyon').condition.id;
}
