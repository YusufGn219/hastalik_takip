import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/seed_loader.dart';
import 'package:mobile/data/repositories/daily_log_repository.dart';
import 'package:mobile/data/repositories/dose_skip_repository.dart';
import 'package:mobile/data/repositories/medication_log_repository.dart';
import 'package:mobile/data/repositories/medication_repository.dart';
import 'package:mobile/domain/services/dose_service.dart';
import 'package:mobile/domain/services/medication_service.dart';
import 'package:mobile/features/home/home_screen.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../data/test_support.dart';

/// Saat: 2026-11-06 Cuma 10:30.
DateTime _now() => DateTime(2026, 11, 6, 10, 30);

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
  late MedicationService meds;
  final parol = SeedLoader.medicationId('parol');
  final vitD = SeedLoader.medicationId('vitamin_d');

  setUp(() {
    db = createTestDb();
    meds = MedicationService(
      medications: DriftMedicationRepository(db),
      logs: DriftMedicationLogRepository(db),
    );
  });
  tearDown(() => db.close());

  Future<void> seed(WidgetTester tester, [Future<void> Function()? more]) async {
    await tester.runAsync(() => seedLoaderFor(db).seedIfNeeded());
    if (more != null) await tester.runAsync(more);
  }

  /// Bugün ekranını açar; açılan rotaların adları dönen listeye yazılır.
  Future<List<String?>> openToday(
    WidgetTester tester, {
    List<Override>? extra,
    Listenable? refresh,
  }) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final pushed = <String?>[];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(_now),
        ...?extra,
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(refresh: refresh),
        onGenerateRoute: (settings) {
          pushed.add(settings.name);
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('hedef')),
          );
        },
      ),
    ));
    await tester.pumpAndSettle();
    return pushed;
  }

  group('dozlar', () {
    testWidgets('planlı doz yoksa ipucu çıkar', (tester) async {
      await seed(tester);
      await openToday(tester);

      expect(find.text('Bugünkü dozlar'), findsOneWidget);
      expect(find.byKey(const Key('bugun_doz_yok')), findsOneWidget);
      expect(find.text('Bugün için planlı doz yok.'), findsOneWidget);
    });

    testWidgets('bugünün dozları saatiyle listelenir, "Aldım" ve "Atla" yazar',
        (tester) async {
      await seed(tester, () async {
        await meds.setRoutine(
            medicationId: parol, times: ['08:30'], days: ['monday', 'friday']);
        await meds.setRoutine(medicationId: vitD, times: ['21:00'], days: ['friday']);
      });
      await openToday(tester);

      expect(find.byKey(Key('doz_$parol-08:30')), findsOneWidget);
      expect(find.byKey(Key('doz_$vitD-21:00')), findsOneWidget);
      expect(find.text('0/2 alındı'), findsOneWidget);

      await tester.tap(find.byKey(Key('doz_al_$parol-08:30')));
      await tester.pumpAndSettle();
      expect(find.byKey(Key('doz_alindi_$parol-08:30')), findsOneWidget);
      expect(find.byKey(Key('doz_al_$parol-08:30')), findsNothing);
      expect(find.text('1/2 alındı'), findsOneWidget);

      await tester.tap(find.byKey(Key('doz_atla_$vitD-21:00')));
      await tester.pumpAndSettle();
      expect(find.byKey(Key('doz_atlandi_$vitD-21:00')), findsOneWidget);
      // Atlanan doz "alındı" sayılmaz.
      expect(find.text('1/2 alındı'), findsOneWidget);
    });

    testWidgets('yazma hatasında uyarı çıkar, doz bekliyor kalır', (tester) async {
      await seed(tester, () async {
        await meds.setRoutine(medicationId: parol, times: ['08:30'], days: ['friday']);
      });
      await openToday(tester, extra: [
        doseServiceProvider.overrideWithValue(_FailingDoseService(db)),
      ]);

      await tester.tap(find.byKey(Key('doz_al_$parol-08:30')));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byKey(Key('doz_al_$parol-08:30')), findsOneWidget);
      expect(find.byKey(Key('doz_alindi_$parol-08:30')), findsNothing);
    });
  });

  group('günlük kayıt', () {
    testWidgets('kayıt yokken dört kutu "Ekle" der, 0/4 dolu', (tester) async {
      await seed(tester);
      await openToday(tester);

      expect(find.text('0/4 dolu'), findsOneWidget);
      expect(find.text('Ekle'), findsNWidgets(4));
    });

    testWidgets('kayıt varsa değerler gösterilir, 4/4 dolu', (tester) async {
      await seed(tester, () async {
        await DriftDailyLogRepository(db, clock: _now).upsert(
          logDate: '2026-11-06',
          sleepHours: 7.5,
          waterIntake: 2,
          mood: 4,
          energyLevel: 3,
        );
      });
      await openToday(tester);

      expect(find.text('4/4 dolu'), findsOneWidget);
      expect(find.text('7,5 sa'), findsOneWidget);
      expect(find.text('2 L'), findsOneWidget);
      expect(find.text('4/5'), findsOneWidget);
      expect(find.text('3/5'), findsOneWidget);
      expect(find.text('Ekle'), findsNothing);
    });
  });

  group('gezinme', () {
    testWidgets('kutular, semptom düğmesi ve avatar doğru ekrana gider',
        (tester) async {
      await seed(tester);
      final pushed = await openToday(tester);

      for (final entry in {
        'bugun_gunluk_0': '/daily-log',
        'bugun_gunluk_3': '/daily-log',
        'bugun_semptom': '/symptoms',
        'ana_ayarlar': '/settings',
      }.entries) {
        await tester.tap(find.byKey(Key(entry.key)));
        await tester.pumpAndSettle();
        expect(pushed.last, entry.value);
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('dışarıdan sinyal gelince ekran yeniden okur', (tester) async {
      final signal = ValueNotifier<int>(0);
      addTearDown(signal.dispose);
      await seed(tester);
      await openToday(tester, refresh: signal);
      expect(find.byKey(const Key('bugun_doz_yok')), findsOneWidget);

      await tester.runAsync(() => meds.setRoutine(
          medicationId: parol, times: ['08:30'], days: ['friday']));
      signal.value++;
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();

      expect(find.byKey(Key('doz_$parol-08:30')), findsOneWidget);
    });
  });
}
