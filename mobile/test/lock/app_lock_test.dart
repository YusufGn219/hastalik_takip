import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/lock/app_lock_controller.dart';
import 'package:mobile/features/lock/app_lock_platform.dart';
import 'package:mobile/features/lock/app_lock_store.dart';
import 'package:mobile/features/lock/pin_hasher.dart';
import 'package:mobile/features/lock/recovery_code.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hızlı test için düşük yinelenme sayısı.
const int _iter = 10;

class FakeBiometric implements BiometricAuthenticator {
  bool result = true;
  int calls = 0;
  Completer<bool>? hold;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> authenticate(String reason) async {
    calls++;
    final h = hold;
    if (h != null) return h.future;
    return result;
  }
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
  _Env(this.prefs);

  final SharedPreferences prefs;
  DateTime now = DateTime(2026, 11, 5, 10);
  final bio = FakeBiometric();
  final wiper = FakeWiper();

  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      appLockClockProvider.overrideWithValue(() => now),
      pinIterationsProvider.overrideWithValue(_iter),
      biometricAuthenticatorProvider.overrideWithValue(bio),
      dataWiperProvider.overrideWithValue(wiper),
    ]);
    addTearDown(c.dispose);
    return c;
  }
}

Future<_Env> _env({Map<String, Object> extra = const {}}) async {
  SharedPreferences.setMockInitialValues({...extra});
  return _Env(await SharedPreferences.getInstance());
}

/// Kilidi kurar, kilidi açık bırakır; (ortam, kap, denetleyici, kurtarma kodu).
Future<(_Env, ProviderContainer, AppLockController, String)> _setUp({
  String pin = '1234',
  bool biometric = false,
  int? timeout,
}) async {
  final env = await _env();
  final c = env.container();
  final n = c.read(appLockProvider.notifier);
  final code = await n.enable(pin);
  if (biometric) await n.setBiometric(true);
  if (timeout != null) await n.setTimeout(timeout);
  return (env, c, n, code);
}

