import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/lock/app_lock_controller.dart';
import 'package:mobile/features/lock/app_lock_gate.dart';
import 'package:mobile/features/lock/app_lock_platform.dart';
import 'package:mobile/features/lock/app_lock_store.dart';
import 'package:mobile/features/lock/lock_flows.dart';
import 'package:mobile/features/lock/recovery_code.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int _iter = 10;

class FakeBiometric implements BiometricAuthenticator {
  bool result = true;
  int calls = 0;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> authenticate(String reason) async {
    calls++;
    return result;
  }
}

class FakeScreenSecurity implements ScreenSecurity {
  final List<bool> calls = [];

  @override
  Future<void> setSecure(bool secure) async => calls.add(secure);
}

class FakeWiper implements DataWiper {
  int calls = 0;
  Object? error;

  @override
  Future<void> wipe() async {
    calls++;
    if (error != null) throw error!;
  }
}

class _Env {
  _Env(this.prefs, this.code);

  final SharedPreferences prefs;

  /// Önceden kurulmuş kilidin kurtarma kodu (kilit kurulmadıysa null).
  final String? code;
  DateTime now = DateTime(2026, 11, 5, 10);
  final bio = FakeBiometric();
  final security = FakeScreenSecurity();
  final wiper = FakeWiper();
  int restarts = 0;

  List<Override> get overrides => [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appLockClockProvider.overrideWithValue(() => now),
        pinIterationsProvider.overrideWithValue(_iter),
        biometricAuthenticatorProvider.overrideWithValue(bio),
        screenSecurityProvider.overrideWithValue(security),
        dataWiperProvider.overrideWithValue(wiper),
        appRestartProvider.overrideWithValue(() async => restarts++),
      ];
}

/// Kilit kuruluysa (pin verilmişse) bir önceki oturumda kurulmuş gibi hazırlar;
/// bir sonraki açılış (soğuk başlangıç) kilitli başlar.
Future<_Env> _env({String? pin, bool biometric = false, int? timeout}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  String? code;
  if (pin != null) {
    final c = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      pinIterationsProvider.overrideWithValue(_iter),
    ]);
    final n = c.read(appLockProvider.notifier);
    code = await n.enable(pin);
    if (biometric) await n.setBiometric(true);
    if (timeout != null) await n.setTimeout(timeout);
    c.dispose();
  }
  return _Env(prefs, code);
}

int _tapped = 0;
BuildContext? _homeContext;

Future<void> _mount(WidgetTester tester, _Env env) async {
  _tapped = 0;
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: env.overrides,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => AppLockGate(child: child!),
      home: Scaffold(
        body: Consumer(builder: (context, ref, _) {
          _homeContext = context;
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ElevatedButton(key: const Key('ana_dugme'), onPressed: () => _tapped++, child: const Text('Ana ekran')),
              ElevatedButton(
                key: const Key('kilit_kur'),
                onPressed: () => runEnableLockFlow(context, ref),
                child: const Text('Kilidi kur'),
              ),
            ]),
          );
        }),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump();
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
  // Sayfa geçişi bitince rota ağaçtan bir sonraki karede kalkar.
  await tester.pump(const Duration(milliseconds: 100));
}

ProviderContainer _container() => ProviderScope.containerOf(_homeContext!);

