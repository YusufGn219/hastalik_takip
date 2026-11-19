import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/database_error_app.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/features/home/home_screen.dart';
import 'package:mobile/features/lock/app_lock_store.dart';
import 'package:mobile/features/onboarding/start_screen.dart';
import 'package:mobile/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/test_support.dart';
import '../support/fake_settings_repository.dart';

void main() {
  group('MyApp', () {
    testWidgets('giriş ekranı olmadan, tanıtım görüldüyse ana ekrana açılır',
        (tester) async {
      final db = createTestDb();
      addTearDown(db.close);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsRepositoryProvider.overrideWithValue(
            FakeSettingsRepository(initial: {onboardingDoneKey: 'true'}),
          ),
        ],
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
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsRepositoryProvider.overrideWithValue(
            FakeSettingsRepository(initial: {onboardingDoneKey: 'true'}),
          ),
        ],
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
