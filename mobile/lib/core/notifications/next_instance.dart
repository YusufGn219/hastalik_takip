import 'package:timezone/timezone.dart' as tz;

/// [now]'dan sonraki, [weekday] (DateTime.monday..sunday) gününün [hour]:[minute]
/// saatine denk gelen ilk an. Tam şimdiye denk gelirse bir hafta sonrası
/// seçilir (geçmiş ya da şimdiki an planlanamaz).
///
/// Gün gün ilerlerken saat, takvim günü olarak kurulur (24 saat eklenmez); böylece
/// yaz saati geçişinde doz saati kaymaz.
tz.TZDateTime nextWeeklyInstance(
  tz.TZDateTime now,
  int weekday,
  int hour,
  int minute,
) {
  var day = 0;
  while (true) {
    final candidate = tz.TZDateTime(
      now.location,
      now.year,
      now.month,
      now.day + day,
      hour,
      minute,
    );
    if (candidate.weekday == weekday && candidate.isAfter(now)) return candidate;
    day++;
  }
}
