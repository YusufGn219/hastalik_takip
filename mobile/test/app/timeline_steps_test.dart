// Zaman çizelgesinde adımlar: toplam, "tahmini" notu, okuma yoksa kart yok,
// okuma hatasında çizelge yine açılır. Gerçek (bellek içi) veritabanı.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/enums.dart';
import 'package:mobile/data/repositories/step_sample_repository.dart';
import 'package:mobile/features/timeline/screens/day_timeline_screen.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../data/test_support.dart';

/// Saat: 2026-11-10 Salı 12:00.
DateTime _now() => DateTime(2026, 11, 10, 12, 0);

class _BrokenSamples extends DriftStepSampleRepository {
  _BrokenSamples(super.db);

  @override
  Future<List<StepSample>> listBetween(DateTime from, DateTime to) =>
      throw StateError('okunamadı');
}

void main() {
  late AppDatabase db;
  setUp(() => db = createTestDb());
  tearDown(() => db.close());

  Future<void> sample(WidgetTester tester, int counter, DateTime at) => tester.runAsync(
        () => DriftStepSampleRepository(db).add(
          counter: counter,
          bootCount: 1,
          uptimeMs: 3600000,
          sampledAt: at,
          source: StepSampleSources.routine,
        ),
      );

  Future<void> openApp(WidgetTester tester, {List<Override>? extra}) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(_now),
        ...?extra,
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const DayTimelineScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('sık okumalarda toplam görünür, "tahmini" notu yok', (tester) async {
    await sample(tester, 1000, DateTime(2026, 11, 10, 8, 0));
    await sample(tester, 1500, DateTime(2026, 11, 10, 8, 30));
    await sample(tester, 2300, DateTime(2026, 11, 10, 9, 0));
    await openApp(tester);
    expect(find.byKey(const ValueKey('timeline-steps')), findsOneWidget);
    expect(find.text('Adımlar'), findsOneWidget);
    expect(find.text('Toplam: 1.300 adım'), findsOneWidget);
    expect(find.byKey(const ValueKey('timeline-steps-estimated')), findsNothing);
  });

  testWidgets('uzun okuma aralığında "tahmini" notu çıkar', (tester) async {
    await sample(tester, 1000, DateTime(2026, 11, 10, 8, 0));
    await sample(tester, 3000, DateTime(2026, 11, 10, 11, 0));
    await openApp(tester);
    expect(find.text('Toplam: 2.000 adım'), findsOneWidget);
    expect(find.byKey(const ValueKey('timeline-steps-estimated')), findsOneWidget);
  });

  testWidgets('hiç okuma yoksa adım kartı görünmez', (tester) async {
    await openApp(tester);
    expect(find.byKey(const ValueKey('timeline-steps')), findsNothing);
    expect(find.text('Adımlar'), findsNothing);
  });

  testWidgets('yalnız önceki günün okumaları bugünün kartını göstermez', (tester) async {
    await sample(tester, 1000, DateTime(2026, 11, 9, 9, 0));
    await sample(tester, 4000, DateTime(2026, 11, 9, 10, 0));
    await openApp(tester);
    expect(find.byKey(const ValueKey('timeline-steps')), findsNothing);
  });

  testWidgets('adım okunamazsa çizelge yine açılır, kart yok', (tester) async {
    await openApp(tester, extra: [
      stepSampleRepositoryProvider.overrideWith((ref) => _BrokenSamples(db)),
    ]);
    expect(find.byKey(const ValueKey('timeline-steps')), findsNothing);
    expect(find.text('Kayıtlar'), findsOneWidget);
  });
}
