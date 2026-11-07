// Zaman çizelgesi sorgusu: eski `services/health/timeline.py` portu.

import '../../data/database/app_database.dart';
import '../../data/repositories/daily_log_repository.dart';
import '../../data/repositories/dose_skip_repository.dart';
import '../../data/repositories/symptom_entry_repository.dart';
import '../local_day.dart';
import 'medication_service.dart';

class Timeline {
  const Timeline({
    required this.dailyLog,
    required this.symptomEntries,
    required this.medicationLogs,
    this.doseSkips = const [],
  });

  final DailyLog? dailyLog;
  final List<SymptomEntry> symptomEntries;
  final List<MedicationLog> medicationLogs;

  /// Bu günün planlı dozlarından açıkça "Atladım" denenler (alım kaydı değildir).
  final List<DoseSkip> doseSkips;
}

class TimelineService {
  TimelineService({
    required DailyLogRepository dailyLogs,
    required SymptomEntryRepository entries,
    required MedicationService medications,
    DoseSkipRepository? doseSkips,
  })  : _dailyLogs = dailyLogs,
        _entries = entries,
        _medications = medications,
        _doseSkips = doseSkips;

  final DailyLogRepository _dailyLogs;
  final SymptomEntryRepository _entries;
  final MedicationService _medications;
  final DoseSkipRepository? _doseSkips;

  /// Yerel [day] ('YYYY-MM-DD') gününün günlük kaydı, semptom girişleri ve
  /// ilaç alımları (girişler ve alımlar eskiden yeniye) ile o günün atlanan
  /// dozları.
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
      // Atlama, dozun planlı olduğu güne yazılır (atlamanın yapıldığı güne değil).
      doseSkips: await _doseSkips?.listForDay(day) ?? const [],
    );
  }
}
