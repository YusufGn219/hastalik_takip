// Adım kaynağı: telefonun adım sayacını okuyan şeyin arayüzü. Hesap servisi
// yalnızca bu arayüzü bilir; Android sensörü, ileride Health Connect ya da
// iPhone Sağlık uygulaması aynı yere takılabilir, testte sahtesi kullanılır.

/// Okumanın sonucu.
enum StepReadStatus {
  ok,

  /// Fiziksel aktivite izni verilmemiş.
  noPermission,

  /// Telefonda adım sayacı yok.
  noSensor,

  /// Sensör süresi içinde değer vermedi.
  timeout,

  /// Beklenmeyen hata.
  error,
}

class StepReading {
  const StepReading({
    required this.status,
    this.counter,
    this.bootCount,
    this.uptimeMs,
  });

  final StepReadStatus status;

  /// Son yeniden başlatmadan beri toplam adım; yalnız [StepReadStatus.ok]'ta dolu.
  final int? counter;

  /// Telefonun açılış sayısı; bilinmiyorsa null.
  final int? bootCount;

  /// Okuma anında yeniden başlatmadan beri geçen süre (ms); yalnız ok'ta dolu.
  final int? uptimeMs;

  bool get isOk => status == StepReadStatus.ok;
}

abstract class StepSource {
  /// Sayacı bir kez okur; hiçbir durumda istisna fırlatmaz.
  Future<StepReading> read();
}
