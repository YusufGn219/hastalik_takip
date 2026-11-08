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

/// Profildeki cinsiyet değerleri (`profiles.gender`, serbest metin sütunu).
/// Boş (null) = "belirtmek istemiyorum".
abstract final class Genders {
  static const female = 'female';
  static const male = 'male';
  static const other = 'other';
  static const all = {female, male, other};
}

/// Profildeki kan grubu değerleri (`profiles.blood_type`). Boş (null) = belirtilmedi.
abstract final class BloodTypes {
  static const all = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', '0+', '0-'];
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
  static const pain = 'pain'; // 0-10
  static const steps = 'steps'; // adım
  // Vücut ölçüleri (zaman serisi)
  static const weight = 'weight'; // kg
  static const height = 'height'; // cm

  /// Kullanıcının kendi günlük alanlarının ölçüm türü öneki
  /// (`field:` ve alanın kimliği art arda).
  static const customFieldPrefix = 'field:';
}

/// Ek günlük alanının türü (`daily_fields.kind`).
abstract final class DailyFieldKinds {
  /// Serbest sayı (alanın kendi en az/en çok sınırı ve birimi vardır).
  static const number = 'number';

  /// 1-5 ölçeği (tam sayı).
  static const scale = 'scale';

  /// Evet/hayır; değer 1 ya da 0 saklanır.
  static const yesNo = 'yesno';

  static const all = [number, scale, yesNo];
}
