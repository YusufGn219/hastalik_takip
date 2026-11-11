// Adım takibinin iki okuma yolunu yönetir. İKİSİ BİRBİRİNDEN BAĞIMSIZDIR:
//  * [onAppOpen]: uygulama açılırken / öne gelirken.
//  * [onRoutine]: saatlik arka plan görevi (WorkManager) çalıştığında.
// İkisi de aynı `StepService.record`'u kendi yol etiketiyle çağırır; biri hiç
// çalışmasa da öbürü okumasını yapar. Zamanlama (saatlik görevin kurulması ve
// iptali) okunan izin durumuna bağlanır: izin varsa kurulur, izin geri alınmışsa
// ya da sensör yoksa iptal edilir; böylece izni olmayan kullanıcıda saatlik
// görev boşuna uyanmaz.

import '../../data/database/enums.dart';
import '../step_source.dart';
import 'step_service.dart';

/// Saatlik arka plan görevinin zamanlayıcısı (Android'de WorkManager).
abstract class StepScheduler {
  /// Saatlik görevin kurulu olmasını sağlar (zaten kuruluysa dokunmaz).
  Future<void> ensureScheduled();

  /// Saatlik görevi iptal eder.
  Future<void> cancel();

  /// Telefonun "pil optimizasyonu" ayarlarını açar (üretici arka planı
  /// kısıtlıyorsa kullanıcı uygulamayı muaf tutabilsin diye).
  Future<void> openBatterySettings();
}

class StepTracking {
  StepTracking({required StepService service, required StepScheduler scheduler})
    : _service = service,
      _scheduler = scheduler;

  final StepService _service;
  final StepScheduler _scheduler;

  /// Açılış yolu: okur ve yazar; sonucu zamanlayıcıya yansıtır (OS görevi
  /// düşürmüşse yeniden kurulur). Hiçbir durumda istisna fırlatmaz.
  Future<StepReadStatus> onAppOpen() async {
    final status = await _read(StepSampleSources.open);
    await _syncSchedule(status);
    return status;
  }

  /// Rutin (arka plan) yolu: okur ve yazar. İzin yoksa ya da sensör yoksa
  /// kendini iptal eder. Hiçbir durumda istisna fırlatmaz.
  Future<StepReadStatus> onRoutine() async {
    final status = await _read(StepSampleSources.routine);
    if (status == StepReadStatus.noPermission || status == StepReadStatus.noSensor) {
      await _safely(_scheduler.cancel);
    }
    return status;
  }

  /// İzin yeni verildiğinde ya da kullanıcı takibi açtığında: hemen bir okuma
  /// yapar ve saatlik görevi kurar (açılış yolunun aynısı).
  Future<StepReadStatus> refresh() => onAppOpen();

  Future<StepReadStatus> _read(String source) async {
    try {
      return (await _service.record(source)).status;
    } catch (_) {
      return StepReadStatus.error;
    }
  }

  Future<void> _syncSchedule(StepReadStatus status) async {
    switch (status) {
      case StepReadStatus.ok:
        await _safely(_scheduler.ensureScheduled);
      case StepReadStatus.noPermission || StepReadStatus.noSensor:
        await _safely(_scheduler.cancel);
      case StepReadStatus.timeout || StepReadStatus.error:
        break; // geçici sorun: mevcut zamanlamaya dokunma
    }
  }

  Future<void> _safely(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Zamanlayıcı hatası okumayı etkilemez.
    }
  }
}
