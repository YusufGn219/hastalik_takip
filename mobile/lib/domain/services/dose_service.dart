// Rutin dozların takibi: her planlı doz (ilaç, gün, saat) üç durumdan birindedir:
// alındı, atlandı ya da henüz kaydedilmedi. "Atlandı" ile "kaydedilmedi"
// ayrımı, ileride uyum analizi ve makine öğrenmesi için veri bütünlüğüdür.
//
// Kurallar:
//  * Bir doz için tek sonuç vardır (hem alındı hem atlandı olamaz); veritabanı
//    dizinleri bunu ayrıca korur.
//  * "Aldım" atlanmış bir dozdan sonra serbesttir: atlama kaydı silinmiş işareti
//    alır, alım yazılır (ikisi tek işlemde). Alınmış doz "atlandı" yapılamaz.
//  * Yalnız ilacın rutininde o gün ve o saatte planlı olan doz kaydedilir;
//    gelecek güne kayıt yazılmaz.

import '../../data/database/app_database.dart';
import '../../data/repositories/dose_skip_repository.dart';
import '../../data/repositories/medication_log_repository.dart';
import '../../data/repositories/medication_repository.dart';
import '../../data/repositories/support.dart';
import '../../core/utils/turkish_text.dart';
import '../errors.dart';
import '../local_day.dart';
import '../weekdays.dart';
import 'episode_service.dart' show Transactor, runDirect;

enum DoseState { pending, taken, skipped }

/// Bir günün planlı dozu ve durumu. [log] yalnız alınmış dozda dolu.
class Dose {
  const Dose(this.medication, this.time, this.state, {this.log});

  final Medication medication;

  /// Doz saati 'HH:mm'.
  final String time;
  final DoseState state;
  final MedicationLog? log;
}

class DoseService {
  DoseService({
    required MedicationRepository medications,
    required MedicationLogRepository logs,
    required DoseSkipRepository skips,
    Transactor? transactor,
    Clock? clock,
  })  : _medications = medications,
        _logs = logs,
        _skips = skips,
        _tx = transactor ?? runDirect,
        _clock = clock ?? DateTime.now;

  final MedicationRepository _medications;
  final MedicationLogRepository _logs;
  final DoseSkipRepository _skips;
  final Transactor _tx;
  final Clock _clock;

  /// Şimdiki yerel gün, 'YYYY-MM-DD'.
  String today() => dayKey(_clock());

  /// Yerel [day] gününün planlı dozları, saate sonra Türkçe ada göre sıralı.
  /// Her doz için durum: alındı (o doz için alım kaydı var), atlandı (atlama
  /// kaydı var), aksi halde kaydedilmedi.
  Future<List<Dose>> dosesForDay(String day) async {
    final weekday = weekdayKeys[parseDay(day).weekday - 1];
    final logs = await _logs.listScheduledForDay(day);
    final skips = await _skips.listForDay(day);
    final doses = <Dose>[];
    for (final m in await _medications.listAvailable()) {
      if (!_isScheduledOn(m, weekday)) continue;
      for (final t in recurringTimesOf(m)) {
        final log = logs
            .where((l) => l.medicationId == m.id && l.scheduledTime == t)
            .firstOrNull;
        final skipped = skips
            .any((s) => s.medicationId == m.id && s.scheduledTime == t);
        doses.add(Dose(
          m,
          t,
          log != null
              ? DoseState.taken
              : skipped
                  ? DoseState.skipped
                  : DoseState.pending,
          log: log,
        ));
      }
    }
    doses.sort((a, b) {
      final byTime = a.time.compareTo(b.time);
      return byTime != 0
          ? byTime
          : compareTr(a.medication.name, b.medication.name);
    });
    return doses;
  }

  /// Planlı dozu "aldım" olarak kaydeder (şimdi, cihazın UTC farkıyla). [day]
  /// verilmezse bugün. Doz atlanmış olarak işaretliyse atlama silinmiş işareti
  /// alır. Zaten alınmışsa [RuleCodes.doseAlreadyTaken]; doz planlı değilse
  /// [RuleCodes.doseNotScheduled]; ilaç yoksa [RuleCodes.medicationNotFound].
  Future<MedicationLog> markTaken({
    required String medicationId,
    required String time,
    String? day,
  }) {
    final d = day ?? today();
    return _tx(() async {
      await _requireScheduled(medicationId, time, d);
      final taken = await _logs.listScheduledForDay(d);
      if (taken.any((l) => l.medicationId == medicationId && l.scheduledTime == time)) {
        throw const RuleViolation(
          RuleCodes.doseAlreadyTaken,
          'Bu doz zaten alındı olarak kaydedilmiş.',
        );
      }
      for (final s in await _skips.listForDay(d)) {
        if (s.medicationId == medicationId && s.scheduledTime == time) {
          await _skips.softDelete(s.id);
        }
      }
      return _logs.create(
        medicationId: medicationId,
        takenAt: _clock(),
        scheduledTime: time,
        scheduledDay: d,
      );
    });
  }

  /// Planlı dozu "atladım" olarak kaydeder. Alınmış doz atlanamaz
  /// ([RuleCodes.doseAlreadyTaken]); zaten atlanmışsa
  /// [RuleCodes.doseAlreadySkipped]; doz planlı değilse
  /// [RuleCodes.doseNotScheduled].
  Future<DoseSkip> markSkipped({
    required String medicationId,
    required String time,
    String? day,
  }) {
    final d = day ?? today();
    return _tx(() async {
      await _requireScheduled(medicationId, time, d);
      final taken = await _logs.listScheduledForDay(d);
      if (taken.any((l) => l.medicationId == medicationId && l.scheduledTime == time)) {
        throw const RuleViolation(
          RuleCodes.doseAlreadyTaken,
          'Alınmış doz atlandı olarak işaretlenemez.',
        );
      }
      final skips = await _skips.listForDay(d);
      if (skips.any((s) => s.medicationId == medicationId && s.scheduledTime == time)) {
        throw const RuleViolation(
          RuleCodes.doseAlreadySkipped,
          'Bu doz zaten atlandı olarak kaydedilmiş.',
        );
      }
      return _skips.create(
        medicationId: medicationId,
        scheduledDay: d,
        scheduledTime: time,
        skippedAt: _clock(),
      );
    });
  }

  bool _isScheduledOn(Medication m, String weekday) {
    if (!m.isRecurring) return false;
    final saved = recurringDaysOf(m);
    final days = saved == null || saved.isEmpty ? weekdayKeys : saved;
    return days.contains(weekday);
  }

  /// İlaç var, rutini o gün ve o saatte planlı ve gün gelecekte değil.
  Future<void> _requireScheduled(
    String medicationId,
    String time,
    String day,
  ) async {
    final m = await _medications.getById(medicationId);
    if (m == null || m.deletedAt != null) {
      throw const RuleViolation(
        RuleCodes.medicationNotFound,
        'İlaç bulunamadı.',
      );
    }
    final weekday = weekdayKeys[parseDay(day).weekday - 1];
    if (day.compareTo(today()) > 0 ||
        !_isScheduledOn(m, weekday) ||
        !recurringTimesOf(m).contains(time)) {
      throw RuleViolation(
        RuleCodes.doseNotScheduled,
        '$day günü saat $time için planlı bir doz yok.',
      );
    }
  }
}
