// Veritabanında metin (adıyla) saklanan sabit seçenekler.
// Drift `textEnum` kullanır: sıra değil ADI saklanır, bu yüzden değerlerin
// adı değiştirilmemeli (ekleme serbest).

/// Atak / dönem durumu. (Arayüzde "dönem" veya "olay" olarak gösterilir.)
enum EpisodeStatus { ongoing, resolved }

/// Doz birimi. Python'daki seçenek değerleriyle aynı.
enum DoseUnit { mg, ml, drop, capsule, tablet }

/// Günlük adet akışı yoğunluğu.
enum FlowIntensity { spotting, light, medium, heavy }

/// Döngü ile ilgili isteğe bağlı durum bilgisi.
enum CycleStatusKind {
  pregnancy,
  breastfeeding,
  menopause,
  hormonalContraception,
}

/// Ölçüm türü anahtarları. Tablo sütunu serbest metindir (yeni takip alanı
/// eklemek şema değişikliği gerektirmesin); bilinen anahtarlar burada.
abstract final class MeasurementTypes {
  // Günlük tetikleyiciler
  static const stress = 'stress'; // 1-5
  static const sleepQuality = 'sleep_quality'; // 1-5
  static const caffeine = 'caffeine'; // bardak
  static const alcohol = 'alcohol'; // birim
  static const exercise = 'exercise'; // dakika
  static const mealPattern = 'meal_pattern';
  static const smoking = 'smoking';
  // Vücut ölçüleri (zaman serisi)
  static const weight = 'weight'; // kg
  static const height = 'height'; // cm
}