void main() {
  group('Kilit kapısı ve kilit ekranı', () {
    testWidgets('kilit kurulu değilse kilit ekranı hiç çıkmaz', (tester) async {
      final env = (await tester.runAsync(_env))!;
      await _mount(tester, env);

      expect(find.byKey(const Key('kilit_ekrani')), findsNothing);
      await tester.tap(find.byKey(const Key('ana_dugme')));
      expect(_tapped, 1);
    });

    testWidgets('kilitli açılışta kilit ekranı çıkar ve altındaki ekrana dokunulamaz', (tester) async {
      final env = (await tester.runAsync(() => _env(pin: '1234')))!;
      await _mount(tester, env);

      expect(find.byKey(const Key('kilit_ekrani')), findsOneWidget);
      expect(find.text('Vitapuls kilitli'), findsOneWidget);
      expect(find.byKey(const Key('ana_dugme')), findsOneWidget);
      expect(find.byKey(const Key('ana_dugme')).hitTestable(), findsNothing);
      expect(find.bySemanticsLabel('Ana ekran'), findsNothing);
    });

    testWidgets('doğru PIN kilidi açar ve ana ekran yeniden kullanılabilir olur', (tester) async {
      final env = (await tester.runAsync(() => _env(pin: '1234')))!;
      await _mount(tester, env);

      await _pin(tester, '1234');

      expect(find.byKey(const Key('kilit_ekrani')), findsNothing);
      await tester.tap(find.byKey(const Key('ana_dugme')));
      expect(_tapped, 1);
    });

    testWidgets('yanlış PIN mesaj gösterir; ardından doğru PIN açar', (tester) async {
      final env = (await tester.runAsync(() => _env(pin: '1234')))!;
      await _mount(tester, env);

      await _pin(tester, '0000');
      expect(find.text('Yanlış PIN'), findsOneWidget);
      expect(find.byKey(const Key('kilit_ekrani')), findsOneWidget);

      await _pin(tester, '1234');
      expect(find.byKey(const Key('kilit_ekrani')), findsNothing);
    });

    testWidgets('5 yanlış denemeden sonra tuşlar kapanır, kalan süre yazılır; süre dolunca açılır', (tester) async {
      final env = (await tester.runAsync(() => _env(pin: '1234')))!;
      await _mount(tester, env);

      for (var i = 0; i < 5; i++) {
        await _pin(tester, '0000');
      }

      expect(find.textContaining('Çok fazla yanlış deneme'), findsOneWidget);
      expect(find.textContaining('30 sn'), findsOneWidget);
      await _pin(tester, '1234');
      expect(find.byKey(const Key('kilit_ekrani')), findsOneWidget, reason: 'kapalıyken doğru PIN de açmaz');

      env.now = env.now.add(const Duration(seconds: 31));
      await tester.pump(const Duration(seconds: 1));
      await _pin(tester, '1234');
      expect(find.byKey(const Key('kilit_ekrani')), findsNothing);
    });

    testWidgets('6 haneli PIN: 4 hane yetmez; silme tuşu son haneyi siler', (tester) async {
      final env = (await tester.runAsync(() => _env(pin: '123456')))!;
      await _mount(tester, env);

      await _pin(tester, '1234');
      expect(find.byKey(const Key('kilit_ekrani')), findsOneWidget);
      expect(find.text('Yanlış PIN'), findsNothing);

      await _pin(tester, '9');
      await tester.tap(find.byKey(const Key('pin_sil')));
      await tester.pump();
      await _pin(tester, '6');
      expect(find.text('Yanlış PIN'), findsNothing);
      await tester.tap(find.byKey(const Key('pin_sil')));
      await tester.pump();
      await _pin(tester, '56');
      expect(find.byKey(const Key('kilit_ekrani')), findsNothing);
    });

    testWidgets('biyometrik açıksa kilit ekranı PIN girmeden otomatik açılır', (tester) async {
      final env = (await tester.runAsync(() => _env(pin: '1234', biometric: true)))!;
      await _mount(tester, env);
      await tester.pump();
      await tester.pump();

      expect(env.bio.calls, 1);
      expect(find.byKey(const Key('kilit_ekrani')), findsNothing);
    });

    testWidgets('biyometrik başarısızsa kilit ekranı kalır; düğmeyle yeniden denenir; PIN yedek yoldur', (tester) async {
      final env = (await tester.runAsync(() => _env(pin: '1234', biometric: true)))!;
      env.bio.result = false;
      await _mount(tester, env);
      await tester.pump();

      expect(find.byKey(const Key('kilit_ekrani')), findsOneWidget);
      await tester.tap(find.byKey(const Key('kilit_biyometrik')));
      await tester.pump();
      expect(env.bio.calls, 2);

      await _pin(tester, '1234');
      expect(find.byKey(const Key('kilit_ekrani')), findsNothing);
    });

    testWidgets('biyometrik kapalıysa düğme yoktur ve sistem penceresi hiç istenmez', (tester) async {
      final env = (await tester.runAsync(() => _env(pin: '1234')))!;
      await _mount(tester, env);
      await tester.pump();

      expect(find.byKey(const Key('kilit_biyometrik')), findsNothing);
      expect(env.bio.calls, 0);
    });

    testWidgets('arka plandan süre dolunca dönülürse yeniden kilitlenir; dolmadan dönülürse kilitlenmez', (tester) async {
      final env = (await tester.runAsync(() => _env(pin: '1234', timeout: 30)))!;
      await _mount(tester, env);
      await _pin(tester, '1234');
      expect(find.byKey(const Key('kilit_ekrani')), findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      env.now = env.now.add(const Duration(seconds: 10));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byKey(const Key('kilit_ekrani')), findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      env.now = env.now.add(const Duration(seconds: 45));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byKey(const Key('kilit_ekrani')), findsOneWidget);
    });

    testWidgets('ekran görüntüsü engeli kilit kuruluyken açık, değilken kapalıdır', (tester) async {
      final env = (await tester.runAsync(() => _env(pin: '1234')))!;
      await _mount(tester, env);
      expect(env.security.calls.last, isTrue);

      final env2 = (await tester.runAsync(_env))!;
      await _mount(tester, env2);
      expect(env2.security.calls.last, isFalse);
    });
  });

  group('Kilidi kurma akışı', () {
    testWidgets('PIN iki kez girilir, kurtarma kodu bir kez gösterilir; "yazdım" işaretlenmeden bitirilemez', (tester) async {
      final env = (await tester.runAsync(_env))!;
      await _mount(tester, env);

      await _tap(tester, find.byKey(const Key('kilit_kur')));
      expect(find.byKey(const Key('pin_kurulum_baslik')), findsOneWidget);
      await _pin(tester, '482');
      expect(tester.widget<FilledButton>(find.byKey(const Key('pin_devam'))).onPressed, isNull);
      await _pin(tester, '1');
      await _tap(tester, find.byKey(const Key('pin_devam')));
      expect(find.text('PIN\'i tekrar girin'), findsOneWidget);
      await _pin(tester, '4821');
      await tester.pump(const Duration(milliseconds: 400));

      // Kilit kuruldu ama uygulama açık; kod gösteriliyor.
      expect(_container().read(appLockProvider).enabled, isTrue);
      expect(_container().read(appLockProvider).locked, isFalse);
      expect(find.text('Kurtarma kodunuz'), findsOneWidget);
      final shown = tester.widget<Text>(find.byKey(const Key('kurtarma_kodu'))).data!;
      expect(isValidRecoveryCode(normalizeRecoveryCode(shown)), isTrue);
      expect(tester.widget<FilledButton>(find.byKey(const Key('kurtarma_bitti'))).onPressed, isNull);

      // Geri tuşu kodu kapatmaz.
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Kurtarma kodunuz'), findsOneWidget);

      await _tap(tester, find.byKey(const Key('kurtarma_yazdim')));
      await _tap(tester, find.byKey(const Key('kurtarma_bitti')));
      expect(find.text('Kurtarma kodunuz'), findsNothing);
      expect(env.security.calls.last, isTrue);

      // Gösterilen kod gerçekten kayıtlı kodla eşleşiyor.
      final n = _container().read(appLockProvider.notifier);
      n.lockNow();
      await tester.pump();
      final out = await tester.runAsync(() => n.checkRecoveryCode(shown));
      expect(out, PinResult.ok);
    });

    testWidgets('tekrar girilen PIN uyuşmazsa uyarı çıkar, baştan başlanır; kilit kurulmaz', (tester) async {
      final env = (await tester.runAsync(_env))!;
      await _mount(tester, env);

      await _tap(tester, find.byKey(const Key('kilit_kur')));
      await _pin(tester, '4821');
      await _tap(tester, find.byKey(const Key('pin_devam')));
      await _pin(tester, '4822');

      expect(find.byKey(const Key('pin_uyusmadi')), findsOneWidget);
      expect(find.text('Yeni PIN belirleyin (4-8 rakam)'), findsOneWidget);
      expect(_container().read(appLockProvider).enabled, isFalse);
    });

    testWidgets('PIN ekranından geri dönülürse hiçbir şey kaydedilmez', (tester) async {
      final env = (await tester.runAsync(_env))!;
      await _mount(tester, env);

      await _tap(tester, find.byKey(const Key('kilit_kur')));
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 400));

      expect(_container().read(appLockProvider).enabled, isFalse);
      expect(env.prefs.getKeys(), isEmpty);
    });
  });

  group('PIN unutuldu: kurtarma', () {
    Future<void> openRecovery(WidgetTester tester) async {
      await _tap(tester, find.byKey(const Key('kilit_unuttum')));
      expect(find.byKey(const Key('kurtarma_alan')), findsOneWidget);
    }

    testWidgets('doğru kod → yeni PIN → yeni kod gösterilir (kilit hâlâ kapalı) → "Bitti"den sonra açılır', (tester) async {
      final env = (await tester.runAsync(() => _env(pin: '1234')))!;
      final oldCode = env.code!;
      await _mount(tester, env);
      await openRecovery(tester);

      await tester.enterText(find.byKey(const Key('kurtarma_alan')), formatRecoveryCode(oldCode).toLowerCase());
      await _tap(tester, find.byKey(const Key('kurtarma_devam')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      // Yeni PIN iste.
      expect(find.byKey(const Key('pin_kurulum_baslik')), findsOneWidget);
      await _pin(tester, '9876');
      await _tap(tester, find.byKey(const Key('pin_devam')));
      await _pin(tester, '9876');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 100));

      // Yeni kod gösteriliyor; kilit ekranı gösterim bitmeden kaybolmadı.
      expect(find.text('Kurtarma kodunuz'), findsOneWidget);
      expect(_container().read(appLockProvider).locked, isTrue);
      expect(find.byKey(const Key('ana_dugme')).hitTestable(), findsNothing);
      final newCode = normalizeRecoveryCode(tester.widget<Text>(find.byKey(const Key('kurtarma_kodu'))).data!);
      expect(newCode, isNot(oldCode));

      await _tap(tester, find.byKey(const Key('kurtarma_yazdim')));
      await _tap(tester, find.byKey(const Key('kurtarma_bitti')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(_container().read(appLockProvider).locked, isFalse);
      expect(find.byKey(const Key('kilit_ekrani')), findsNothing);
      await tester.tap(find.byKey(const Key('ana_dugme')));
      expect(_tapped, 1);

      // Eski PIN ve eski kod geçersiz; yenileri geçerli.
      final n = _container().read(appLockProvider.notifier);
      expect(await tester.runAsync(() => n.checkPin('1234', unlock: false)), PinResult.wrong);
      expect(await tester.runAsync(() => n.checkPin('9876', unlock: false)), PinResult.ok);
      expect(await tester.runAsync(() => n.checkRecoveryCode(oldCode)), PinResult.wrong);
      expect(await tester.runAsync(() => n.checkRecoveryCode(newCode)), PinResult.ok);
    });

    testWidgets('eksik/biçimsiz kod uyarılır; yanlış kod reddedilir ve kilit açılmaz', (tester) async {
      final env = (await tester.runAsync(() => _env(pin: '1234')))!;
      await _mount(tester, env);
      await openRecovery(tester);

      await tester.enterText(find.byKey(const Key('kurtarma_alan')), 'ABCD-EFGH');
      await _tap(tester, find.byKey(const Key('kurtarma_devam')));
      expect(find.text('Kod 12 karakter olmalı (harf ve rakam)'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('kurtarma_alan')), 'AAAA-BBBB-CCCC');
      await _tap(tester, find.byKey(const Key('kurtarma_devam')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Kod yanlış'), findsOneWidget);
      expect(find.byKey(const Key('pin_kurulum_baslik')), findsNothing);
      expect(_container().read(appLockProvider).locked, isTrue);
    });

    testWidgets('yeni PIN ekranından vazgeçilirse PIN ve kod değişmez', (tester) async {
      final env = (await tester.runAsync(() => _env(pin: '1234')))!;
      await _mount(tester, env);
      await openRecovery(tester);

      await tester.enterText(find.byKey(const Key('kurtarma_alan')), env.code!);
      await _tap(tester, find.byKey(const Key('kurtarma_devam')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('pin_kurulum_baslik')), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('kurtarma_alan')), findsOneWidget);
      final n = _container().read(appLockProvider.notifier);
      expect(await tester.runAsync(() => n.checkPin('1234', unlock: false)), PinResult.ok);
      expect(await tester.runAsync(() => n.checkRecoveryCode(env.code!)), PinResult.ok);
    });

    testWidgets('5 yanlış denemeden sonra kod girişi de kapanır (PIN ile ortak sayaç)', (tester) async {
      final env = (await tester.runAsync(() => _env(pin: '1234')))!;
      await _mount(tester, env);
      for (var i = 0; i < 3; i++) {
        await _pin(tester, '0000');
      }
      await openRecovery(tester);

      for (var i = 0; i < 2; i++) {
        await tester.enterText(find.byKey(const Key('kurtarma_alan')), 'AAAA-BBBB-CCCC');
        await _tap(tester, find.byKey(const Key('kurtarma_devam')));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(_container().read(appLockProvider).failures, 5);

      await tester.enterText(find.byKey(const Key('kurtarma_alan')), env.code!);
      await _tap(tester, find.byKey(const Key('kurtarma_devam')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Çok fazla yanlış deneme'), findsOneWidget);
      expect(find.byKey(const Key('pin_kurulum_baslik')), findsNothing);
    });
  });

  group('Son çare: tüm veriyi sil', () {
    Future<void> openWipeDialog(WidgetTester tester) async {
      await _tap(tester, find.byKey(const Key('kilit_unuttum')));
      await _tap(tester, find.byKey(const Key('kurtarma_kayip')));
      expect(find.text('Tüm veriler silinsin mi?'), findsOneWidget);
    }

    testWidgets('uyarıda vazgeçilirse hiçbir şey silinmez', (tester) async {
      final env = (await tester.runAsync(() => _env(pin: '1234')))!;
      await _mount(tester, env);
      await openWipeDialog(tester);

      await _tap(tester, find.byKey(const Key('silme_vazgec')));

      expect(env.wiper.calls, 0);
      expect(env.restarts, 0);
      expect(_container().read(appLockProvider).enabled, isTrue);
    });

    testWidgets('onaylanırsa veri silinir, kilit kalkar ve uygulama baştan kurulur', (tester) async {
      final env = (await tester.runAsync(() => _env(pin: '1234')))!;
      await _mount(tester, env);
      await openWipeDialog(tester);

      await _tap(tester, find.byKey(const Key('silme_onay')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(env.wiper.calls, 1);
      expect(env.restarts, 1);
      expect(env.prefs.getBool(AppLockStore.enabledKey), isNull);
      expect(find.byKey(const Key('kilit_ekrani')), findsNothing);
    });

    testWidgets('silme başarısız olursa kilit kalır, restart yapılmaz ve hata gösterilir', (tester) async {
      final env = (await tester.runAsync(() => _env(pin: '1234')))!;
      env.wiper.error = StateError('disk');
      await _mount(tester, env);
      await openWipeDialog(tester);

      await _tap(tester, find.byKey(const Key('silme_onay')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(env.restarts, 0);
      expect(_container().read(appLockProvider).enabled, isTrue);
      expect(find.text('Silinemedi, tekrar deneyin'), findsOneWidget);
    });
  });
}
