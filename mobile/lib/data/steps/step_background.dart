// Saatlik adım okuması: WorkManager arka plan görevi ve zamanlayıcısı.
//
// Görev, uygulama kapalıyken telefonun kendi Flutter motorunda çalışır: şifreli
// veritabanını (anahtar Keystore'da) KENDİ bağlantısıyla açar, bir okuma yazar
// ve kapatır. Veritabanı ya da anahtar yoksa (kullanıcı veriyi silmişse) hiçbir
// şey oluşturmaz, kendini iptal eder.

import 'package:flutter/foundation.dart';
import 'package:app_settings/app_settings.dart';
import 'package:workmanager/workmanager.dart';

import '../../domain/services/step_service.dart';
import '../../domain/services/step_tracking.dart';
import '../../domain/step_source.dart';
import '../database/app_database.dart';
import '../database/database_opener.dart';
import '../repositories/step_sample_repository.dart';
import '../repositories/support.dart';
import 'android_step_source.dart';

/// WorkManager'a verilen görev adı ve benzersiz kimlik.
const stepTaskName = 'vitapuls.steps.read';
const stepUniqueName = 'vitapuls.steps.hourly';

/// Saatlik görevin aralığı.
const stepFrequency = Duration(hours: 1);

/// Arka plan görevinin giriş noktası; `Workmanager().initialize` buna verilir.
@pragma('vm:entry-point')
void stepCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != stepTaskName) return true;
    return runStepRoutine(
      openDatabase: openExistingAppDatabase,
      source: const AndroidStepSource(),
      scheduler: WorkmanagerStepScheduler(),
    );
  });
}

/// Bir rutin okumasını çalıştırır. Hiçbir durumda istisna fırlatmaz; sonraki
/// saatte yeniden denemek için her zaman true döner. Veritabanı her durumda kapatılır.
Future<bool> runStepRoutine({
  required Future<AppDatabase?> Function() openDatabase,
  required StepSource source,
  required StepScheduler scheduler,
  Clock? clock,
}) async {
  AppDatabase? db;
  try {
    db = await openDatabase();
    if (db == null) {
      // Veri silinmiş ya da henüz yok: görev boşuna uyanmasın.
      await scheduler.cancel();
      debugPrint('Adım rutini: veritabanı yok, görev iptal edildi.');
      return true;
    }
    final tracking = StepTracking(
      service: StepService(
        source: source,
        samples: DriftStepSampleRepository(db),
        clock: clock ?? DateTime.now,
      ),
      scheduler: scheduler,
    );
    final status = await tracking.onRoutine();
    debugPrint('Adım rutini: ${status.name}');
  } catch (e) {
    debugPrint('Adım rutini hata verdi: ${e.runtimeType}');
  } finally {
    try {
      await db?.close();
    } catch (_) {}
  }
  return true;
}

/// Saatlik görevi WorkManager ile kurar.
class WorkmanagerStepScheduler implements StepScheduler {
  WorkmanagerStepScheduler({Workmanager? workmanager})
    : _workmanager = workmanager ?? Workmanager();

  final Workmanager _workmanager;

  @override
  Future<void> ensureScheduled() => _workmanager.registerPeriodicTask(
    stepUniqueName,
    stepTaskName,
    frequency: stepFrequency,
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
  );

  @override
  Future<void> cancel() => _workmanager.cancelByUniqueName(stepUniqueName);

  @override
  Future<void> openBatterySettings() =>
      AppSettings.openAppSettings(type: AppSettingsType.batteryOptimization);
}
