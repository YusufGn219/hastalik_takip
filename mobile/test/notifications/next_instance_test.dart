import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/notifications/next_instance.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tz_data.initializeTimeZones);

  tz.Location istanbul() => tz.getLocation('Europe/Istanbul');
  // 2026-11-06 Cuma 10:30.
  tz.TZDateTime now() => tz.TZDateTime(istanbul(), 2026, 11, 6, 10, 30);

  String fmt(tz.TZDateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  test('bugünün gelecek saati bugün seçilir', () {
    expect(fmt(nextWeeklyInstance(now(), DateTime.friday, 20, 0)),
        '2026-11-06 20:00');
  });

  test('bugünün geçmiş saati gelecek haftaya kalır', () {
    expect(fmt(nextWeeklyInstance(now(), DateTime.friday, 8, 0)),
        '2026-11-13 08:00');
  });

  test('tam şimdiki an planlanmaz, bir hafta sonrası seçilir', () {
    expect(fmt(nextWeeklyInstance(now(), DateTime.friday, 10, 30)),
        '2026-11-13 10:30');
  });

  test('sonraki günler: cumartesi, pazartesi', () {
    expect(fmt(nextWeeklyInstance(now(), DateTime.saturday, 8, 0)),
        '2026-11-07 08:00');
    expect(fmt(nextWeeklyInstance(now(), DateTime.monday, 9, 15)),
        '2026-11-09 09:15');
  });

  test('sonuç her zaman şimdiden sonradır ve istenen günde', () {
    for (var wd = 1; wd <= 7; wd++) {
      for (final h in [0, 10, 23]) {
        final t = nextWeeklyInstance(now(), wd, h, 0);
        expect(t.isAfter(now()), isTrue, reason: 'gün $wd saat $h');
        expect(t.weekday, wd);
        expect(t.hour, h);
        expect(t.difference(now()).inDays, lessThanOrEqualTo(7));
      }
    }
  });

  test('yaz saati geçişinde doz saati kaymaz (ABD, 8 Mart 2026)', () {
    final ny = tz.getLocation('America/New_York');
    // Cumartesi öğlen; pazar 08:00 doz. Geceleyin saat bir saat ileri alınır.
    final saturdayNoon = tz.TZDateTime(ny, 2026, 3, 7, 12, 0);
    final t = nextWeeklyInstance(saturdayNoon, DateTime.sunday, 8, 0);
    expect(fmt(t), '2026-03-08 08:00');
    expect(t.hour, 8); // 24 saat eklenseydi 09:00 olurdu
  });
}
