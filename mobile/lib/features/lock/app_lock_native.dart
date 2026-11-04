import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'app_lock_platform.dart';

/// Gerçek parmak izi / yüz doğrulaması (`local_auth`). Yalnız biyometrik: telefonun
/// kendi PIN'i değil, uygulamanın PIN'i yedek yoldur.
class LocalAuthBiometric implements BiometricAuthenticator {
  LocalAuthBiometric([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported() && (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (e) {
      debugPrint('Biyometrik durum okunamadı: ${e.runtimeType}');
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason, biometricOnly: true);
    } catch (e) {
      debugPrint('Biyometrik doğrulama başarısız: ${e.runtimeType}');
      return false;
    }
  }
}

/// Android `FLAG_SECURE`: ekran görüntüsünü ve son uygulamalar önizlemesini
/// engeller. Kanal adı `MainActivity.kt`'deki ile aynı olmalıdır.
class MethodChannelScreenSecurity implements ScreenSecurity {
  MethodChannelScreenSecurity([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'vitapuls/screen_security';

  final MethodChannel _channel;

  @override
  Future<void> setSecure(bool secure) async {
    try {
      await _channel.invokeMethod<void>('setSecure', secure);
    } catch (e) {
      debugPrint('Ekran güvenliği ayarlanamadı: ${e.runtimeType}');
    }
  }
}
