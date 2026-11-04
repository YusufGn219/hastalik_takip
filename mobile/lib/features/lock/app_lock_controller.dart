import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lock_platform.dart';
import 'app_lock_store.dart';
import 'pin_hasher.dart';
import 'recovery_code.dart';

/// Üst üste [failures] yanlış denemeden sonra girişin kapalı kalacağı süre.
/// İlk dört hata bedava; sonrası giderek uzar. PIN ve kurtarma kodu aynı sayacı
/// paylaşır.
Duration lockoutDelay(int failures) {
  if (failures < 5) return Duration.zero;
  return switch (failures) {
    5 => const Duration(seconds: 30),
    6 => const Duration(minutes: 1),
    7 => const Duration(minutes: 5),
    _ => const Duration(minutes: 15),
  };
}

enum PinResult { ok, wrong, blocked }

/// Kurtarma kodu işleminin sonucu. [newCode] yalnız [PinResult.ok] iken doludur
/// ve kullanıcıya **bir kez** gösterilir (düz saklanmaz).
class RecoveryOutcome {
  const RecoveryOutcome(this.result, [this.newCode]);

  final PinResult result;
  final String? newCode;
}

class AppLockState {
  const AppLockState({
    this.enabled = false,
    this.locked = false,
    this.pinLength = minPinLength,
    this.biometric = false,
    this.hasRecovery = false,
    this.timeoutSeconds = AppLockStore.defaultTimeoutSeconds,
    this.failures = 0,
    this.blockedUntil,
  });

  /// Uygulama kilidi kurulu mu.
  final bool enabled;

  /// Şu an kilit ekranı gösteriliyor mu (yalnız [enabled] iken true olabilir).
  final bool locked;

  final int pinLength;
  final bool biometric;

  /// Kurtarma kodu tanımlı mı (kilit ekranında "PIN'imi unuttum" için).
  final bool hasRecovery;

  /// Arka plandan dönünce yeniden kilitlenmeden önceki bekleme (sn); 0 = hemen.
  final int timeoutSeconds;

  final int failures;

  /// Yanlış denemeler yüzünden girişin kapalı olduğu an; geçmişse ya da yoksa serbest.
  final DateTime? blockedUntil;

  /// [now] anında giriş kapalı mı.
  bool isBlocked(DateTime now) => blockedUntil != null && blockedUntil!.isAfter(now);

  AppLockState copyWith({
    bool? enabled,
    bool? locked,
    int? pinLength,
    bool? biometric,
    bool? hasRecovery,
    int? timeoutSeconds,
    int? failures,
    DateTime? blockedUntil,
    bool clearBlocked = false,
  }) {
    return AppLockState(
      enabled: enabled ?? this.enabled,
      locked: locked ?? this.locked,
      pinLength: pinLength ?? this.pinLength,
      biometric: biometric ?? this.biometric,
      hasRecovery: hasRecovery ?? this.hasRecovery,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      failures: failures ?? this.failures,
      blockedUntil: clearBlocked ? null : (blockedUntil ?? this.blockedUntil),
    );
  }
}

final appLockStoreProvider = Provider<AppLockStore>((ref) => AppLockStore(ref.watch(sharedPreferencesProvider)));

final appLockProvider = NotifierProvider<AppLockController, AppLockState>(AppLockController.new);

/// Uygulama kilidinin durumu ve kuralları. Açılışta kilit kuruluysa uygulama
/// kilitli başlar; arka plandan [AppLockState.timeoutSeconds] sonra ya da daha
/// geç dönülürse yeniden kilitlenir.
///
/// PIN unutulursa 12 karakterlik kurtarma kodu yolu vardır. İkisi de kaybolursa
/// son çare [wipeAllData]'dır (veritabanı ve anahtarı silinir).
class AppLockController extends Notifier<AppLockState> {
  AppLockStore get _store => ref.read(appLockStoreProvider);
  DateTime Function() get _now => ref.read(appLockClockProvider);
  PinHasher get _hasher => PinHasher(iterations: ref.read(pinIterationsProvider));

  DateTime? _leftAt;
  bool _busy = false;

  /// Biyometrik penceresi açıkken uygulama "arka plana" gitmiş görünür; o sırada
  /// yaşam döngüsü olayları kilit kararı için yok sayılır.
  bool get busy => _busy;

  @override
  AppLockState build() {
    final store = _store;
    if (!store.enabled) return const AppLockState();
    final blocked = store.blockedUntilMs;
    return AppLockState(
      enabled: true,
      locked: true,
      pinLength: store.pinLength!,
      biometric: store.biometric,
      hasRecovery: store.hasRecovery,
      timeoutSeconds: store.timeoutSeconds,
      failures: store.failures,
      blockedUntil: blocked == null ? null : DateTime.fromMillisecondsSinceEpoch(blocked),
    );
  }

