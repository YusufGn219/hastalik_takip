// Analiz ekranının okuma modeli: dört hesabı (semptom, günlük, ilaç etkisi ve
// doz bazlı ilaç uyumu) aynı dönem için birlikte okur.

import '../../domain/services/analytics_service.dart';
import '../../domain/services/dose_adherence_service.dart';

class AnalyticsOverview {
  const AnalyticsOverview({
    required this.days,
    required this.symptoms,
    required this.daily,
    required this.effect,
    required this.adherence,
  });

  final int days;
  final SymptomAnalytics symptoms;
  final DailyTrends daily;
  final MedicationEffect effect;
  final DoseAdherence adherence;
}

class AnalyticsOverviewLoader {
  AnalyticsOverviewLoader({
    required AnalyticsService analytics,
    required DoseAdherenceService adherence,
  })  : _analytics = analytics,
        _adherence = adherence;

  final AnalyticsService _analytics;
  final DoseAdherenceService _adherence;

  Future<AnalyticsOverview> load(int days) async {
    final symptoms = await _analytics.symptomAnalytics(days);
    final daily = await _analytics.dailyTrends(days);
    final effect = await _analytics.medicationEffect(days);
    final adherence = await _adherence.doseAdherence(days);
    return AnalyticsOverview(
      days: days,
      symptoms: symptoms,
      daily: daily,
      effect: effect,
      adherence: adherence,
    );
  }
}
