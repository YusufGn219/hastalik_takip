import 'package:flutter/material.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/health/screens/daily_log_screen.dart';
import 'features/health/screens/symptom_screen.dart';
import 'features/timeline/screens/timeline_screen.dart';
import 'features/episode/screens/episode_list_screen.dart';
import 'features/medication/screens/medication_log_screen.dart';
import 'features/medication/screens/chronic_condition_screen.dart';
import 'features/medication/screens/recurring_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hastalık Takip',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const TimelineScreen(),
        '/daily-log': (context) => const DailyLogScreen(),
        '/symptoms': (context) => const SymptomScreen(),
        '/episodes': (context) => const EpisodeListScreen(),
        '/medication-log': (context) => const MedicationLogScreen(),
        '/chronic-conditions': (context) => const ChronicConditionScreen(),
        '/recurring': (context) => const RecurringScreen(),
      },
    );
  }
}