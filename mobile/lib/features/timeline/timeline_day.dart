// Zaman çizelgesi ekranının okuma modeli: bir günün kayıtlarını (semptom girişi,
// ilaç alımı, atlanan doz) adlarıyla birlikte tek sıralı liste olarak toplar.

import '../../data/database/app_database.dart';
import '../../data/repositories/medication_repository.dart';
import '../../data/repositories/symptom_repository.dart';
import '../../domain/services/timeline_service.dart';
import '../episode/episode_overview.dart';

/// Çizelgedeki tek satır. [instant] kaydın anı (UTC), [offsetMinutes] kaydın
/// kendi UTC farkı: saat, kayıt anındaki cihaz saatiyle yazılır, saat dilimi
/// değişse de eski kayıtlar kaymaz.
sealed class TimelineItem {
  const TimelineItem();

  DateTime get instant;
  int get offsetMinutes;
}

class SymptomTimelineItem extends TimelineItem {
  const SymptomTimelineItem(this.entry, this.symptomName);

  final SymptomEntry entry;

  /// Semptom bulunamazsa boş metin.
  final String symptomName;

  @override
  DateTime get instant => entry.timestamp;
  @override
  int get offsetMinutes => entry.utcOffsetMinutes;
}

class IntakeTimelineItem extends TimelineItem {
  const IntakeTimelineItem(this.log, this.medicationName);

  final MedicationLog log;

  /// İlaç bulunamazsa boş metin.
  final String medicationName;

  /// Rutin dozu için alındıysa doz saati 'HH:mm'; plansız alımda null.
  String? get scheduledTime => log.scheduledTime;

  @override
  DateTime get instant => log.takenAt;
  @override
  int get offsetMinutes => log.utcOffsetMinutes;
}

class SkipTimelineItem extends TimelineItem {
  const SkipTimelineItem(this.skip, this.medicationName);

  final DoseSkip skip;
  final String medicationName;

  /// Atlanan dozun saati 'HH:mm'.
  String get scheduledTime => skip.scheduledTime;

  @override
  DateTime get instant => skip.skippedAt;
  @override
  int get offsetMinutes => skip.utcOffsetMinutes;
}

/// Bir günün çizelgesi. [activeEpisodes] yalnız istendiyse (bugün) dolu gelir.
class TimelineDay {
  const TimelineDay({
    required this.day,
    required this.dailyLog,
    required this.items,
    this.activeEpisodes = const [],
  });

  final String day;
  final DailyLog? dailyLog;

  /// Zamana göre eskiden yeniye.
  final List<TimelineItem> items;
  final List<EpisodeOverview> activeEpisodes;

  bool get isEmpty => dailyLog == null && items.isEmpty;
}

class TimelineDayLoader {
  TimelineDayLoader({
    required TimelineService timeline,
    required SymptomRepository symptoms,
    required MedicationRepository medications,
    required EpisodeOverviewLoader episodes,
  })  : _timeline = timeline,
        _symptoms = symptoms,
        _medications = medications,
        _episodes = episodes;

  final TimelineService _timeline;
  final SymptomRepository _symptoms;
  final MedicationRepository _medications;
  final EpisodeOverviewLoader _episodes;

  Future<TimelineDay> load(String day, {bool withActiveEpisodes = false}) async {
    final t = await _timeline.forDay(day);
    final symptomNames = <String, String>{};
    final medicationNames = <String, String>{};

    Future<String> symptomName(String id) async => symptomNames[id] ??=
        (await _symptoms.getById(id))?.name ?? '';
    Future<String> medicationName(String id) async => medicationNames[id] ??=
        (await _medications.getById(id))?.name ?? '';

    final items = <TimelineItem>[
      for (final e in t.symptomEntries)
        SymptomTimelineItem(e, await symptomName(e.symptomId)),
      for (final l in t.medicationLogs)
        IntakeTimelineItem(l, await medicationName(l.medicationId)),
      for (final s in t.doseSkips)
        SkipTimelineItem(s, await medicationName(s.medicationId)),
    ]..sort((a, b) => a.instant.compareTo(b.instant));

    return TimelineDay(
      day: day,
      dailyLog: t.dailyLog,
      items: items,
      activeEpisodes:
          withActiveEpisodes ? (await _episodes.load()).active : const [],
    );
  }
}
