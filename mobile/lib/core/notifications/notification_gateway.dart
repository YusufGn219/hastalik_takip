/// Haftalık tekrar eden bir doz hatırlatması: [weekday] (DateTime.monday..sunday)
/// günü [hour]:[minute] saatinde, her hafta. Cihazın yerel saat dilimiyle kurulur.
class DoseReminder {
  const DoseReminder({
    required this.id,
    required this.title,
    required this.body,
    required this.weekday,
    required this.hour,
    required this.minute,
    required this.exact,
    required this.channelName,
    required this.channelDescription,
  });

  /// Android bildirim kimliği (bkz. `ReminderService.idFor`).
  final int id;
  final String title;
  final String body;
  final int weekday;
  final int hour;
  final int minute;

  /// true: tam saatte (tam alarm izni varsa); false: yaklaşık saatte (Android'in
  /// uygun gördüğü birkaç dakika içinde).
  final bool exact;
  final String channelName;
  final String channelDescription;
}

/// Telefonun bildirim sistemi. Hatırlatma mantığı bunun üstünde çalışır; testlerde
/// sahtesi kullanılır.
abstract class NotificationGateway {
  Future<void> schedule(DoseReminder reminder);
  Future<void> cancel(int id);
  Future<void> cancelAll();

  /// Tam alarm izni var mı (Android 12+'da kullanıcı sistem ayarından verir).
  Future<bool> canScheduleExact();

  /// Uygulamanın bildirim göstermesine izin var mı (Android 13+'da kullanıcı izni).
  Future<bool> areNotificationsEnabled();

  /// Bildirim iznini sistem penceresiyle ister; verildiyse true.
  Future<bool> requestNotificationPermission();

  /// Tam alarm izni için sistem ayar ekranını açar (sonuç ekrandan dönünce
  /// `canScheduleExact` ile okunur).
  Future<void> requestExactAlarmPermission();
}
