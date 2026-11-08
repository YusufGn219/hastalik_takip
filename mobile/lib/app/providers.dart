// Riverpod sağlayıcıları: veritabanı → repository'ler → servisler.
//
// Veritabanı `main()` içinde açılır ve burada geçersiz kılınır (override);
// böylece ekranlar tek satırla (`ref.watch(episodeServiceProvider)`) servise
// ulaşır ve testler bellek içi veritabanı verebilir.

import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notifications/notification_gateway.dart';
import '../core/notifications/notification_service.dart';
import '../data/database/app_database.dart';
import '../data/repositories/daily_log_repository.dart';
import '../data/repositories/dose_skip_repository.dart';
import '../data/repositories/episode_repository.dart';
import '../data/repositories/medication_log_repository.dart';
import '../data/repositories/daily_field_repository.dart';
import '../data/repositories/measurement_repository.dart';
import '../data/repositories/medication_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/support.dart';
import '../data/repositories/symptom_entry_repository.dart';
import '../data/repositories/symptom_repository.dart';
import '../domain/services/analytics_service.dart';
import '../domain/services/body_measurement_service.dart';
import '../domain/services/daily_field_service.dart';
import '../domain/services/dose_adherence_service.dart';
import '../domain/services/dose_service.dart';
import '../domain/services/episode_service.dart';
import '../domain/services/medication_service.dart';
import '../domain/services/reminder_service.dart';
import '../domain/services/timeline_service.dart';
import '../features/analytics/analytics_overview.dart';
import '../features/timeline/timeline_day.dart';
import '../l10n/app_localizations.dart';
import '../features/episode/episode_overview.dart';

/// `main()` açılmış veritabanıyla bunu geçersiz kılmak zorundadır.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw StateError(
    'databaseProvider geçersiz kılınmadı: ProviderScope(overrides: ...) kullanın.',
  ),
);

/// Şimdiki zaman; testlerde sabitlenebilir.
final clockProvider = Provider<Clock>((ref) => DateTime.now);

// ------------------------------------------------------------ repository'ler

