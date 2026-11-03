import 'package:drift/drift.dart';

import 'enums.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Profiles,
    AppSettings,
    Symptoms,
    Episodes,
    SymptomEntries,
    EpisodeLocationEntries,
    Medications,
    ChronicConditions,
    ConditionMedications,
    MedicationLogs,
    DailyLogs,
    Measurements,
    Tags,
    TagEntries,
    CyclePeriods,
    CycleFlows,
    CycleStatuses,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Şema sürümü. Tablo/sütun değişince artırılır ve [migration]'a adım eklenir.
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          for (final statement in _extraIndexes) {
            await customStatement(statement);
          }
        },
        beforeOpen: (details) async {
          // Yabancı anahtar kısıtları SQLite'ta varsayılan olarak kapalıdır.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Silme işaretli kayıtları saymayan tekillik kuralları ve sık kullanılan
  /// aralık sorguları için dizinler. (Drift bildirimi kısmi dizini desteklemez.)
  static const _extraIndexes = <String>[
    'CREATE UNIQUE INDEX uq_symptoms_name ON symptoms (name) '
        'WHERE deleted_at IS NULL',
    'CREATE UNIQUE INDEX uq_tags_name ON tags (name) '
        'WHERE deleted_at IS NULL',
    'CREATE UNIQUE INDEX uq_daily_logs_date ON daily_logs (log_date) '
        'WHERE deleted_at IS NULL',
    'CREATE UNIQUE INDEX uq_cycle_flows_date ON cycle_flows (flow_date) '
        'WHERE deleted_at IS NULL',
    'CREATE UNIQUE INDEX uq_medications_notification_id '
        'ON medications (notification_id) WHERE notification_id IS NOT NULL',
    'CREATE INDEX ix_symptom_entries_timestamp ON symptom_entries (timestamp)',
    'CREATE INDEX ix_symptom_entries_episode ON symptom_entries (episode_id)',
    'CREATE INDEX ix_medication_logs_taken_at ON medication_logs (taken_at)',
    'CREATE INDEX ix_medication_logs_episode ON medication_logs (episode_id)',
    'CREATE INDEX ix_measurements_type_date ON measurements (type, log_date)',
    'CREATE INDEX ix_tag_entries_occurred_at ON tag_entries (occurred_at)',
  ];
}
