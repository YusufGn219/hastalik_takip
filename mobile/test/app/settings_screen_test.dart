import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/lock/app_lock_store.dart';
import 'package:mobile/features/home/home_screen.dart';
import 'package:mobile/features/lock/app_lock_controller.dart';
import 'package:mobile/features/lock/app_lock_gate.dart';
import 'package:mobile/features/lock/app_lock_platform.dart';
import 'package:mobile/features/lock/lock_settings_card.dart';
import 'package:mobile/features/settings/settings_screen.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Wiper implements DataWiper {
  int calls = 0;
  Object? error;

  @override
  Future<void> wipe() async {
    calls++;
    if (error != null) throw error!;
  }
}

class _NoBiometric implements BiometricAuthenticator {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> authenticate(String reason) async => false;
}

class _NoSecurity implements ScreenSecurity {
  @override
  Future<void> setSecure(bool secure) async {}
}

class _Env {
  _Env(this.prefs);

  final SharedPreferences prefs;
  final wiper = _Wiper();
  int restarts = 0;
}

late ProviderContainer _c;

/// Kilit kuruluysa [pin] önceki oturumda kurulmuş gibi hazırlanır.
Future<_Env> _env({String? pin}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  if (pin != null) {
    final c = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      pinIterationsProvider.overrideWithValue(10),
    ]);
    await c.read(appLockProvider.notifier).enable(pin);
    c.dispose();
  }
  return _Env(prefs);
}

/// Ana ekranın üstüne Ayarlar'ı açar (gerçek tema, gerçek rota adları).
Future<void> _mount(WidgetTester tester, _Env env, {String? unlockWith}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      sharedPreferencesProvider.overrideWithValue(env.prefs),
      pinIterationsProvider.overrideWithValue(10),
      biometricAuthenticatorProvider.overrideWithValue(_NoBiometric()),
      screenSecurityProvider.overrideWithValue(_NoSecurity()),
      dataWiperProvider.overrideWithValue(env.wiper),
      appRestartProvider.overrideWithValue(() async => env.restarts++),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => AppLockGate(child: child!),
      routes: {
        '/': (context) => Builder(builder: (context) {
              _c = ProviderScope.containerOf(context);
              return const HomeScreen();
            }),
        '/settings': (context) => const SettingsScreen(),
      },
    ),
  ));
  await tester.pump();
  await tester.pump();
  if (unlockWith != null) {
    await tester.runAsync(() => _c.read(appLockProvider.notifier).checkPin(unlockWith));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _openSettings(WidgetTester tester) async {
  await _tap(tester, find.byKey(const Key('ana_ayarlar')));
  expect(find.byType(SettingsScreen), findsOneWidget);
}

Future<void> _pin(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    await tester.tap(find.byKey(Key('pin_$d')));
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('ana ekrandaki ayarlar düğmesi Ayarlar\'ı açar; kilit kartı artık ana ekranda değil',
      (tester) async {
    final env = (await tester.runAsync(() => _env()))!;
    await _mount(tester, env);

    expect(find.byType(AppLockSettingsCard), findsNothing);
    await _openSettings(tester);

    expect(find.text('Ayarlar'), findsWidgets);
    expect(find.byType(AppLockSettingsCard), findsOneWidget);
    expect(find.text('Tüm verimi sil'), findsOneWidget);
  });

  group('Tüm verimi sil', () {
    testWidgets('kilitsizken: uyarıda vazgeçilirse hiçbir şey silinmez', (tester) async {
      final env = (await tester.runAsync(() => _env()))!;
      await _mount(tester, env);
      await _openSettings(tester);

      await _tap(tester, find.byKey(const Key('ayar_tum_veri_sil')));
      expect(find.text('Tüm veriler silinsin mi?'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('silme_vazgec')));

      expect(env.wiper.calls, 0);
      expect(env.restarts, 0);
    });

    testWidgets('kilitsizken: onaylanırsa veri silinir ve uygulama baştan kurulur', (tester) async {
      final env = (await tester.runAsync(() => _env()))!;
      await _mount(tester, env);
      await _openSettings(tester);

      await _tap(tester, find.byKey(const Key('ayar_tum_veri_sil')));
      await _tap(tester, find.byKey(const Key('silme_onay')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(env.wiper.calls, 1);
      expect(env.restarts, 1);
    });

    testWidgets('silme başarısız olursa restart yapılmaz ve hata gösterilir', (tester) async {
      final env = (await tester.runAsync(() => _env()))!;
      env.wiper.error = StateError('disk');
      await _mount(tester, env);
      await _openSettings(tester);

      await _tap(tester, find.byKey(const Key('ayar_tum_veri_sil')));
      await _tap(tester, find.byKey(const Key('silme_onay')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(env.restarts, 0);
      expect(find.text('Silinemedi, tekrar deneyin'), findsOneWidget);
    });

    testWidgets('kilit açıkken önce PIN istenir; vazgeçilirse uyarı bile açılmaz', (tester) async {
      final env = (await tester.runAsync(() => _env(pin: '1234')))!;
      await _mount(tester, env, unlockWith: '1234');
      await _openSettings(tester);

      await _tap(tester, find.byKey(const Key('ayar_tum_veri_sil')));
      expect(find.byKey(const Key('pin_dogrula_vazgec')), findsOneWidget);
      expect(find.text('Tüm veriler silinsin mi?'), findsNothing);
      await _tap(tester, find.byKey(const Key('pin_dogrula_vazgec')));

      expect(find.text('Tüm veriler silinsin mi?'), findsNothing);
      expect(env.wiper.calls, 0);
    });

    testWidgets('kilit açıkken yanlış PIN silmeyi açmaz', (tester) async {
      final env = (await tester.runAsync(() => _env(pin: '1234')))!;
      await _mount(tester, env, unlockWith: '1234');
      await _openSettings(tester);

      await _tap(tester, find.byKey(const Key('ayar_tum_veri_sil')));
      await _pin(tester, '9999');

      expect(find.byKey(const Key('pin_dogrula_hata')), findsOneWidget);
      expect(find.text('Tüm veriler silinsin mi?'), findsNothing);
      expect(env.wiper.calls, 0);
    });

    testWidgets('kilit açıkken doğru PIN + onay veriyi siler, kilit ayarı da sıfırlanır',
        (tester) async {
      final env = (await tester.runAsync(() => _env(pin: '1234')))!;
      await _mount(tester, env, unlockWith: '1234');
      await _openSettings(tester);

      await _tap(tester, find.byKey(const Key('ayar_tum_veri_sil')));
      await _pin(tester, '1234');
      expect(find.text('Tüm veriler silinsin mi?'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('silme_onay')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(env.wiper.calls, 1);
      expect(env.restarts, 1);
      expect(_c.read(appLockProvider).enabled, isFalse);
    });
  });
}
