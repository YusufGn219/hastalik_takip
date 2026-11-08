// Analiz grafiklerinin hareketli ortalaması: takvim penceresi, eksik gün, ay sınırı.

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/analytics/smoothing.dart';

List<String> _days(String from, int count) {
  final p = from.split('-').map(int.parse).toList();
  return [
    for (var i = 0; i < count; i++)
      () {
        final d = DateTime(p[0], p[1], p[2] + i);
        return '${d.year.toString().padLeft(4, '0')}-'
            '${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}';
      }(),
  ];
}

void main() {
  test('her nokta kendi günü dahil son 7 takvim gününün ortalamasıdır', () {
    final dates = _days('2026-11-01', 10);
    final values = [for (var i = 1; i <= 10; i++) i.toDouble()];
    final avg = trailingAverage(dates, values);

    expect(avg[0], 1); // yalnız kendisi
    expect(avg[2], 2); // 1,2,3
    expect(avg[6], 4); // 1..7
    expect(avg[9], 7); // 4..10: ilk üç gün pencereden çıktı
  });

  test('kayıt girilmeyen gün 0 sayılmaz: yalnız elde olan değerler ortalanır', () {
    // 1 Kasım ve 4 Kasım: ikisi de aynı 7 günlük pencerede.
    expect(trailingAverage(['2026-11-01', '2026-11-04'], [4, 2]), [4, 3]);
    // 1 ve 9 Kasım: ilki pencerenin dışında kalır.
    expect(trailingAverage(['2026-11-01', '2026-11-09'], [4, 2]), [4, 2]);
    // Tam sınır: 7 günlük pencere 9 Kasım için 3-9 Kasım'dır; 3 Kasım içeride.
    expect(trailingAverage(['2026-11-03', '2026-11-09'], [4, 2]), [4, 3]);
    expect(trailingAverage(['2026-11-02', '2026-11-09'], [4, 2]), [4, 2]);
  });

  test('ay ve yıl sınırı takvime göre işler', () {
    expect(trailingAverage(['2026-10-30', '2026-11-02'], [5, 3]), [5, 4]);
    expect(trailingAverage(['2026-12-29', '2027-01-03'], [6, 2]), [6, 4]);
    // Şubat 2028 artık yıl: 27 Şubat ile 4 Mart arası 7 gün içinde.
    expect(trailingAverage(['2028-02-27', '2028-03-04'], [8, 4]), [8, 6]);
  });

  test('pencere boyutu değiştirilebilir', () {
    final dates = _days('2026-11-01', 5);
    final avg = trailingAverage(dates, [1, 2, 3, 4, 5], window: 2);
    expect(avg, [1, 1.5, 2.5, 3.5, 4.5]);
  });

  test('boş liste boş döner, tek nokta aynen kalır', () {
    expect(trailingAverage([], []), isEmpty);
    expect(trailingAverage(['2026-11-01'], [3.5]), [3.5]);
  });
}