final symptomRepositoryProvider = Provider<SymptomRepository>(
  (ref) => DriftSymptomRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

final episodeRepositoryProvider = Provider<EpisodeRepository>(
  (ref) => DriftEpisodeRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

final symptomEntryRepositoryProvider = Provider<SymptomEntryRepository>(
  (ref) => DriftSymptomEntryRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

final medicationRepositoryProvider = Provider<MedicationRepository>(
  (ref) => DriftMedicationRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

final medicationLogRepositoryProvider = Provider<MedicationLogRepository>(
  (ref) => DriftMedicationLogRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

final doseSkipRepositoryProvider = Provider<DoseSkipRepository>(
  (ref) => DriftDoseSkipRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

final dailyLogRepositoryProvider = Provider<DailyLogRepository>(
  (ref) => DriftDailyLogRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => DriftSettingsRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

final measurementRepositoryProvider = Provider<MeasurementRepository>(
  (ref) => DriftMeasurementRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => DriftProfileRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// Yerel profil (tek satır). Kaydedildikten sonra `ref.invalidate` ile tazelenir.
final profileProvider = FutureProvider.autoDispose<Profile>(
  (ref) => ref.watch(profileRepositoryProvider).get(),
);

// ------------------------------------------------------------------ servisler

final bodyMeasurementServiceProvider = Provider<BodyMeasurementService>(
  (ref) => BodyMeasurementService(
    measurements: ref.watch(measurementRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// Boy ve kilo görünümü. Kayıttan sonra `ref.invalidate` ile tazelenir.
final bodyMeasurementsProvider = FutureProvider.autoDispose<BodyMeasurements>(
  (ref) => ref.watch(bodyMeasurementServiceProvider).overview(),
);

final dailyFieldRepositoryProvider = Provider<DailyFieldRepository>(
  (ref) => DriftDailyFieldRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

final dailyFieldServiceProvider = Provider<DailyFieldService>(
  (ref) => DailyFieldService(
    fields: ref.watch(dailyFieldRepositoryProvider),
    measurements: ref.watch(measurementRepositoryProvider),
    clock: ref.watch(clockProvider),
    transactor: ref.watch(databaseProvider).transaction,
  ),
);

final episodeServiceProvider = Provider<EpisodeService>(
  (ref) => EpisodeService(
    episodes: ref.watch(episodeRepositoryProvider),
    entries: ref.watch(symptomEntryRepositoryProvider),
    transactor: ref.watch(databaseProvider).transaction,
    clock: ref.watch(clockProvider),
  ),
);

final medicationServiceProvider = Provider<MedicationService>(
  (ref) => MedicationService(
    medications: ref.watch(medicationRepositoryProvider),
    logs: ref.watch(medicationLogRepositoryProvider),
  ),
);

/// Telefonun bildirim sistemi; testlerde sahtesiyle geçersiz kılınır.
final notificationGatewayProvider = Provider<NotificationGateway>(
  (ref) => NotificationService.instance,
);

/// Doz hatırlatmalarının metinleri (şimdilik yalnız Türkçe).
final reminderTextsProvider = Provider<ReminderTexts>(
  (ref) => ReminderTexts.fromL10n(lookupAppLocalizations(const Locale('tr'))),
);

/// Rutin dozların hatırlatma bildirimleri (her dozun kendi saatinde).
final reminderServiceProvider = Provider<ReminderService>(
  (ref) => ReminderService(
    medications: ref.watch(medicationRepositoryProvider),
    gateway: ref.watch(notificationGatewayProvider),
    texts: ref.watch(reminderTextsProvider),
  ),
);

/// Rutin dozların takibi (alındı / atlandı / kaydedilmedi).
final doseServiceProvider = Provider<DoseService>(
  (ref) => DoseService(
    medications: ref.watch(medicationRepositoryProvider),
    logs: ref.watch(medicationLogRepositoryProvider),
    skips: ref.watch(doseSkipRepositoryProvider),
    transactor: ref.watch(databaseProvider).transaction,
    clock: ref.watch(clockProvider),
  ),
);

/// Dönem listesi ekranının okuma modeli (dönem + semptom adı + girişler +
/// konumlar).
final episodeOverviewLoaderProvider = Provider<EpisodeOverviewLoader>(
  (ref) => EpisodeOverviewLoader(
    episodes: ref.watch(episodeRepositoryProvider),
    entries: ref.watch(symptomEntryRepositoryProvider),
    symptoms: ref.watch(symptomRepositoryProvider),
    medicationLogs: ref.watch(medicationLogRepositoryProvider),
    medications: ref.watch(medicationRepositoryProvider),
  ),
);

final timelineServiceProvider = Provider<TimelineService>(
  (ref) => TimelineService(
    dailyLogs: ref.watch(dailyLogRepositoryProvider),
    entries: ref.watch(symptomEntryRepositoryProvider),
    medications: ref.watch(medicationServiceProvider),
    doseSkips: ref.watch(doseSkipRepositoryProvider),
  ),
);

/// Zaman çizelgesi ekranı için günün kayıtlarını adlarıyla toplar.
final timelineDayLoaderProvider = Provider<TimelineDayLoader>(
  (ref) => TimelineDayLoader(
    timeline: ref.watch(timelineServiceProvider),
    symptoms: ref.watch(symptomRepositoryProvider),
    medications: ref.watch(medicationRepositoryProvider),
    episodes: ref.watch(episodeOverviewLoaderProvider),
  ),
);

/// Doz bazlı ilaç uyumu (alındı / atlandı / kaydedilmedi).
final doseAdherenceServiceProvider = Provider<DoseAdherenceService>(
  (ref) => DoseAdherenceService(
    doses: ref.watch(doseServiceProvider),
    logs: ref.watch(medicationLogRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// Semptom, günlük ve ilaç etkisi hesapları.
final analyticsServiceProvider = Provider<AnalyticsService>(
  (ref) => AnalyticsService(
    entries: ref.watch(symptomEntryRepositoryProvider),
    symptoms: ref.watch(symptomRepositoryProvider),
    medicationLogs: ref.watch(medicationLogRepositoryProvider),
    medications: ref.watch(medicationRepositoryProvider),
    dailyLogs: ref.watch(dailyLogRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// Analiz ekranı için dört hesabı birlikte okur.
final analyticsOverviewLoaderProvider = Provider<AnalyticsOverviewLoader>(
  (ref) => AnalyticsOverviewLoader(
    analytics: ref.watch(analyticsServiceProvider),
    adherence: ref.watch(doseAdherenceServiceProvider),
  ),
);
