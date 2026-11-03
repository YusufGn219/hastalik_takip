// Zaman çizelgesi sorgusu: eski `services/health/timeline.py` portu.

import '../../data/database/app_database.dart';
import '../../data/repositories/daily_log_repository.dart';
import '../../data/repositories/symptom_entry_repository.dart';
import '../local_day.dart';
import 'medication_service.dart';

class Timeline {
  const Timeline({
    required this.dailyLog,
    required this.symptomEntries,
    required this.medicationLogs,
  });

  final DailyLog? dailyLog;
  final List<SymptomEntry> symptomEntries;
  final List<MedicationLog> medicationLogs;
}

class TimelineService {
  TimelineService({
    required DailyLogRepository dailyLogs,
    required SymptomEntryRepository entries,
    required MedicationService medications,
  })  : _dailyLogs = dailyLogs,
        _entries = entries,
        _medications = medications;

  final DailyLogRepository _dailyLogs;
  final SymptomEntryRepository _entries;
  final MedicationService _medications;

  /// Yerel [day] ('YYYY-MM-DD') gününün günlük kaydı, semptom girişleri ve
  /// ilaç alımları (girişler ve alımlar eskiden yeniye).
  Future<Timeline> forDay(String day) async {
    final w = utcWindowForLocalDay(day);
    final entries = (await _entries.listInRange(w.from, w.to))
        .where((e) => localDayOf(e.timestamp, e.utcOffsetMinutes) == day)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return Timeline(
      dailyLog: await _dailyLogs.getByDate(day),
      symptomEntries: entries,
      medicationLogs: await _medications.logsForDay(day),
    );
  }
}
