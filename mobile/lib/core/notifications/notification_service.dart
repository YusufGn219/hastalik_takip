// Gerçek bildirim uygulaması (flutter_local_notifications). İzin İSTEMEZ: izinler
// kullanıcı ilk rutini kaydederken sorulur (Sprint 4 Grup 3). Saat dilimi sabit
// değildir, cihazın gerçek saat dilimi kullanılır.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'next_instance.dart';
import 'notification_gateway.dart';

class NotificationService implements NotificationGateway {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Eklentiyi ve saat dilimini hazırlar; ikinci çağrı bir şey yapmaz. Hiçbir
  /// izin istemez.
  Future<void> initialize() async {
    if (_ready) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(await _deviceLocation());
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  /// Telefonun saat dilimi. Adı tanınmazsa, şimdiki UTC farkı aynı olan bir bölge
  /// seçilir; o da bulunamazsa UTC (uygulama her açılışta yeniden kurar).
  Future<tz.Location> _deviceLocation() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      return tz.getLocation(info.identifier);
    } catch (_) {
      final offset = DateTime.now().timeZoneOffset;
      for (final loc in tz.timeZoneDatabase.locations.values) {
        if (tz.TZDateTime.now(loc).timeZoneOffset == offset) return loc;
      }
      return tz.UTC;
    }
  }

  @override
  Future<void> schedule(DoseReminder r) async {
    await initialize();
    final when = nextWeeklyInstance(
      tz.TZDateTime.now(tz.local),
      r.weekday,
      r.hour,
      r.minute,
    );
    await _plugin.zonedSchedule(
      r.id,
      r.title,
      r.body,
      when,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'dose_reminders',
          r.channelName,
          channelDescription: r.channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          // Kilit ekranında içerik gizli (metin zaten sağlık verisi içermez).
          visibility: NotificationVisibility.private,
        ),
      ),
      androidScheduleMode: r.exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  @override
  Future<void> cancel(int id) async {
    await initialize();
    await _plugin.cancel(id);
  }

  @override
  Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAll();
  }

  @override
  Future<bool> canScheduleExact() async {
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.canScheduleExactNotifications() ?? false;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<bool> areNotificationsEnabled() async {
    await initialize();
    return await _android?.areNotificationsEnabled() ?? false;
  }

  @override
  Future<bool> requestNotificationPermission() async {
    await initialize();
    return await _android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> requestExactAlarmPermission() async {
    await initialize();
    await _android?.requestExactAlarmsPermission();
  }
}
