import 'package:uuid/uuid.dart';

/// Şimdiki zamanı verir; testlerde sabitlenebilir.
typedef Clock = DateTime Function();

/// Yeni kayıt kimliği üretir (UUID v4); testlerde öngörülebilir yapılabilir.
typedef IdGenerator = String Function();

const _uuid = Uuid();

String newUuid() => _uuid.v4();

/// Bir anın cihazdaki UTC farkı (dakika). Yerel `DateTime` ile verilmelidir;
/// UTC `DateTime` verilirse 0 çıkar.
int utcOffsetOf(DateTime t) => t.timeZoneOffset.inMinutes;

/// Yerel takvim günü anahtarı: 'YYYY-MM-DD'.
String dayKey(DateTime t) {
  final y = t.year.toString().padLeft(4, '0');
  final m = t.month.toString().padLeft(2, '0');
  final d = t.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
