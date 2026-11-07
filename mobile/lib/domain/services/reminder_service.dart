// Rutin dozların hatırlatmaları: her dozun kendi saatinde, haftanın seçili
// günlerinde bildirim. Sabit bir saat yoktur; saatler kullanıcının rutininden gelir.
//
// Bildirim kimliği (Android tamsayı ister; aynı kimlik öncekini ezer):
//   kimlik = ilacın notificationId'si * 100 + doz sırası * 10 + gün
// Doz sırası saat listesindeki yer (0..9), gün hafta sırası (pazartesi 0 ..
// pazar 6). Bir ilaç bir yüzlük bloğu kullanır, ilaçlar birbirine karışmaz.
// Rutin değişince ilacın 70 olası kimliğinin hepsi iptal edilip baştan kurulur
// (saat silinince sıra numaraları kaydığı için tek tek iptal güvenilmez).
//
// Metinler sağlık verisi içermez (ilaç adı yok): kilit ekranında başkaları görebilir.

import '../../core/notifications/notification_gateway.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/medication_repository.dart';
import '../../l10n/app_localizations.dart';
import '../weekdays.dart';

/// Bildirimde gösterilen metinler (çeviri anahtarlarından).
class ReminderTexts {
  const ReminderTexts({
    required this.title,
    required this.body,
    required this.channelName,
    required this.channelDescription,
  });

  factory ReminderTexts.fromL10n(AppLocalizations l10n) => ReminderTexts(
        title: l10n.reminderTitle,
        body: l10n.reminderBody,
        channelName: l10n.reminderChannelName,
        channelDescription: l10n.reminderChannelDescription,
      );

  final String title;
  final String body;
  final String channelName;
  final String channelDescription;
}

class ReminderService {
  ReminderService({
    required MedicationRepository medications,
    required NotificationGateway gateway,
    required ReminderTexts texts,
  })  : _medications = medications,
        _gateway = gateway,
        _texts = texts;

  final MedicationRepository _medications;
  final NotificationGateway _gateway;
  final ReminderTexts _texts;

  /// Bir ilacın günde en çok doz sayısı (kimlik düzeninden gelir).
  static const maxDoses = 10;

  static final _timePattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  /// Bildirim kimliği. [doseIndex] 0..9, [dayIndex] 0..6.
  static int idFor(int notificationId, int doseIndex, int dayIndex) =>
      notificationId * 100 + doseIndex * 10 + dayIndex;

  /// Bir ilacın olası tüm kimlikleri (10 doz x 7 gün).
  static List<int> allIdsOf(int notificationId) => [
        for (var d = 0; d < maxDoses; d++)
          for (var day = 0; day < 7; day++) idFor(notificationId, d, day),
      ];

  /// Hepsini silip tüm rutinleri baştan kurar: açılışta (saat dilimi
  /// değişmiş olabilir, kayıtlar güncel olsun) ve gerektiğinde çağrılır.
  Future<void> rescheduleAll() async {
    await _gateway.cancelAll();
    final exact = await _gateway.canScheduleExact();
    for (final listed in await _medications.listAvailable()) {
      if (!listed.isRecurring) continue;
      final m = await _medications.ensureNotificationId(listed.id);
      if (m == null || m.notificationId == null) continue;
      await _scheduleOf(m, exact: exact);
    }
  }

  /// İlacın bildirimlerini rutinine göre yeniden kurar: önce 70 olası kimliğin
  /// hepsi iptal edilir; ilaç rutinliyse yeniden kurulur, değilse (rutin kapatıldı,
  /// ilaç silindi) yalnız iptal kalır.
  Future<void> rescheduleFor(String medicationId) async {
    // Katalog ilaçlarının numarası yoktur; ilk rutinde atanır.
    final m = await _medications.ensureNotificationId(medicationId);
    final nid = m?.notificationId;
    if (m == null || nid == null) return;
    await _cancelAllOf(nid);
    if (m.deletedAt != null || !m.isRecurring) return;
    await _scheduleOf(m, exact: await _gateway.canScheduleExact());
  }

  /// İlacın tüm bildirimlerini iptal eder.
  Future<void> cancelFor(String medicationId) async {
    final m = await _medications.getById(medicationId);
    final nid = m?.notificationId;
    if (nid == null) return;
    await _cancelAllOf(nid);
  }

  Future<void> _cancelAllOf(int notificationId) async {
    for (final id in allIdsOf(notificationId)) {
      await _gateway.cancel(id);
    }
  }

  Future<void> _scheduleOf(Medication m, {required bool exact}) async {
    final nid = m.notificationId!;
    final times = [
      for (final t in recurringTimesOf(m))
        if (_timePattern.hasMatch(t)) t,
    ].take(maxDoses).toList();
    final saved = recurringDaysOf(m);
    final dayNames = saved == null || saved.isEmpty ? weekdayKeys : saved;
    for (var i = 0; i < times.length; i++) {
      final hour = int.parse(times[i].substring(0, 2));
      final minute = int.parse(times[i].substring(3, 5));
      for (final name in dayNames) {
        final dayIndex = weekdayIndex[name];
        if (dayIndex == null) continue;
        await _gateway.schedule(DoseReminder(
          id: idFor(nid, i, dayIndex),
          title: _texts.title,
          body: _texts.body,
          weekday: dayIndex + 1,
          hour: hour,
          minute: minute,
          exact: exact,
          channelName: _texts.channelName,
          channelDescription: _texts.channelDescription,
        ));
      }
    }
  }
}