void main() {
  group('PIN özeti', () {
    test('PBKDF2-HMAC-SHA256 bilinen vektörlerle uyuşur', () {
      String hex(List<int> b) => b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
      final pw = utf8.encode('password');
      final salt = utf8.encode('salt');
      expect(hex(pbkdf2(pw, salt, 1, 32)), '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b');
      expect(hex(pbkdf2(pw, salt, 2, 32)), 'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43');
      expect(hex(pbkdf2(pw, salt, 4096, 32)), 'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a');
    });

    test('doğru PIN doğrulanır, yanlışı reddedilir; aynı PIN farklı tuzla farklı özet verir', () {
      const hasher = PinHasher(iterations: _iter);
      final s1 = hasher.newSalt();
      final s2 = hasher.newSalt();
      expect(s1, isNot(s2));
      final h = hasher.hash('1234', s1);
      expect(hasher.verify('1234', s1, h), isTrue);
      expect(hasher.verify('1235', s1, h), isFalse);
      expect(hasher.verify('1234', s2, h), isFalse);
      expect(h, isNot(contains('1234')));
      expect(hasher.hash('1234', s2), isNot(h));
    });

    test('isValidPin: yalnız 4-8 rakam', () {
      for (final ok in ['1234', '123456', '12345678']) {
        expect(isValidPin(ok), isTrue, reason: ok);
      }
      for (final bad in ['', '123', '123456789', '12a4', '12 34', '١٢٣٤', '1234\n']) {
        expect(isValidPin(bad), isFalse, reason: bad);
      }
    });

    test('lockoutDelay: ilk dört hata bedava, sonra giderek uzar', () {
      expect([for (var i = 0; i <= 4; i++) lockoutDelay(i)], everyElement(Duration.zero));
      expect(lockoutDelay(5), const Duration(seconds: 30));
      expect(lockoutDelay(6), const Duration(minutes: 1));
      expect(lockoutDelay(7), const Duration(minutes: 5));
      expect(lockoutDelay(8), const Duration(minutes: 15));
      expect(lockoutDelay(40), const Duration(minutes: 15));
    });
  });

  group('Kurtarma kodu üretimi', () {
    test('12 karakter, yalnız okunaklı alfabe; karışan karakterler (0 O 1 I L) yok', () {
      final rnd = Random(7);
      for (var i = 0; i < 200; i++) {
        final code = generateRecoveryCode(rnd);
        expect(code.length, 12);
        expect(isValidRecoveryCode(code), isTrue, reason: code);
        for (final bad in ['0', 'O', '1', 'I', 'L']) {
          expect(code, isNot(contains(bad)), reason: code);
        }
      }
      expect(recoveryAlphabet.length, 31);
    });

    test('kodlar birbirinden farklı (güvenli rastgele)', () {
      final codes = {for (var i = 0; i < 50; i++) generateRecoveryCode()};
      expect(codes.length, 50);
    });

    test('gösterim dörderli gruplar; girişte küçük harf, boşluk ve tire yok sayılır', () {
      expect(formatRecoveryCode('ABCDEFGHJKMN'), 'ABCD-EFGH-JKMN');
      expect(normalizeRecoveryCode(' abcd-efgh jkmn '), 'ABCDEFGHJKMN');
      expect(isValidRecoveryCode('ABCDEFGHJKM'), isFalse, reason: 'kısa');
      expect(isValidRecoveryCode('ABCDEFGHJKM0'), isFalse, reason: 'alfabede yok');
    });
  });

  group('AppLockStore', () {
    test('varsayılan kapalı; özet/tuz eksik bozuk kayıt kapalı sayılır (kullanıcı dışarıda kalmaz)', () async {
      final env = await _env();
      expect(AppLockStore(env.prefs).enabled, isFalse);

      final bozuk = await _env(extra: {AppLockStore.enabledKey: true});
      expect(AppLockStore(bozuk.prefs).enabled, isFalse);
      expect(bozuk.container().read(appLockProvider).locked, isFalse);
    });

    test('geçersiz kayıtlı bekleme süresi varsayılana döner', () async {
      final env = await _env(extra: {AppLockStore.timeoutKey: 77});
      expect(AppLockStore(env.prefs).timeoutSeconds, AppLockStore.defaultTimeoutSeconds);
    });
  });

  group('AppLockController: kurulum ve PIN', () {
    test('kilit hiç kurulmadıysa uygulama açık başlar (kilit isteğe bağlı)', () async {
      final env = await _env();
      final state = env.container().read(appLockProvider);
      expect(state.enabled, isFalse);
      expect(state.locked, isFalse);
      expect(state.hasRecovery, isFalse);
    });

    test('enable: PIN ve kurtarma kodu düz saklanmaz, uygulama açık kalır; soğuk başlangıçta kilitli başlar', () async {
      final env = await _env();
      final c = env.container();
      final code = await c.read(appLockProvider.notifier).enable('4821');

      expect(isValidRecoveryCode(code), isTrue);
      expect(c.read(appLockProvider).enabled, isTrue);
      expect(c.read(appLockProvider).locked, isFalse);
      expect(c.read(appLockProvider).hasRecovery, isTrue);
      final saved = env.prefs.getKeys().map((k) => '$k=${env.prefs.get(k)}').join('|');
      expect(saved, isNot(contains('4821')));
      expect(saved, isNot(contains(code)));

      final cold = env.container().read(appLockProvider);
      expect(cold.enabled, isTrue);
      expect(cold.locked, isTrue);
      expect(cold.pinLength, 4);
      expect(cold.hasRecovery, isTrue);
    });

    test('geçersiz PIN reddedilir ve hiçbir şey kaydedilmez', () async {
      final env = await _env();
      expect(() => env.container().read(appLockProvider.notifier).enable('12'), throwsArgumentError);
      await Future<void>.delayed(Duration.zero);
      expect(env.prefs.getKeys(), isEmpty);
    });

    test('doğru PIN kilidi açar, yanlış PIN açmaz', () async {
      final (_, c, n, _) = await _setUp();
      n.lockNow();
      expect(await n.checkPin('0000'), PinResult.wrong);
      expect(c.read(appLockProvider).locked, isTrue);
      expect(await n.checkPin('1234'), PinResult.ok);
      expect(c.read(appLockProvider).locked, isFalse);
    });

    test('5. yanlış denemede giriş 30 sn kapanır; bu sürede doğru PIN de kabul edilmez ve sayaç artmaz', () async {
      final (env, c, n, _) = await _setUp();
      n.lockNow();

      for (var i = 0; i < 4; i++) {
        expect(await n.checkPin('0000'), PinResult.wrong);
        expect(c.read(appLockProvider).isBlocked(env.now), isFalse);
      }
      expect(await n.checkPin('0000'), PinResult.wrong);
      expect(c.read(appLockProvider).isBlocked(env.now), isTrue);
      expect(c.read(appLockProvider).failures, 5);

      expect(await n.checkPin('1234'), PinResult.blocked);
      expect(c.read(appLockProvider).locked, isTrue);
      expect(c.read(appLockProvider).failures, 5, reason: 'kapalıyken deneme sayılmaz');

      env.now = env.now.add(const Duration(seconds: 31));
      expect(await n.checkPin('1234'), PinResult.ok);
      expect(c.read(appLockProvider).failures, 0);
    });

    test('bekleme süresi dolduktan sonraki yanlış deneme bir üst süreyi (1 dk) başlatır', () async {
      final (env, c, n, _) = await _setUp();
      for (var i = 0; i < 5; i++) {
        await n.checkPin('0000');
      }
      env.now = env.now.add(const Duration(seconds: 31));
      await n.checkPin('0000');

      expect(c.read(appLockProvider).failures, 6);
      expect(c.read(appLockProvider).blockedUntil, env.now.add(const Duration(minutes: 1)));
    });

    test('yanlış deneme sayacı ve bekleme uygulama kapanıp açılınca da sürer', () async {
      final (env, c, n, _) = await _setUp();
      for (var i = 0; i < 5; i++) {
        await n.checkPin('0000');
      }

      final again = env.container().read(appLockProvider);
      expect(c.read(appLockProvider).failures, 5);
      expect(again.failures, 5);
      expect(again.isBlocked(env.now), isTrue);
      expect(again.locked, isTrue);
    });

    test('changePin: eski PIN yanlışsa değişmez; doğruysa yenisi geçer; biyometrik, süre ve kurtarma kodu korunur', () async {
      final (_, c, n, code) = await _setUp(biometric: true, timeout: 60);

      expect(await n.changePin('9999', '5555'), PinResult.wrong);
      expect(await n.checkPin('5555', unlock: false), PinResult.wrong);

      expect(await n.changePin('1234', '556677'), PinResult.ok);
      expect(c.read(appLockProvider).pinLength, 6);
      expect(c.read(appLockProvider).biometric, isTrue);
      expect(c.read(appLockProvider).timeoutSeconds, 60);
      expect(await n.checkPin('1234', unlock: false), PinResult.wrong);
      expect(await n.checkPin('556677', unlock: false), PinResult.ok);

      // PIN değişince kurtarma kodu geçerli kalır.
      n.lockNow();
      expect((await n.recoverWithCode(code, '7788')).result, PinResult.ok);
    });

    test('changePin geçersiz yeni PIN\'i, eski PIN\'e deneme harcamadan reddeder', () async {
      final (_, c, n, _) = await _setUp();
      expect(() => n.changePin('0000', '12'), throwsArgumentError);
      expect(c.read(appLockProvider).failures, 0);
    });

    test('setTimeout yalnız tanımlı değerleri kabul eder', () async {
      final (env, _, n, _) = await _setUp();
      await n.setTimeout(300);
      expect(AppLockStore(env.prefs).timeoutSeconds, 300);
      expect(() => n.setTimeout(45), throwsArgumentError);
    });
  });

  group('AppLockController: kurtarma kodu', () {
    test('doğru kod: yeni PIN geçerli olur, yeni kod üretilir, eski kod ve eski PIN geçersiz, kilit açılır', () async {
      final (env, c, n, oldCode) = await _setUp();
      n.lockNow();

      // Kullanıcı kodu küçük harfle, tireli yazabilir.
      final typed = formatRecoveryCode(oldCode).toLowerCase();
      final out = await n.recoverWithCode(typed, '9876');

      expect(out.result, PinResult.ok);
      expect(out.newCode, isNotNull);
      expect(isValidRecoveryCode(out.newCode!), isTrue);
      expect(out.newCode, isNot(oldCode));
      expect(c.read(appLockProvider).locked, isFalse);
      expect(c.read(appLockProvider).hasRecovery, isTrue);

      expect(await n.checkPin('1234', unlock: false), PinResult.wrong, reason: 'eski PIN');
      expect(await n.checkPin('9876', unlock: false), PinResult.ok);
      expect((await n.recoverWithCode(oldCode, '1111')).result, PinResult.wrong, reason: 'eski kod');
      expect((await n.recoverWithCode(out.newCode!, '2222')).result, PinResult.ok, reason: 'yeni kod');

      final saved = env.prefs.getKeys().map((k) => '$k=${env.prefs.get(k)}').join('|');
      expect(saved, isNot(contains(out.newCode!)));
    });

    test('yanlış kod PIN\'i değiştirmez ve kilidi açmaz', () async {
      final (_, c, n, _) = await _setUp();
      n.lockNow();

      final out = await n.recoverWithCode('AAAA-BBBB-CCCC', '9876');
      expect(out.result, PinResult.wrong);
      expect(out.newCode, isNull);
      expect(c.read(appLockProvider).locked, isTrue);
      expect(await n.checkPin('1234', unlock: false), PinResult.ok, reason: 'PIN eskisi gibi');
    });

    test('geçersiz yeni PIN kodu denemeye harcamadan reddedilir', () async {
      final (_, c, n, code) = await _setUp();
      n.lockNow();
      expect(() => n.recoverWithCode(code, '12'), throwsArgumentError);
      expect(c.read(appLockProvider).failures, 0);
      expect(c.read(appLockProvider).locked, isTrue);
    });

    test('PIN ve kod aynı deneme sayacını paylaşır; 5. toplam yanlışta ikisi de kapanır', () async {
      final (env, c, n, code) = await _setUp();
      n.lockNow();

      await n.checkPin('0000');
      await n.checkPin('0000');
      await n.recoverWithCode('AAAA-BBBB-CCCC', '9876');
      await n.recoverWithCode('AAAA-BBBB-CCCC', '9876');
      expect(c.read(appLockProvider).isBlocked(env.now), isFalse);
      await n.checkPin('0000'); // toplam 5
      expect(c.read(appLockProvider).failures, 5);
      expect(c.read(appLockProvider).isBlocked(env.now), isTrue);

      // Kapalıyken doğru kod da, doğru PIN de kabul edilmez.
      expect((await n.recoverWithCode(code, '9876')).result, PinResult.blocked);
      expect(await n.checkPin('1234'), PinResult.blocked);
      expect(c.read(appLockProvider).locked, isTrue);

      env.now = env.now.add(const Duration(seconds: 31));
      expect((await n.recoverWithCode(code, '9876')).result, PinResult.ok);
      expect(c.read(appLockProvider).failures, 0);
    });

    test('kurtarma kodu kayıtlı değilse kod yolu çalışmaz (PIN yolu etkilenmez)', () async {
      final (env, _, n, _) = await _setUp();
      await env.prefs.remove(AppLockStore.recoverySaltKey);
      await env.prefs.remove(AppLockStore.recoveryHashKey);
      final c2 = env.container();
      expect(c2.read(appLockProvider).hasRecovery, isFalse);
      expect((await c2.read(appLockProvider.notifier).recoverWithCode('AAAA-BBBB-CCCC', '9876')).result, PinResult.wrong);
      expect(await c2.read(appLockProvider.notifier).checkPin('1234', unlock: false), PinResult.ok);
      expect(n, isNotNull);
    });

    test('regenerateRecoveryCode: yanlış PIN yeni kod vermez; doğru PIN yenisini verir, eskisi geçersiz olur', () async {
      final (_, _, n, oldCode) = await _setUp();

      final bad = await n.regenerateRecoveryCode('0000');
      expect(bad.result, PinResult.wrong);
      expect(bad.newCode, isNull);
      n.lockNow();
      expect((await n.recoverWithCode(oldCode, '4321')).result, PinResult.ok, reason: 'eski kod hâlâ geçerli');

      final fresh = await n.regenerateRecoveryCode('4321');
      expect(fresh.result, PinResult.ok);
      expect(fresh.newCode, isNot(oldCode));
      expect((await n.recoverWithCode(oldCode, '1111')).result, PinResult.wrong);
      expect((await n.recoverWithCode(fresh.newCode!, '1111')).result, PinResult.ok);
    });

    test('disable: yanlış PIN kapatmaz; doğru PIN PIN, kurtarma kodu ve her şeyi siler', () async {
      final (env, c, n, _) = await _setUp(biometric: true);

      expect(await n.disable('0000'), PinResult.wrong);
      expect(c.read(appLockProvider).enabled, isTrue);

      expect(await n.disable('1234'), PinResult.ok);
      expect(c.read(appLockProvider).enabled, isFalse);
      expect(c.read(appLockProvider).hasRecovery, isFalse);
      final store = AppLockStore(env.prefs);
      expect(store.hash, isNull);
      expect(store.salt, isNull);
      expect(store.recoveryHash, isNull);
      expect(store.recoverySalt, isNull);
      expect(env.container().read(appLockProvider).locked, isFalse);
    });
  });

  group('AppLockController: tüm veriyi silme (son çare)', () {
    test('silici çağrılır, kilit tamamen kalkar, yeni açılış kilitsiz olur; süre tercihi kalır', () async {
      final (env, c, n, _) = await _setUp(biometric: true, timeout: 300);
      n.lockNow();

      await n.wipeAllData();

      expect(env.wiper.calls, 1);
      final s = c.read(appLockProvider);
      expect(s.enabled, isFalse);
      expect(s.locked, isFalse);
      expect(s.hasRecovery, isFalse);
      expect(s.biometric, isFalse);
      expect(s.timeoutSeconds, 300);
      expect(env.container().read(appLockProvider).locked, isFalse);
      expect(AppLockStore(env.prefs).hash, isNull);
      expect(AppLockStore(env.prefs).recoveryHash, isNull);
    });

    test('silme başarısız olursa kilit olduğu gibi kalır ve hata yukarı çıkar', () async {
      final (env, c, n, code) = await _setUp();
      n.lockNow();
      env.wiper.error = StateError('disk dolu');

      await expectLater(n.wipeAllData(), throwsStateError);

      expect(c.read(appLockProvider).enabled, isTrue);
      expect(c.read(appLockProvider).locked, isTrue);
      expect(await n.checkPin('1234', unlock: false), PinResult.ok);
      expect((await n.recoverWithCode(code, '5555')).result, PinResult.ok);
    });

    test('silici tanımlı değilse sessizce başarılı görünmez', () async {
      final env = await _env();
      final c = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(env.prefs),
        pinIterationsProvider.overrideWithValue(_iter),
      ]);
      addTearDown(c.dispose);
      final n = c.read(appLockProvider.notifier);
      await n.enable('1234');
      await expectLater(n.wipeAllData(), throwsStateError);
      expect(c.read(appLockProvider).enabled, isTrue);
    });
  });

  group('AppLockController: arka plan ve biyometrik', () {
    test('arka plandan bekleme süresinden önce dönülürse kilitlenmez, süre dolunca kilitlenir', () async {
      final (env, c, n, _) = await _setUp(timeout: 30);

      n.appLeft();
      env.now = env.now.add(const Duration(seconds: 29));
      n.appReturned();
      expect(c.read(appLockProvider).locked, isFalse);

      n.appLeft();
      env.now = env.now.add(const Duration(seconds: 30));
      n.appReturned();
      expect(c.read(appLockProvider).locked, isTrue);
    });

    test('bekleme "hemen" ise her dönüşte kilitlenir', () async {
      final (_, c, n, _) = await _setUp(timeout: 0);
      n.appLeft();
      n.appReturned();
      expect(c.read(appLockProvider).locked, isTrue);
    });

    test('kilit kurulu değilken arka plan geçişleri bir şey yapmaz', () async {
      final env = await _env();
      final c = env.container();
      final n = c.read(appLockProvider.notifier);
      n.appLeft();
      env.now = env.now.add(const Duration(hours: 5));
      n.appReturned();
      expect(c.read(appLockProvider).locked, isFalse);
    });

    test('biyometrik başarılıysa kilit açılır; ayarda kapalıysa açılmaz; başarısızsa açılmaz', () async {
      final (_, c, n, _) = await _setUp(biometric: true);
      n.lockNow();
      expect(await n.authenticateBiometric('x'), isTrue);
      expect(c.read(appLockProvider).locked, isFalse);

      final (_, c2, n2, _) = await _setUp();
      n2.lockNow();
      await n2.authenticateBiometric('x');
      expect(c2.read(appLockProvider).locked, isTrue, reason: 'biyometrik ayarı kapalıyken açamaz');

      final (env3, c3, n3, _) = await _setUp(biometric: true);
      n3.lockNow();
      env3.bio.result = false;
      expect(await n3.authenticateBiometric('x'), isFalse);
      expect(c3.read(appLockProvider).locked, isTrue);
    });

    test('biyometrik pencere açıkken gelen arka plan/ön plan olayları kilidi yeniden kurmaz', () async {
      final (env, c, n, _) = await _setUp(biometric: true, timeout: 0);
      env.bio.hold = Completer<bool>();

      final pending = n.authenticateBiometric('x', unlock: false);
      n.appLeft();
      n.appReturned();
      expect(c.read(appLockProvider).locked, isFalse);
      env.bio.hold!.complete(true);
      await pending;
      n.appReturned();

      expect(c.read(appLockProvider).locked, isFalse);
    });
  });
}
