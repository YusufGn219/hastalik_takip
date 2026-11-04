import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `main()` açılmış `SharedPreferences` ile bunu geçersiz kılmak zorundadır.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError(
    'sharedPreferencesProvider geçersiz kılınmadı: ProviderScope(overrides: ...) kullanın.',
  ),
);

/// Uygulama kilidinin telefondaki kaydı (SharedPreferences). Yedek dosyasına ve
/// veritabanına girmez; kilit yalnız bu telefona aittir. PIN ve kurtarma kodu
/// yalnız tuzlu özet olarak saklanır.
class AppLockStore {
  AppLockStore(this._prefs);

  static const String enabledKey = 'kilit_acik';
  static const String saltKey = 'kilit_tuz';
  static const String hashKey = 'kilit_ozet';
  static const String lengthKey = 'kilit_uzunluk';
  static const String recoverySaltKey = 'kilit_kurtarma_tuz';
  static const String recoveryHashKey = 'kilit_kurtarma_ozet';
  static const String biometricKey = 'kilit_biyometrik';
  static const String timeoutKey = 'kilit_sure';
  static const String failuresKey = 'kilit_hata';
  static const String blockedUntilKey = 'kilit_bekleme';

  /// Arka plandan dönünce kilit için varsayılan bekleme (sn).
  static const int defaultTimeoutSeconds = 30;

  /// Seçilebilir bekleme süreleri (sn); 0 = hemen.
  static const List<int> timeoutOptions = [0, 30, 60, 300];

  final SharedPreferences _prefs;

  /// Kilit gerçekten kurulu mu: anahtar açık ve özet/tuz/uzunluk eksiksiz.
  /// Bozuk bir kayıt kullanıcıyı dışarıda bırakmasın diye eksikse kapalı sayılır.
  bool get enabled =>
      (_prefs.getBool(enabledKey) ?? false) &&
      salt != null &&
      hash != null &&
      pinLength != null;

  String? get salt => _prefs.getString(saltKey);
  String? get hash => _prefs.getString(hashKey);
  int? get pinLength => _prefs.getInt(lengthKey);

  String? get recoverySalt => _prefs.getString(recoverySaltKey);
  String? get recoveryHash => _prefs.getString(recoveryHashKey);
  bool get hasRecovery => recoverySalt != null && recoveryHash != null;

  bool get biometric => _prefs.getBool(biometricKey) ?? false;

  int get timeoutSeconds {
    final value = _prefs.getInt(timeoutKey);
    return value != null && timeoutOptions.contains(value) ? value : defaultTimeoutSeconds;
  }

  int get failures => _prefs.getInt(failuresKey) ?? 0;

  /// Yanlış denemelerden sonra girişin kapalı olduğu an (epoch ms), yoksa null.
  int? get blockedUntilMs => _prefs.getInt(blockedUntilKey);

  Future<void> savePin({required String salt, required String hash, required int length}) async {
    await _prefs.setString(saltKey, salt);
    await _prefs.setString(hashKey, hash);
    await _prefs.setInt(lengthKey, length);
    await _prefs.setBool(enabledKey, true);
    await clearFailures();
  }

  Future<void> saveRecovery({required String salt, required String hash}) async {
    await _prefs.setString(recoverySaltKey, salt);
    await _prefs.setString(recoveryHashKey, hash);
  }

  Future<void> saveBiometric(bool value) => _prefs.setBool(biometricKey, value);

  Future<void> saveTimeout(int seconds) => _prefs.setInt(timeoutKey, seconds);

  Future<void> saveFailures(int count, int? blockedUntilMs) async {
    await _prefs.setInt(failuresKey, count);
    if (blockedUntilMs == null) {
      await _prefs.remove(blockedUntilKey);
    } else {
      await _prefs.setInt(blockedUntilKey, blockedUntilMs);
    }
  }

  Future<void> clearFailures() => saveFailures(0, null);

  /// Kilidi tamamen kaldırır (PIN, kurtarma kodu, tuzlar, biyometrik, sayaçlar).
  /// Bekleme süresi tercihi kalır.
  Future<void> clear() async {
    for (final key in [
      enabledKey,
      saltKey,
      hashKey,
      lengthKey,
      recoverySaltKey,
      recoveryHashKey,
      biometricKey,
      failuresKey,
      blockedUntilKey,
    ]) {
      await _prefs.remove(key);
    }
  }
}
