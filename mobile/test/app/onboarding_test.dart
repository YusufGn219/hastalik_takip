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
  testWidgets('ilk açılışta karşılama gelir, ana ekran gelmez', (tester) async {
    final settings = FakeSettingsRepository();
    await tester.pumpWidget(_app(settings));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.text('Başlayalım'), findsOneWidget);
    // Karşılama henüz bitmedi: "görüldü" yazılmaz.
    expect(settings.values[onboardingDoneKey], isNull);
  });

  testWidgets('karşılama taslaktaki metinleri gösterir; "dönem" denir, "atak" denmez',
      (tester) async {
    await tester.pumpWidget(_app(FakeSettingsRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Vitapuls'), findsOneWidget);
    expect(
      find.text('İlaçlarınızı, belirtilerinizi ve günlük halinizi tek yerden, '
          'birkaç dokunuşla kaydedin.'),
      findsOneWidget,
    );
    expect(find.text('Verileriniz yalnız telefonunuzda, şifreli saklanır'), findsOneWidget);
    expect(find.text('Hesap açmak ya da internet gerekmez'), findsOneWidget);
    expect(find.text('İsterseniz PIN veya parmak iziyle kilitlersiniz'), findsOneWidget);
    expect(
      find.text('Vitapuls tıbbi tavsiye vermez; yalnızca kayıt tutmanıza yardım eder.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('karsilama_logo')), findsOneWidget);
    expect(find.textContaining('Atak'), findsNothing);
    expect(find.textContaining('atak'), findsNothing);
    // Eski sayfa gezintisi yok: İleri / Geç düğmeleri kalktı.
    expect(find.text('İleri'), findsNothing);
    expect(find.text('Geç'), findsNothing);
  });

  testWidgets('"Başlayalım" ile ana ekrana geçilir ve görüldü kaydedilir',
      (tester) async {
    final settings = FakeSettingsRepository();
    await tester.pumpWidget(_app(settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Başlayalım'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
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

  testWidgets('ayar okunamazsa kullanıcı karşılamada kalmaz, ana ekran açılır',
      (tester) async {
    await tester.pumpWidget(_app(FakeSettingsRepository(failReads: true)));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('ayar yazılamazsa akış yine de ana ekrana geçer', (tester) async {
    final settings = FakeSettingsRepository(failWrites: true);
    await tester.pumpWidget(_app(settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Başlayalım'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(settings.values[onboardingDoneKey], isNull);
  });
}
