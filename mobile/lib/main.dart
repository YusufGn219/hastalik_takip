import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/app_root.dart';
import 'app/database_error_app.dart';
import 'core/notifications/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'data/database/app_database.dart';
import 'data/database/database_opener.dart';
import 'data/database/seed_loader.dart';
import 'features/analytics/screens/analytics_screen.dart';
import 'features/auth/onboarding_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/episode/screens/episode_list_screen.dart';
import 'features/health/screens/daily_log_screen.dart';
import 'features/health/screens/symptom_screen.dart';
import 'features/home/home_screen.dart';
import 'features/lock/app_lock_gate.dart';
import 'features/lock/app_lock_native.dart';
import 'features/lock/app_lock_platform.dart';
import 'features/medication/screens/chronic_condition_screen.dart';
import 'features/medication/screens/medication_log_screen.dart';
import 'features/medication/screens/recurring_screen.dart';
import 'features/profile/screens/change_password_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/timeline/screens/timeline_screen.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await NotificationService.initialize();

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

  runApp(
    AppRoot(
      database: db,
      prefs: prefs,
      openDatabase: _openSeededDatabase,
      eraseStorage: eraseDatabaseStorage,
      overrides: [
        biometricAuthenticatorProvider.overrideWithValue(LocalAuthBiometric()),
        screenSecurityProvider.overrideWithValue(MethodChannelScreenSecurity()),
      ],
      child: const MyApp(),
    ),
  );
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
        // Giriş/kayıt yok (hesap yok); uygulama doğrudan ana ekrana açılır.
        '/': (context) => const HomeScreen(),
        '/home': (context) => const HomeScreen(),
        // Aşağıdakiler henüz eski sunucu koduna bağlı; Sprint 3-6'da yeni
        // servislere bağlanır ya da kaldırılır.
        '/timeline': (context) => const TimelineScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/daily-log': (context) => const DailyLogScreen(),
        '/symptoms': (context) => const SymptomScreen(),
        '/episodes': (context) => const EpisodeListScreen(),
        '/medication-log': (context) => const MedicationLogScreen(),
        '/chronic-conditions': (context) => const ChronicConditionScreen(),
        '/recurring': (context) => const RecurringScreen(),
        '/analytics': (context) => const AnalyticsScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/change-password': (context) => const ChangePasswordScreen(),
      },
    );
  }
}
