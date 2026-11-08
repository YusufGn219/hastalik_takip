import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/home/home_screen.dart';
import 'package:mobile/features/onboarding/onboarding_screen.dart';
import 'package:mobile/features/onboarding/start_screen.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../support/fake_settings_repository.dart';

/// Gerçek temayla açar: `ElevatedButton` tam genişlik ister (bkz. düğme dersi).
Widget _app(FakeSettingsRepository settings) => ProviderScope(
      overrides: [settingsRepositoryProvider.overrideWithValue(settings)],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const StartScreen(),
      ),
    );

void main() {
  testWidgets('ilk açılışta tanıtım gelir, ana ekran gelmez', (tester) async {
    final settings = FakeSettingsRepository();
    await tester.pumpWidget(_app(settings));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.text('Sağlığınızı takip edin'), findsOneWidget);
    expect(find.text('Geç'), findsOneWidget);
    expect(find.text('İleri'), findsOneWidget);
    // Tanıtım henüz bitmedi: "görüldü" yazılmaz.
    expect(settings.values[onboardingDoneKey], isNull);
  });

  testWidgets('dört sayfa sırayla gezilir; "dönem" denir, "atak" denmez',
      (tester) async {
    await tester.pumpWidget(_app(FakeSettingsRepository()));
    await tester.pumpAndSettle();

    final titles = [
      'Sağlığınızı takip edin',
      'Semptomlarınızı kaydedin',
      'Dönemleri yönetin',
      'Eğilimlerinizi görün',
    ];
    for (var i = 0; i < titles.length; i++) {
      expect(find.text(titles[i]), findsOneWidget);
      expect(find.textContaining('Atak'), findsNothing);
      expect(find.textContaining('atak'), findsNothing);
      if (i < titles.length - 1) {
        await tester.tap(find.text('İleri'));
        await tester.pumpAndSettle();
      }
    }
    // Son sayfada "İleri" yerine "Başla" var.
    expect(find.text('İleri'), findsNothing);
    expect(find.text('Başla'), findsOneWidget);
    expect(find.textContaining('Tıbbi tavsiye değildir'), findsOneWidget);
  });

  testWidgets('"Başla" ile ana ekrana geçilir ve görüldü kaydedilir',
      (tester) async {
    final settings = FakeSettingsRepository();
    await tester.pumpWidget(_app(settings));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('İleri'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Başla'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(settings.values[onboardingDoneKey], 'true');
  });

  testWidgets('"Geç" ilk sayfadan da ana ekrana götürür', (tester) async {
    final settings = FakeSettingsRepository();
    await tester.pumpWidget(_app(settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Geç'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(settings.values[onboardingDoneKey], 'true');
  });

  testWidgets('daha önce görüldüyse doğrudan ana ekran açılır', (tester) async {
    await tester.pumpWidget(_app(
      FakeSettingsRepository(initial: {onboardingDoneKey: 'true'}),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets('"true" dışındaki değer görülmedi sayılır', (tester) async {
    await tester.pumpWidget(_app(
      FakeSettingsRepository(initial: {onboardingDoneKey: 'false'}),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('ayar okunamazsa kullanıcı tanıtımda kalmaz, ana ekran açılır',
      (tester) async {
    await tester.pumpWidget(_app(FakeSettingsRepository(failReads: true)));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('ayar yazılamazsa akış yine de ana ekrana geçer', (tester) async {
    final settings = FakeSettingsRepository(failWrites: true);
    await tester.pumpWidget(_app(settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Geç'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(settings.values[onboardingDoneKey], isNull);
  });
}
