// Doz bazlı ilaç uyumu: rutinli her ilaç için planlı dozlar üç gruba ayrılır:
// alındı, atlandı, kaydedilmedi. Gün bazlı eski hesap (`AnalyticsService.
// medicationAdherence`) günde tek alımı "uyumlu gün" sayar; günde iki dozu olan
// ilaçta sabahı atlayıp akşamı almak %100 çıkar. Burada her doz ayrı sayılır.
//
// Kurallar:
//  * Yalnız şu an rutinli olan ilaçlar. Rutin sonradan değişirse geçmiş günler
//    bugünkü rutine göre değerlendirilir (rutinin geçmiş sürümleri tutulmuyor).
//  * Sayım, ilacın pencere içindeki **ilk kayıtlı dozundan** (alım ya da atlama)
//    başlar; öncesi sayılmaz. Rutin yeni kurulduysa ya da hiç kayıt yoksa geçmiş
//    günler "kaydedilmedi" diye cezalandırılmaz. Hiç kayıt yoksa oran boştur.
//  * Saati henüz gelmemiş bugünkü doz sayılmaz (doz saati şimdiye eşit ya da
//    geçmişse sayılır).
//  * Oran = alınan ÷ planlı × 100; atlanan ve kaydedilmeyen paydada kalır.
//  * Plansız alımlar (rutin dozuna bağlı olmayanlar) "ekstra" diye ayrıca sayılır,
//    orana girmez.

import '../../core/utils/turkish_text.dart';
import '../../data/repositories/medication_log_repository.dart';
import '../../data/repositories/support.dart';
import '../local_day.dart';
import 'dose_service.dart';

class DoseAdherenceItem {
  const DoseAdherenceItem({
    required this.medicationId,
    required this.medicationName,
    required this.taken,
    required this.skipped,
    required this.unrecorded,
    required this.extraIntakes,
  });

  final String medicationId;
  final String medicationName;

  /// Alınan, atlanan ve kaydedilmeyen planlı doz sayıları.
  final int taken;
  final int skipped;
  final int unrecorded;

  /// Pencere içindeki plansız alım sayısı.
  final int extraIntakes;

  /// Sayılan planlı doz (saati gelmiş ve ilk kayıttan sonrakiler).
  int get planned => taken + skipped + unrecorded;

  /// Hiç sayılacak doz yoksa (kayıt yok) false: yüzde gösterilmez.
  bool get hasData => planned > 0;

  /// 0–100, tek ondalık; veri yoksa null.
  double? get rate =>
      hasData ? ((taken / planned * 1000).round() / 10) : null;
}

class DoseAdherence {
  const DoseAdherence(this.periodDays, this.items);

  /// Bugün dahil son kaç gün.
  final int periodDays;

  /// İlaç adına göre Türkçe sıralı.
  final List<DoseAdherenceItem> items;
}

class DoseAdherenceService {
  DoseAdherenceService({
    required DoseService doses,
    required MedicationLogRepository logs,
    Clock? clock,
  })  : _doses = doses,
        _logs = logs,
        _clock = clock ?? DateTime.now;

  final DoseService _doses;
  final MedicationLogRepository _logs;
  final Clock _clock;

  /// Bugün dahil son [days] gün için ilaç başına doz uyumu.
  Future<DoseAdherence> doseAdherence(int days) async {
    final now = _clock();
    final today = dayKey(now);
    final nowHm = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
    final start = addDays(today, -(days - 1));

    // İlaç -> (zaman anahtarı "YYYY-MM-DD HH:mm", durum) listesi.
    final slots = <String, List<(String, DoseState)>>{};
    final names = <String, String>{};
    final firstRecorded = <String, String>{};

    for (var day = start; day.compareTo(today) <= 0; day = addDays(day, 1)) {
      for (final dose in await _doses.dosesForDay(day)) {
        // Bugünün saati henüz gelmemiş dozu sayılmaz.
        if (day == today &&
            dose.state == DoseState.pending &&
            dose.time.compareTo(nowHm) > 0) {
          continue;
        }
        final id = dose.medication.id;
        final key = '$day ${dose.time}';
        names[id] = dose.medication.name;
        slots.putIfAbsent(id, () => []).add((key, dose.state));
        if (dose.state != DoseState.pending) {
          final first = firstRecorded[id];
          if (first == null || key.compareTo(first) < 0) firstRecorded[id] = key;
        }
      }
    }

    // Plansız alımlar: rutin dozuna bağlı olmayan, pencere içindeki kayıtlar.
    final extras = <String, int>{};
    final since = parseDay(start).subtract(const Duration(hours: 14));
    for (final l in await _logs.listSince(since)) {
      if (l.scheduledDay != null || !slots.containsKey(l.medicationId)) continue;
      final day = localDayOf(l.takenAt, l.utcOffsetMinutes);
      if (day.compareTo(start) < 0 || day.compareTo(today) > 0) continue;
      extras[l.medicationId] = (extras[l.medicationId] ?? 0) + 1;
    }

    final items = <DoseAdherenceItem>[];
    for (final entry in slots.entries) {
      final first = firstRecorded[entry.key];
      var taken = 0, skipped = 0, unrecorded = 0;
      if (first != null) {
        for (final (key, state) in entry.value) {
          if (key.compareTo(first) < 0) continue;
          switch (state) {
            case DoseState.taken:
              taken++;
            case DoseState.skipped:
              skipped++;
            case DoseState.pending:
              unrecorded++;
          }
        }
      }
      items.add(DoseAdherenceItem(
        medicationId: entry.key,
        medicationName: names[entry.key]!,
        taken: taken,
        skipped: skipped,
        unrecorded: unrecorded,
        extraIntakes: extras[entry.key] ?? 0,
      ));
    }
    items.sort((a, b) => compareTr(a.medicationName, b.medicationName));
    return DoseAdherence(days, items);
  }
}
