// Yerel gün yardımcıları.
//
// Olay zamanları UTC saklanır, yanında o andaki cihaz UTC farkı (dakika) vardır.
// "Bu kayıt hangi güne ait" sorusu, kaydın kendi farkıyla yanıtlanır; böylece
// kullanıcı saat dilimi değiştirse de eski kayıtların günü kaymaz.

/// 'YYYY-MM-DD'.
String formatDay(int y, int m, int d) =>
    '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-'
    '${d.toString().padLeft(2, '0')}';

/// [instant] anının, [offsetMinutes] farklı yerel takvim günü.
String localDayOf(DateTime instant, int offsetMinutes) {
  final shifted = instant.toUtc().add(Duration(minutes: offsetMinutes));
  return formatDay(shifted.year, shifted.month, shifted.day);
}

/// Bir anın UTC takvim günü (eski Python'daki `.date()` davranışı için).
String utcDayOf(DateTime instant) {
  final u = instant.toUtc();
  return formatDay(u.year, u.month, u.day);
}

/// 'YYYY-MM-DD' metnini UTC gece yarısı `DateTime`'a çevirir.
DateTime parseDay(String day) {
  final p = day.split('-');
  return DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// Yerel [day] gününe düşebilecek tüm anları kapsayan geniş UTC aralığı.
/// Dünyadaki UTC farkları -12:00 ile +14:00 arasındadır; kesin süzme çağıran
/// tarafta kaydın kendi farkıyla yapılır.
({DateTime from, DateTime to}) utcWindowForLocalDay(String day) {
  final start = parseDay(day);
  return (
    from: start.subtract(const Duration(hours: 14)),
    to: start.add(const Duration(hours: 24 + 12)),
  );
}