  /// PIN'i yazar (kurtarma koduna dokunmaz). Kurulum sonrası uygulama açık kalır.
  Future<void> _writePin(String pin) async {
    if (!isValidPin(pin)) throw ArgumentError('Geçersiz PIN');
    final salt = _hasher.newSalt();
    await _store.savePin(salt: salt, hash: _hasher.hash(pin, salt), length: pin.length);
    state = state.copyWith(
      enabled: true,
      locked: false,
      pinLength: pin.length,
      timeoutSeconds: _store.timeoutSeconds,
      failures: 0,
      clearBlocked: true,
    );
  }

  /// Yeni bir kurtarma kodu üretir, özetini saklar ve düz hâlini döndürür.
  /// Eski kod geçersiz olur.
  Future<String> _writeRecoveryCode() async {
    final code = generateRecoveryCode();
    final salt = _hasher.newSalt();
    await _store.saveRecovery(salt: salt, hash: _hasher.hash(code, salt));
    state = state.copyWith(hasRecovery: true);
    return code;
  }

  /// Kilidi kurar: PIN'i ve yeni bir kurtarma kodunu kaydeder. Dönen kod
  /// kullanıcıya **bir kez** gösterilir.
  Future<String> enable(String pin) async {
    if (!isValidPin(pin)) throw ArgumentError('Geçersiz PIN');
    // Önce kod: yarıda kalırsa PIN'siz kod kalır (kilit kapalı sayılır), tersi olmaz.
    final code = await _writeRecoveryCode();
    await _writePin(pin);
    return code;
  }

  /// [secret]'i saklı özetle denetler; sayaç ve bekleme PIN ile kurtarma kodu için
  /// ortaktır (iki yoldan ayrı ayrı deneme hakkı verilmez). Başarıda sayaçlar
  /// sıfırlanır, [unlock] doğruysa kilit açılır. Giriş kapalıyken
  /// ([PinResult.blocked]) deneme sayılmaz.
  Future<PinResult> _verify(String secret, String? salt, String? hash, {required bool unlock}) async {
    if (!state.enabled || salt == null || hash == null) return PinResult.wrong;

    final now = _now();
    if (state.isBlocked(now)) return PinResult.blocked;

    if (_hasher.verify(secret, salt, hash)) {
      await _store.clearFailures();
      state = state.copyWith(failures: 0, clearBlocked: true, locked: unlock ? false : state.locked);
      return PinResult.ok;
    }

    final failures = state.failures + 1;
    final delay = lockoutDelay(failures);
    final until = delay == Duration.zero ? null : now.add(delay);
    await _store.saveFailures(failures, until?.millisecondsSinceEpoch);
    state = state.copyWith(failures: failures, blockedUntil: until, clearBlocked: until == null);
    return PinResult.wrong;
  }

  /// [pin]'i denetler. Başarılıysa sayaçlar sıfırlanır ve [unlock] doğruysa kilit
  /// açılır.
  Future<PinResult> checkPin(String pin, {bool unlock = true}) =>
      _verify(pin, _store.salt, _store.hash, unlock: unlock);

  /// Eski PIN doğruysa PIN'i [newPin] ile değiştirir (parmak izi açık olsa da eski
  /// PIN sorulur). Kurtarma kodu aynı kalır.
  Future<PinResult> changePin(String oldPin, String newPin) async {
    if (!isValidPin(newPin)) throw ArgumentError('Geçersiz PIN');
    final result = await checkPin(oldPin, unlock: false);
    if (result == PinResult.ok) await _writePin(newPin);
    return result;
  }

  /// Kurtarma kodunu yalnız denetler (PIN değişmez, kilit açılmaz). Doğruysa
  /// sayaçlar sıfırlanır; yanlışsa PIN ile ortak sayaca işler. Ekran, yeni PIN'i
  /// sormadan önce kodu burada sınar.
  Future<PinResult> checkRecoveryCode(String code) =>
      _verify(normalizeRecoveryCode(code), _store.recoverySalt, _store.recoveryHash, unlock: false);

  bool _recoveryPending = false;

  /// [recoverWithCode] `unlock: false` ile bittiyse kilidi açar (yeni kod
  /// gösterildikten sonra). Bekleyen kurtarma yoksa hiçbir şey yapmaz.
  void finishRecovery() {
    if (!_recoveryPending) return;
    _recoveryPending = false;
    if (state.enabled) state = state.copyWith(locked: false);
  }

