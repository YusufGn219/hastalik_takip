// Analiz grafiklerinde çok noktalı dönemleri okunur kılan hareketli ortalama.

import '../../domain/local_day.dart';

/// Bundan fazla nokta varsa grafikler ham değer yerine hareketli ortalama çizer
/// (7 gün: ham; 30 ve 90 gün: ortalama).
const smoothingThreshold = 14;

/// Her nokta için o günü ve ondan önceki `window - 1` **takvim gününü** kapsayan
/// değerlerin ortalaması. [dates] 'YYYY-MM-DD' ve artan sırada, [values] aynı
/// uzunlukta olmalı. Kaydı olmayan günler pencerede yer almaz: 0 sayılmaz, yalnız
/// elde olan değerler ortalanır; böylece az kayıt girilen günler ortalamayı
/// aşağı çekmez.
List<double> trailingAverage(
  List<String> dates,
  List<double> values, {
  int window = 7,
}) {
  assert(dates.length == values.length);
  assert(window >= 1);
  final result = <double>[];
  for (var i = 0; i < dates.length; i++) {
    final from = addDays(dates[i], -(window - 1));
    var sum = 0.0;
    var count = 0;
    for (var j = i; j >= 0; j--) {
      if (dates[j].compareTo(from) < 0) break;
      sum += values[j];
      count++;
    }
    result.add(sum / count);
  }
  return result;
}
