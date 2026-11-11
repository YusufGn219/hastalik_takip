// Adım takibinin kullanıcı tarafı: açık mı, izin var mı, aç/kapat.
//
// Takip YALNIZ kullanıcı açınca çalışır ("adım takibi" anahtarı, varsayılan
// kapalı). Açma: izin istenir; verilirse bayrak yazılır, hemen bir okuma yapılır
// ve saatlik görev kurulur. Kapatma: bayrak yazılır ve saatlik görev iptal
// edilir; geçmiş okumalar silinmez. Açılış okuması bayrağa bakar; kapalıysa hiç
// okumaz (izin telefonda hâlâ verilmiş olsa bile).

import '../../data/repositories/settings_repository.dart';
import '../step_permission.dart';
import 'step_tracking.dart';

/// `app_settings` anahtarı: '1' = açık.
const stepTrackingEnabledKey = 'steps_tracking_enabled';

/// [StepControl.enable] sonucu.
enum StepEnableResult {
  /// Açıldı (izin var, bayrak yazıldı, ilk okuma yapıldı).
  enabled,

  /// İzin verilmedi; yeniden sorulabilir.
  denied,

  /// İzin kalıcı reddedilmiş; yalnız telefon ayarlarından açılır.
  permanentlyDenied,

  /// Bayrak yazılamadı (veritabanı hatası); takip açılmadı.
  failed,
}

/// Ayarlar kartının okuduğu durum.
class StepControlState {
  const StepControlState({required this.enabled, required this.permission});

  final bool enabled;
  final StepPermissionState permission;

  /// Kullanıcı açmış ama izin sonradan telefon ayarlarından geri alınmış.
  bool get permissionLost => enabled && permission != StepPermissionState.granted;
}

class StepControl {
  StepControl({
    required SettingsRepository settings,
    required StepPermission permission,
    required StepTracking tracking,
    required StepScheduler scheduler,
  }) : _settings = settings,
       _permission = permission,
       _tracking = tracking,
       _scheduler = scheduler;

  final SettingsRepository _settings;
  final StepPermission _permission;
  final StepTracking _tracking;
  final StepScheduler _scheduler;

  Future<bool> isEnabled() async => (await _settings.get(stepTrackingEnabledKey)) == '1';

  Future<StepControlState> state() async => StepControlState(
    enabled: await isEnabled(),
    permission: await _permission.status(),
  );

  /// Açılış okuması: yalnız takip açıksa okur. Hata fırlatmaz.
  Future<void> onAppOpen() async {
    try {
      if (!await isEnabled()) return;
      await _tracking.onAppOpen();
    } catch (_) {
      // Adım okuması hiçbir zaman uygulamayı etkilemez.
    }
  }

  /// Takibi açar: izin ister; verilirse bayrağı yazar, okur ve görevi kurar.
  Future<StepEnableResult> enable() async {
    var permission = await _permission.status();
    if (permission == StepPermissionState.denied) {
      permission = await _permission.request();
    }
    switch (permission) {
      case StepPermissionState.denied:
        return StepEnableResult.denied;
      case StepPermissionState.permanentlyDenied:
        return StepEnableResult.permanentlyDenied;
      case StepPermissionState.granted:
        break;
    }
    try {
      await _settings.set(stepTrackingEnabledKey, '1');
    } catch (_) {
      return StepEnableResult.failed;
    }
    try {
      await _tracking.refresh();
    } catch (_) {
      // İlk okuma olmadı: açılış ve saatlik yol yeniden dener.
    }
    return StepEnableResult.enabled;
  }

  /// Takibi kapatır: bayrak yazılır, saatlik görev iptal edilir. Okumalar kalır.
  /// Bayrak yazılamazsa istisna yukarı çıkar (ekran "kapatılamadı" der).
  Future<void> disable() async {
    await _settings.set(stepTrackingEnabledKey, '0');
    try {
      await _scheduler.cancel();
    } catch (_) {
      // Görev iptal edilemese de bayrak kapalı: görev kendini iptal eder.
    }
  }

  Future<void> openPermissionSettings() => _permission.openSettings();
}
