import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/screens/splash_screen.dart';
import 'core/notifications/notification_service.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/health/screens/daily_log_screen.dart';
import 'features/health/screens/symptom_screen.dart';
import 'features/timeline/screens/timeline_screen.dart';
import 'features/episode/screens/episode_list_screen.dart';
import 'features/medication/screens/medication_log_screen.dart';
import 'features/medication/screens/chronic_condition_screen.dart';
import 'features/medication/screens/recurring_screen.dart';
import 'features/analytics/screens/analytics_screen.dart';
import 'features/auth/onboarding_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/profile/screens/change_password_screen.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await NotificationService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vitapuls',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const TimelineScreen(),
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