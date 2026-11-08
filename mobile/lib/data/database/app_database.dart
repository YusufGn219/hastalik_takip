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
    MedicationCategories,
    Medications,
    ChronicConditions,
    ConditionMedications,
    MedicationLogs,
    DoseSkips,
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
  ///
  /// Sürüm geçmişi:
  ///  * 1: ilk şema.
  ///  * 2: ilaç türü (`medications.type`: kronik/semptomatik) kalktı; yerine
  ///    kullanıcının kendi kategorileri (`medication_categories` tablosu ve
  ///    `medications.category_id`) geldi.
  ///  * 3: planlı doz takibi. `medication_logs.scheduled_time/scheduled_day`
  ///    (alımın hangi dozu için olduğu) ve `dose_skips` tablosu (açıkça
  ///    atlanan dozlar) geldi; ilaçta birden fazla doz saati
  ///    (`recurring_time` virgüllü liste) desteklenir (şema aynı).
  ///  * 4: profil kimliği. `profiles.display_name` yerine ayrı `first_name` /
  ///    `last_name`; kullanılmayan `photo_path` yerine veritabanı içi `photo`
  ///    (BLOB). Eski `display_name` değeri `first_name`'e taşınır.
  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          for (final statement in _extraIndexes) {
            await customStatement(statement);
          }
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // Eski `type` değerleri kategoriye çevrilmez, atılır (karar:
            // kategori kullanıcıya özeldir, katalogdan gelmez).
            await m.createTable(medicationCategories);
            await m.addColumn(medications, medications.categoryId);
            await m.dropColumn(medications, 'type');
            await customStatement(_medicationCategoryNameIndex);
          }
          if (from < 3) {
            // Eski alım kayıtları plansız (boş) kalır; hiçbiri değişmez.
            await m.addColumn(medicationLogs, medicationLogs.scheduledTime);
            await m.addColumn(medicationLogs, medicationLogs.scheduledDay);
            await m.createTable(doseSkips);
            await customStatement(_medicationLogDoseIndex);
            await customStatement(_doseSkipDoseIndex);
          }
          if (from < 4) {
            await m.addColumn(profiles, profiles.firstName);
            await m.addColumn(profiles, profiles.lastName);
            await m.addColumn(profiles, profiles.photo);
            await customStatement(
                'UPDATE profiles SET first_name = display_name');
            await m.dropColumn(profiles, 'display_name');
            await m.dropColumn(profiles, 'photo_path');
          }
        },
        beforeOpen: (details) async {
          // Yabancı anahtar kısıtları SQLite'ta varsayılan olarak kapalıdır.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Silme işaretli kayıtları saymayan tekillik kuralları ve sık kullanılan
  /// aralık sorguları için dizinler. (Drift bildirimi kısmi dizini desteklemez.)
  static const _medicationCategoryNameIndex =
      'CREATE UNIQUE INDEX uq_medication_categories_name '
      'ON medication_categories (name) WHERE deleted_at IS NULL';

  /// Bir doz (ilaç, gün, saat) için en çok bir alım kaydı.
  static const _medicationLogDoseIndex =
      'CREATE UNIQUE INDEX uq_medication_logs_dose '
      'ON medication_logs (medication_id, scheduled_day, scheduled_time) '
      'WHERE deleted_at IS NULL AND scheduled_time IS NOT NULL';

  /// Bir doz (ilaç, gün, saat) için en çok bir atlama kaydı.
  static const _doseSkipDoseIndex =
      'CREATE UNIQUE INDEX uq_dose_skips_dose '
      'ON dose_skips (medication_id, scheduled_day, scheduled_time) '
      'WHERE deleted_at IS NULL';

  static const _extraIndexes = <String>[
    _medicationCategoryNameIndex,
    _medicationLogDoseIndex,
    _doseSkipDoseIndex,
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
