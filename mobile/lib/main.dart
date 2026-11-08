import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/app_root.dart';
import 'app/database_error_app.dart';
import 'core/notifications/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'data/database/app_database.dart';
import 'data/database/database_opener.dart';
import 'data/database/seed_loader.dart';
import 'data/repositories/medication_repository.dart';
import 'domain/services/reminder_service.dart';
import 'features/analytics/screens/analytics_dashboard_screen.dart';
import 'features/backup/backup_export_screen.dart';
import 'features/backup/backup_restore_screen.dart';
import 'features/episode/screens/episode_list_screen.dart';
import 'features/health/screens/daily_fields_screen.dart';
import 'features/health/screens/daily_log_screen.dart';
import 'features/health/screens/symptom_screen.dart';
import 'features/home/home_screen.dart';
import 'features/lock/app_lock_gate.dart';
import 'features/lock/app_lock_native.dart';
import 'features/lock/app_lock_platform.dart';
import 'features/medication/screens/chronic_condition_screen.dart';
import 'features/medication/screens/medication_log_screen.dart';
import 'features/medication/screens/recurring_screen.dart';
import 'features/onboarding/start_screen.dart';
import 'features/profile/body_measurements_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/timeline/screens/day_timeline_screen.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Bildirim altyapısı hazırlanır ama izin İSTENMEZ (izinler ilk rutinde sorulur).
  try {
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('Bildirim altyapısı başlatılamadı: ${e.runtimeType}');
  }

  final prefs = await SharedPreferences.getInstance();

  // Şifreli yerel veritabanı: açılamazsa uygulama devam etmez, hata ekranı çıkar.
  AppDatabase? db;
  try {
    db = await _openSeededDatabase();
  } catch (e) {
    debugPrint('Veritabanı açılamadı: ${e.runtimeType}');
    runApp(const DatabaseErrorApp());
    return;
  }

  await _rescheduleReminders(db);

  runApp(
    AppRoot(
      database: db,
      prefs: prefs,
      openDatabase: _openSeededDatabase,
      eraseStorage: _eraseEverything,
      onDatabaseReplaced: _afterRestore,
      overrides: [
        biometricAuthenticatorProvider.overrideWithValue(LocalAuthBiometric()),
        screenSecurityProvider.overrideWithValue(MethodChannelScreenSecurity()),
      ],
      child: const MyApp(),
    ),
  );
}

/// Tüm rutin hatırlatmalarını baştan kurar (cihazın saat dilimi değişmiş olabilir,
/// kayıtlar güncel olsun). Hata uygulamayı durdurmaz.
Future<void> _rescheduleReminders(AppDatabase db) async {
  try {
    await ReminderService(
      medications: DriftMedicationRepository(db),
      gateway: NotificationService.instance,
      texts: ReminderTexts.fromL10n(lookupAppLocalizations(const Locale('tr'))),
    ).rescheduleAll();
  } catch (e) {
    debugPrint('Hatırlatmalar yeniden kurulamadı: ${e.runtimeType}');
  }
}

/// "Tüm veriyi sil" son çaresi: planlı bildirimler de silinir (yoksa silinen
/// veriye ait hatırlatmalar gelmeye devam ederdi), sonra veritabanı dosyaları.
Future<void> _eraseEverything() async {
  try {
    await NotificationService.instance.cancelAll();
  } catch (e) {
    debugPrint('Bildirimler iptal edilemedi: ${e.runtimeType}');
  }
  await eraseDatabaseStorage();
}

/// Yedekten geri yüklemeden sonra: eski veriye ait planlı bildirimler iptal edilir,
/// geri yüklenen rutinlere göre baştan kurulur.
Future<void> _afterRestore(AppDatabase db) async {
  try {
    await NotificationService.instance.cancelAll();
  } catch (e) {
    debugPrint('Bildirimler iptal edilemedi: ${e.runtimeType}');
  }
  await _rescheduleReminders(db);
}

/// Veritabanını açar ve başlangıç verisini yükler; yüklenemezse kapatıp hatayı atar.
Future<AppDatabase> _openSeededDatabase() async {
  final db = await openAppDatabase();
  try {
    await SeedLoader(db).seedIfNeeded();
  } catch (_) {
    await db.close();
    rethrow;
  }
  return db;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Uygulama kilidi: kuruluysa tüm gezginin üstüne kilit ekranını bindirir.
      builder: (context, child) => AppLockGate(child: child!),
      initialRoute: '/',
      routes: {
        // Giriş/kayıt yok (hesap yok): ilk açılışta tanıtım, sonra ana ekran.
        '/': (context) => const StartScreen(),
        '/home': (context) => const HomeScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/body': (context) => const BodyMeasurementsScreen(),
        '/backup': (context) => const BackupExportScreen(),
        '/restore': (context) => const BackupRestoreScreen(),
        '/timeline': (context) => const DayTimelineScreen(),
        '/daily-log': (context) => const DailyLogScreen(),
        '/daily-fields': (context) => const DailyFieldsScreen(),
        '/symptoms': (context) => const SymptomScreen(),
        '/episodes': (context) => const EpisodeListScreen(),
        '/medication-log': (context) => const MedicationLogScreen(),
        '/chronic-conditions': (context) => const ChronicConditionScreen(),
        '/recurring': (context) => const RecurringScreen(),
        '/analytics': (context) => const AnalyticsDashboardScreen(),
      },
    );
  }
}
