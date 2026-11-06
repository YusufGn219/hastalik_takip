// Riverpod sağlayıcıları: veritabanı → repository'ler → servisler.
//
// Veritabanı `main()` içinde açılır ve burada geçersiz kılınır (override);
// böylece ekranlar tek satırla (`ref.watch(episodeServiceProvider)`) servise
// ulaşır ve testler bellek içi veritabanı verebilir.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/repositories/daily_log_repository.dart';
import '../data/repositories/episode_repository.dart';
import '../data/repositories/medication_log_repository.dart';
import '../data/repositories/medication_repository.dart';
import '../data/repositories/support.dart';
import '../data/repositories/symptom_entry_repository.dart';
import '../data/repositories/symptom_repository.dart';
import '../domain/services/episode_service.dart';
import '../domain/services/medication_service.dart';
import '../domain/services/timeline_service.dart';
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

final dailyLogRepositoryProvider = Provider<DailyLogRepository>(
  (ref) => DriftDailyLogRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

// ------------------------------------------------------------------ servisler

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

/// Dönem listesi ekranının okuma modeli (dönem + semptom adı + girişler +
/// konumlar).
final episodeOverviewLoaderProvider = Provider<EpisodeOverviewLoader>(
  (ref) => EpisodeOverviewLoader(
    episodes: ref.watch(episodeRepositoryProvider),
    entries: ref.watch(symptomEntryRepositoryProvider),
    symptoms: ref.watch(symptomRepositoryProvider),
  ),
);

final timelineServiceProvider = Provider<TimelineService>(
  (ref) => TimelineService(
    dailyLogs: ref.watch(dailyLogRepositoryProvider),
    entries: ref.watch(symptomEntryRepositoryProvider),
    medications: ref.watch(medicationServiceProvider),
  ),
);
