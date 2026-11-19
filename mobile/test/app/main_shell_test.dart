import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/features/home/home_screen.dart';
import 'package:mobile/features/lock/app_lock_store.dart';
import 'package:mobile/features/shell/health_hub_screen.dart';
import 'package:mobile/features/shell/main_shell.dart';
import 'package:mobile/features/timeline/screens/day_timeline_screen.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/test_support.dart';

Future<List<String?>> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final db = createTestDb();
  addTearDown(db.close);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final pushed = <String?>[];
  await tester.pumpWidget(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const MainShell(),
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

void main() {
  testWidgets('üç sekme var, Bugün açılır, Geçmiş ve Sağlık ilk dokunuşta kurulur',
      (tester) async {
    await _pump(tester);

    expect(find.text('Bugün'), findsOneWidget);
    expect(find.text('Geçmiş'), findsOneWidget);
    expect(find.text('Sağlık'), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(DayTimelineScreen), findsNothing);
    expect(find.byType(HealthHubScreen), findsNothing);

    await tester.tap(find.text('Geçmiş'));
    await tester.pumpAndSettle();
    expect(find.byType(DayTimelineScreen), findsOneWidget);

    await tester.tap(find.text('Sağlık'));
    await tester.pumpAndSettle();
    expect(find.byType(HealthHubScreen), findsOneWidget);
  });

  testWidgets('"+" düğmesi yalnız Bugün sekmesinde görünür', (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('kabuk_ekle')), findsOneWidget);

    await tester.tap(find.text('Sağlık'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kabuk_ekle')), findsNothing);

    await tester.tap(find.text('Bugün'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kabuk_ekle')), findsOneWidget);
  });

  testWidgets('"+" alt sayfasındaki dört seçenek doğru ekrana gider', (tester) async {
    final pushed = await _pump(tester);

    for (final entry in {
      'ekle_ilac': '/medication-log',
      'ekle_semptom': '/symptoms',
      'ekle_gunluk': '/daily-log',
      'ekle_olcum': '/readings',
    }.entries) {
      await tester.tap(find.byKey(const Key('kabuk_ekle')));
      await tester.pumpAndSettle();
      expect(find.text('Ne eklemek istersiniz?'), findsOneWidget);
      await tester.tap(find.byKey(Key(entry.key)));
      await tester.pumpAndSettle();
      expect(pushed.last, entry.value);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
    }
    expect(pushed.where((r) => r != '/'), hasLength(4));
  });

  testWidgets('Sağlık listesindeki her satır doğru ekrana gider', (tester) async {
    final pushed = await _pump(tester);
    await tester.tap(find.text('Sağlık'));
    await tester.pumpAndSettle();

    for (final entry in {
      'saglik_rutin': '/recurring',
      'saglik_ilaclar': '/medication-log',
      'saglik_kronik': '/chronic-conditions',
      'saglik_olcumler': '/readings',
      'saglik_boykilo': '/body',
      'saglik_alanlar': '/daily-fields',
      'saglik_profil': '/profile',
      'saglik_ayarlar': '/settings',
    }.entries) {
      await tester.tap(find.byKey(Key(entry.key)));
      await tester.pumpAndSettle();
      expect(pushed.last, entry.value);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
    }
  });
}
