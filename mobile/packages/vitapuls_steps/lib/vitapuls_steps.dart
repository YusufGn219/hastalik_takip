// Telefonun adım sayacını (Android `STEP_COUNTER`) tek seferlik okur.
//
// Sayaç, telefonun son yeniden başlatılmasından beri atılan TOPLAM adımdır;
// günlük geçmiş tutmaz. Okuma arka plan görevinde de (ikinci bir Flutter
// motorunda) çalışır, bu yüzden eklenti olarak yazılmıştır. İzni bu eklenti
// istemez; yalnızca verilip verilmediğine bakar ([StepReadStatus.noPermission]).

import 'package:flutter/services.dart';

/// Okumanın sonucu.
enum StepReadStatus {
  /// Sayaç okundu.
  ok,

  /// Fiziksel aktivite izni (ACTIVITY_RECOGNITION) verilmemiş.
  noPermission,

  /// Telefonda adım sayacı sensörü yok.
  noSensor,

  /// Sensör süresi içinde değer vermedi.
  timeout,

  /// Beklenmeyen hata.
  error,
}

class StepCounterReading {
  const StepCounterReading({
    required this.status,
    this.counter,
    this.bootCount,
    this.uptimeMs,
  });

  final StepReadStatus status;

  /// Son yeniden başlatmadan beri toplam adım; yalnız [StepReadStatus.ok]'ta dolu.
  final int? counter;

  /// Telefonun açılış sayısı (`Settings.Global.BOOT_COUNT`); okunamazsa null.
  final int? bootCount;

  /// Okuma anındaki `SystemClock.elapsedRealtime()` (milisaniye): yeniden
  /// başlatmadan beri geçen süre.
  final int? uptimeMs;

  bool get isOk => status == StepReadStatus.ok;
}

class VitapulsSteps {
  VitapulsSteps._();

  static const MethodChannel _channel = MethodChannel('vitapuls/steps');

  /// Sayacı bir kez okur; [timeout] içinde değer gelmezse
  /// [StepReadStatus.timeout] döner. Hiçbir durumda istisna fırlatmaz.
  static Future<StepCounterReading> read({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>('read', {
        'timeoutMs': timeout.inMilliseconds,
      });
      if (raw == null) return const StepCounterReading(status: StepReadStatus.error);
      return parseReading(raw);
    } catch (_) {
      return const StepCounterReading(status: StepReadStatus.error);
    }
  }

  /// Kanaldan gelen haritayı okumaya çevirir (testlerde doğrudan denenir).
  static StepCounterReading parseReading(Map<String, Object?> raw) {
    final status = switch (raw['status']) {
      'ok' => StepReadStatus.ok,
      'noPermission' => StepReadStatus.noPermission,
      'noSensor' => StepReadStatus.noSensor,
      'timeout' => StepReadStatus.timeout,
      _ => StepReadStatus.error,
    };
    int? asInt(Object? v) => v is num ? v.toInt() : null;
    if (status != StepReadStatus.ok) return StepCounterReading(status: status);
    final counter = asInt(raw['counter']);
    final uptime = asInt(raw['uptimeMs']);
    if (counter == null || counter < 0 || uptime == null || uptime < 0) {
      return const StepCounterReading(status: StepReadStatus.error);
    }
    return StepCounterReading(
      status: status,
      counter: counter,
      bootCount: asInt(raw['bootCount']),
      uptimeMs: uptime,
    );
  }
}
