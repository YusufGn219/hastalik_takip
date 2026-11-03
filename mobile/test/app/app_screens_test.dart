import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/database_error_app.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/features/home/home_screen.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:mobile/main.dart';

import '../data/test_support.dart';

Widget _localized(Widget home, {RouteFactory? onGenerateRoute}) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
      onGenerateRoute: onGenerateRoute,
    );

void main() {
  group('HomeScreen', () {
    testWidgets('üç akışı Türkçe metinlerle gösterir', (tester) async {
      await tester.pumpWidget(_localized(const HomeScreen()));

      expect(find.text('Günlük kayıt'), findsOneWidget);
      expect(find.text('Semptom girişi'), findsOneWidget);
      expect(find.text('Dönemler'), findsOneWidget);
      // "Atak" kullanıcıya gösterilmez.
      expect(find.textContaining('Atak'), findsNothing);
    });

    testWidgets('her satır doğru ekrana yönlendirir', (tester) async {
      final pushed = <String?>[];
      await tester.pumpWidget(_localized(
        const HomeScreen(),
        onGenerateRoute: (settings) {
          pushed.add(settings.name);
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('hedef')),
          );
        },
      ));

      for (final entry in {
        'Günlük kayıt': '/daily-log',
        'Semptom girişi': '/symptoms',
        'Dönemler': '/episodes',
      }.entries) {
        await tester.tap(find.text(entry.key));
        await tester.pumpAndSettle();
        expect(pushed.last, entry.value);
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pumpAndSettle();
      }
      expect(pushed, hasLength(3));
    });
  });

  group('MyApp', () {
    testWidgets('giriş ekranı olmadan doğrudan ana ekrana açılır',
        (tester) async {
      final db = createTestDb();
      addTearDown(db.close);

      await tester.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MyApp(),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Günlük kayıt'), findsOneWidget);
      expect(find.textContaining('Giriş'), findsNothing);
    });

    testWidgets('uygulama başlığı çeviri dosyasından gelir', (tester) async {
      final db = createTestDb();
      addTearDown(db.close);
      await tester.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MyApp(),
      ));
      await tester.pumpAndSettle();

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      final context = tester.element(find.byType(HomeScreen));
      expect(app.onGenerateTitle!(context), 'Vitapuls');
    });
  });

  testWidgets('DatabaseErrorApp açılamama mesajını gösterir', (tester) async {
    await tester.pumpWidget(const DatabaseErrorApp());
    await tester.pumpAndSettle();

    expect(find.text('Veritabanı açılamadı'), findsOneWidget);
    expect(find.textContaining('yeniden açmayı deneyin'), findsOneWidget);
  });
}
