// İlaç kuralları: eski `services/health/medication.py` portu.

import '../../data/database/app_database.dart';
import '../../data/database/enums.dart';
import '../../data/repositories/medication_log_repository.dart';
import '../../data/repositories/medication_repository.dart';
import '../errors.dart';
import '../local_day.dart';

class MedicationService {
  MedicationService({
    required MedicationRepository medications,
    required MedicationLogRepository logs,
  })  : _medications = medications,
        _logs = logs;

  final MedicationRepository _medications;
  final MedicationLogRepository _logs;

  /// Kullanılabilir ilaçlar (katalog + kullanıcının kendi ilaçları).
  Future<List<Medication>> available() => _medications.listAvailable();

  Future<Medication> create({
    required String name,
    MedicationType type = MedicationType.symptomatic,
    bool isRecurring = false,
    String? recurringTime,
    List<String>? recurringDays,
  }) {
    return _medications.create(
      name: name,
      type: type,
      isRecurring: isRecurring,
      recurringTime: recurringTime,
      recurringDays: recurringDays,
    );
  }

  /// İlaç alımı kaydeder. Atak ve kronik hastalık aynı anda dolu olamaz.
  Future<MedicationLog> logIntake({
    required String medicationId,
    required DateTime takenAt,
    double? doseAmount,
    DoseUnit doseUnit = DoseUnit.tablet,
    String? episodeId,
    String? conditionId,
    String notes = '',
  }) async {
    if (episodeId != null && conditionId != null) {
      throw const RuleViolation(
        RuleCodes.episodeAndConditionBoth,
        'Atak ve kronik hastalık aynı anda doldurulamaz.',
      );
    }
    return _logs.create(
      medicationId: medicationId,
      takenAt: takenAt,
      doseAmount: doseAmount,
      doseUnit: doseUnit,
      episodeId: episodeId,
      conditionId: conditionId,
      notes: notes,
    );
  }

  /// Yerel [day] gününde alınan ilaçlar, eskiden yeniye.
  Future<List<MedicationLog>> logsForDay(String day) async {
    final w = utcWindowForLocalDay(day);
    final candidates = await _logs.listInRange(w.from, w.to);
    final result = candidates
        .where((l) => localDayOf(l.takenAt, l.utcOffsetMinutes) == day)
        .toList()
      ..sort((a, b) => a.takenAt.compareTo(b.takenAt));
    return result;
  }
}
