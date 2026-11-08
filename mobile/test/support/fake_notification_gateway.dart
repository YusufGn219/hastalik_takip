import 'package:mobile/core/notifications/notification_gateway.dart';

/// Android'in kimlik davranışını taklit eden sahte bildirim sistemi: aynı kimlikle
/// ikinci bildirim öncekini EZER, iptal kimliği siler. Böylece kimlik çakışmaları
/// testlerde yakalanır.
class FakeNotificationGateway implements NotificationGateway {
  /// Şu an planlı bildirimler (kimlik → hatırlatma).
  final Map<int, DoseReminder> active = {};

  /// Yapılan tüm `schedule` çağrıları (ezilenler dahil).
  final List<DoseReminder> scheduleCalls = [];
  final List<int> cancelCalls = [];
  int cancelAllCalls = 0;

  /// Tam alarm izni var mı.
  bool exact = true;

  /// Doluysa `schedule` / `cancel` bu hatayı atar.
  Object? failSchedule;
  Object? failCancel;

  @override
  Future<void> schedule(DoseReminder reminder) async {
    if (failSchedule != null) throw failSchedule!;
    scheduleCalls.add(reminder);
    active[reminder.id] = reminder;
  }

  @override
  Future<void> cancel(int id) async {
    if (failCancel != null) throw failCancel!;
    cancelCalls.add(id);
    active.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
    active.clear();
  }

  @override
  Future<bool> canScheduleExact() async => exact;

  /// Bildirim izni durumu ve sistem penceresinde verilecek cevap.
  bool notificationsEnabled = true;
  bool grantOnRequest = true;
  int notificationRequests = 0;
  int exactRequests = 0;
  int settingsOpens = 0;

  @override
  Future<bool> areNotificationsEnabled() async => notificationsEnabled;

  @override
  Future<bool> requestNotificationPermission() async {
    notificationRequests++;
    if (grantOnRequest) notificationsEnabled = true;
    return notificationsEnabled;
  }

  @override
  Future<void> requestExactAlarmPermission() async {
    exactRequests++;
  }

  @override
  Future<void> openNotificationSettings() async {
    settingsOpens++;
  }
}