  /// PIN'i unutan kullanıcı için: [code] doğruysa PIN'i [newPin] yapar, **yeni** bir
  /// kurtarma kodu üretir (eskisi geçersiz) ve kilidi açar. Kodun düz hâli
  /// [RecoveryOutcome.newCode]'da bir kez döner. [unlock] yanlışsa kilit açık
  /// kalmaz; yeni kod gösterildikten sonra [finishRecovery] ile açılır (kilit
  /// ekranı kodu göstermeden kaybolmasın diye).
  Future<RecoveryOutcome> recoverWithCode(String code, String newPin, {bool unlock = true}) async {
    if (!isValidPin(newPin)) throw ArgumentError('Geçersiz PIN');
    final result = await _verify(
      normalizeRecoveryCode(code),
      _store.recoverySalt,
      _store.recoveryHash,
      unlock: false,
    );
    if (result != PinResult.ok) return RecoveryOutcome(result);
    final newCode = await _writeRecoveryCode();
    await _writePin(newPin);
    _leftAt = null;
    if (!unlock) {
      _recoveryPending = true;
      state = state.copyWith(locked: true);
    }
    return RecoveryOutcome(PinResult.ok, newCode);
  }

  /// PIN doğruysa yeni bir kurtarma kodu üretir (eskisi geçersiz). Ayarlardan.
  Future<RecoveryOutcome> regenerateRecoveryCode(String pin) async {
    final result = await checkPin(pin, unlock: false);
    if (result != PinResult.ok) return RecoveryOutcome(result);
    return RecoveryOutcome(PinResult.ok, await _writeRecoveryCode());
  }

  /// PIN doğruysa kilidi tamamen kaldırır (kurtarma kodu da silinir).
  Future<PinResult> disable(String pin) async {
    final result = await checkPin(pin, unlock: false);
    if (result == PinResult.ok) {
      await _store.clear();
      state = state.copyWith(
        enabled: false,
        locked: false,
        biometric: false,
        hasRecovery: false,
        failures: 0,
        clearBlocked: true,
      );
    }
    return result;
  }

  /// Son çare: PIN de kurtarma kodu da kaybolduysa. Şifreli veritabanı ve
  /// anahtarı silinir, kilit kaldırılır; **geri dönüşü yoktur**. Silme başarısız
  /// olursa kilit olduğu gibi kalır (hata yukarı fırlar).
  Future<void> wipeAllData() async {
    await ref.read(dataWiperProvider).wipe();
    await _store.clear();
    _leftAt = null;
    state = const AppLockState().copyWith(timeoutSeconds: _store.timeoutSeconds);
  }

  Future<void> setBiometric(bool value) async {
    if (!state.enabled || state.biometric == value) return;
    await _store.saveBiometric(value);
    state = state.copyWith(biometric: value);
  }

  Future<void> setTimeout(int seconds) async {
    if (!AppLockStore.timeoutOptions.contains(seconds)) throw ArgumentError('Geçersiz süre: $seconds');
    await _store.saveTimeout(seconds);
    state = state.copyWith(timeoutSeconds: seconds);
  }

  void lockNow() {
    if (state.enabled && !state.locked) state = state.copyWith(locked: true);
  }

  /// Biyometrik doğrulamayı ister. [unlock] doğruysa başarıda kilit açılır
  /// (kilit ekranı); yanlışsa yalnız sonuç döner (Ayarlar'da açarken deneme).
  Future<bool> authenticateBiometric(String reason, {bool unlock = true}) async {
    if (_busy) return false;
    _busy = true;
    try {
      final ok = await ref.read(biometricAuthenticatorProvider).authenticate(reason);
      if (ok && unlock && state.enabled && state.biometric) {
        _leftAt = null;
        state = state.copyWith(locked: false);
      }
      return ok;
    } finally {
      _busy = false;
      // Pencere kapanırken gelen "döndü" olayı kilidi yeniden kurmasın.
      _leftAt = null;
    }
  }

  /// Uygulama arka plana gitti.
  void appLeft() {
    if (!state.enabled || state.locked) return;
    _leftAt ??= _now();
  }

  /// Uygulama öne döndü: bekleme süresi dolduysa kilitler.
  void appReturned() {
    final left = _leftAt;
    _leftAt = null;
    if (_busy || left == null || !state.enabled || state.locked) return;
    if (_now().difference(left).inSeconds >= state.timeoutSeconds) {
      state = state.copyWith(locked: true);
    }
  }
}
