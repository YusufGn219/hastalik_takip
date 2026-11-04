import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/lock/app_lock_controller.dart';
import 'package:mobile/features/lock/app_lock_gate.dart';
import 'package:mobile/features/lock/app_lock_native.dart';
import 'package:mobile/features/lock/app_lock_platform.dart';
import 'package:mobile/features/lock/app_lock_store.dart';
import 'package:mobile/features/lock/lock_settings_card.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeBiometric implements BiometricAuthenticator {
  bool available = true;
  bool result = true;
  int calls = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate(String reason) async {
    calls++;
    return result;
  }
}

class _Env {
  _Env(this.prefs);

  final SharedPreferences prefs;
  final bio = FakeBiometric();
  final secure = <bool>[];
}

class _Security implements ScreenSecurity {
  _Security(this.calls);
  final List<bool> calls;

  @override
  Future<void> setSecure(bool secure) async => calls.add(secure);
}

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

late ProviderContainer _c;

/// Kilit kuruluysa açılış kilitli olur; testlerin çoğu açık başlangıç ister.
Future<void> _mount(WidgetTester tester, _Env env, {bool unlock = false}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      sharedPreferencesProvider.overrideWithValue(env.prefs),
      pinIterationsProvider.overrideWithValue(10),
      biometricAuthenticatorProvider.overrideWithValue(env.bio),
      screenSecurityProvider.overrideWithValue(_Security(env.secure)),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => AppLockGate(child: child!),
      home: Scaffold(body: Builder(builder: (context) {
        _c = ProviderScope.containerOf(context);
        return const SingleChildScrollView(child: AppLockSettingsCard());
      })),
    ),
  ));
  await tester.pump();
  await tester.pump();
  if (unlock) {
    await tester.runAsync(() => _c.read(appLockProvider.notifier).checkPin('1234'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pin(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    await tester.tap(find.byKey(Key('pin_$d')));
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('kilit kapalıyken yalnız ana anahtar görünür', (tester) async {
    final env = (await tester.runAsync(_env))!;
    await _mount(tester, env);

    expect(tester.widget<SwitchListTile>(find.byKey(const Key('ayar_kilit'))).value, isFalse);
    expect(find.byKey(const Key('ayar_kilit_sure')), findsNothing);
    expect(find.byKey(const Key('ayar_kilit_biyometrik')), findsNothing);
    expect(find.byKey(const Key('ayar_kilit_simdi')), findsNothing);
  });

  testWidgets('anahtarla kilit kurulur: PIN, kurtarma kodu; sonra ek ayarlar görünür', (tester) async {
    final env = (await tester.runAsync(_env))!;
    await _mount(tester, env);

    await _tap(tester, find.byKey(const Key('ayar_kilit')));
    await _pin(tester, '4821');
    await _tap(tester, find.byKey(const Key('pin_devam')));
    await _pin(tester, '4821');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Kurtarma kodunuz'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('kurtarma_yazdim')));
    await _tap(tester, find.byKey(const Key('kurtarma_bitti')));

    expect(_c.read(appLockProvider).enabled, isTrue);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('ayar_kilit'))).value, isTrue);
    expect(find.byKey(const Key('ayar_kilit_sure')), findsOneWidget);
    expect(env.secure.last, isTrue);
  });

  testWidgets('kapatma: yanlış PIN kapatmaz, doğru PIN kapatır', (tester) async {
    final env = (await tester.runAsync(() => _env(pin: '1234')))!;
    await _mount(tester, env, unlock: true);

    await _tap(tester, find.byKey(const Key('ayar_kilit')));
    await _pin(tester, '0000');
    expect(find.byKey(const Key('pin_dogrula_hata')), findsOneWidget);
    expect(_c.read(appLockProvider).enabled, isTrue);

    await _pin(tester, '1234');
    await tester.pump(const Duration(milliseconds: 400));
    expect(_c.read(appLockProvider).enabled, isFalse);
    expect(env.secure.last, isFalse);
  });

  testWidgets('kapatma penceresinde vazgeçilirse kilit kalır', (tester) async {
    final env = (await tester.runAsync(() => _env(pin: '1234')))!;
    await _mount(tester, env, unlock: true);

    await _tap(tester, find.byKey(const Key('ayar_kilit')));
    await _tap(tester, find.byKey(const Key('pin_dogrula_vazgec')));

    expect(_c.read(appLockProvider).enabled, isTrue);
  });

  testWidgets('parmak izi anahtarı: telefonda yoksa görünmez', (tester) async {
    final env = (await tester.runAsync(() => _env(pin: '1234')))!;
    env.bio.available = false;
    await _mount(tester, env, unlock: true);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('ayar_kilit_biyometrik')), findsNothing);
  });

  testWidgets('parmak izi açılırken doğrulama istenir; başarısızsa açılmaz, başarılıysa açılır', (tester) async {
    final env = (await tester.runAsync(() => _env(pin: '1234')))!;
    env.bio.result = false;
    await _mount(tester, env, unlock: true);
    await tester.pump(const Duration(milliseconds: 100));

    await _tap(tester, find.byKey(const Key('ayar_kilit_biyometrik')));
    expect(env.bio.calls, 1);
    expect(_c.read(appLockProvider).biometric, isFalse);

    env.bio.result = true;
    await _tap(tester, find.byKey(const Key('ayar_kilit_biyometrik')));
    expect(env.bio.calls, 2);
    expect(_c.read(appLockProvider).biometric, isTrue);
    expect(_c.read(appLockProvider).locked, isFalse, reason: 'ayarlarda doğrulama kilidi tetiklemez');

    // Kapatırken doğrulama istenmez.
    await _tap(tester, find.byKey(const Key('ayar_kilit_biyometrik')));
    expect(env.bio.calls, 2);
    expect(_c.read(appLockProvider).biometric, isFalse);
  });

  testWidgets('kilitlenme süresi seçilir ve kaydedilir; "şimdi kilitle" kilidi kapatır', (tester) async {
    final env = (await tester.runAsync(() => _env(pin: '1234')))!;
    await _mount(tester, env, unlock: true);

    await _tap(tester, find.byKey(const Key('ayar_kilit_sure')).last);
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('5 dk sonra').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(_c.read(appLockProvider).timeoutSeconds, 300);
    expect(AppLockStore(env.prefs).timeoutSeconds, 300);

    await _tap(tester, find.byKey(const Key('ayar_kilit_simdi')));
    expect(find.byKey(const Key('kilit_ekrani')), findsOneWidget);
  });

  group('Android köprüleri (Dart tarafı)', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('MethodChannelScreenSecurity doğru kanal ve yöntemle çağrılır', () async {
      final calls = <MethodCall>[];
      const channel = MethodChannel(MethodChannelScreenSecurity.channelName);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

      await MethodChannelScreenSecurity().setSecure(true);
      await MethodChannelScreenSecurity().setSecure(false);

      expect(MethodChannelScreenSecurity.channelName, 'vitapuls/screen_security');
      expect(calls.map((c) => c.method), ['setSecure', 'setSecure']);
      expect(calls.map((c) => c.arguments), [true, false]);
    });

    test('kanal yoksa (eklenti yok) hata fırlatmaz', () async {
      await expectLater(MethodChannelScreenSecurity().setSecure(true), completes);
    });
  });
}
