/// Tekrarlayan ilaçlarda saklanan gün adları (küçük harf, İngilizce anahtar).
/// Ekranda çeviriyle gösterilir; kullanıcı elle yazmaz, listeden seçer.
const weekdayKeys = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

/// Gün adının hafta içi sırası: pazartesi 0 … pazar 6 (DateTime.weekday − 1).
const weekdayIndex = {
  'monday': 0,
  'tuesday': 1,
  'wednesday': 2,
  'thursday': 3,
  'friday': 4,
  'saturday': 5,
  'sunday': 6,
};
