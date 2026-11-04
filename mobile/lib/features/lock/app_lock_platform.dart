import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Parmak izi / yüz doğrulaması. Gerçek uygulama (adım 1b / grup 3) `local_auth`
/// ile yazılmış bir uygulamayı verir; testlerde ve desteksiz ortamda [NoBiometric]
/// (varsayılan) devrededir.
abstract class BiometricAuthenticator {
  /// Telefonda kayıtlı bir parmak izi / yüz var mı.
  Future<bool> isAvailable();

  /// Doğrulamayı ister; başarılıysa true. Hata ya da iptalde false.
  Future<bool> authenticate(String reason);
}

class NoBiometric implements BiometricAuthenticator {
  const NoBiometric();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> authenticate(String reason) async => false;
}

/// Ekran görüntüsünü ve son uygulamalar önizlemesini engelleyen katman (Android
/// `FLAG_SECURE`). Testlerde [NoScreenSecurity] devrededir.
abstract class ScreenSecurity {
  Future<void> setSecure(bool secure);
}

class NoScreenSecurity implements ScreenSecurity {
  const NoScreenSecurity();

  @override
  Future<void> setSecure(bool secure) async {}
}

/// "Tüm verimi sil ve baştan başla" son çaresi: şifreli veritabanını ve
/// Keystore'daki anahtarını siler. Gerçek uygulama grup 2'de yazılır; o zamana
/// kadar çağrılırsa sessizce başarılı görünmek yerine hata verir.
abstract class DataWiper {
  Future<void> wipe();
}

class UnconfiguredDataWiper implements DataWiper {
  const UnconfiguredDataWiper();

  @override
  Future<void> wipe() => throw StateError('dataWiperProvider geçersiz kılınmadı.');
}

/// Uygulamayı baştan kurar (yeni veritabanı, boş durum). "Tüm veriyi sil"den
/// sonra çağrılır; gerçeği `AppRoot` verir.
final appRestartProvider = Provider<Future<void> Function()>(
  (ref) => () => throw StateError('appRestartProvider geçersiz kılınmadı.'),
);

/// `main` içinde gerçekleriyle değiştirilir.
final biometricAuthenticatorProvider = Provider<BiometricAuthenticator>((ref) => const NoBiometric());
final screenSecurityProvider = Provider<ScreenSecurity>((ref) => const NoScreenSecurity());
final dataWiperProvider = Provider<DataWiper>((ref) => const UnconfiguredDataWiper());

/// Kilit zamanlaması için saat; testlerde sabit saatle değiştirilir.
final appLockClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Testlerde PIN özetini hızlandırmak için yinelenme sayısı değiştirilebilir.
final pinIterationsProvider = Provider<int>((ref) => 10000);
