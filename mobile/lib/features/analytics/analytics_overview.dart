// Analiz ekranının okuma modeli: dört hesabı (semptom, günlük, ilaç etkisi ve
// doz bazlı ilaç uyumu) aynı dönem için birlikte okur.

import '../../domain/services/analytics_service.dart';
import '../../domain/services/dose_adherence_service.dart';
import '../../domain/services/field_analytics_service.dart';

class AnalyticsOverview {
  const AnalyticsOverview({
    required this.days,
    required this.symptoms,
    required this.daily,
    required this.effect,
    required this.adherence,
    this.fields = const FieldAnalytics(0, []),
  });

  final int days;
  final SymptomAnalytics symptoms;
  final DailyTrends daily;
  final MedicationEffect effect;
  final DoseAdherence adherence;

  /// Ek günlük alanların analizi; okunamazsa boş (diğer sekmeler etkilenmez).
  final FieldAnalytics fields;
}

class AnalyticsOverviewLoader {
  AnalyticsOverviewLoader({
    required AnalyticsService analytics,
    required DoseAdherenceService adherence,
    FieldAnalyticsService? fieldAnalytics,
  })  : _analytics = analytics,
        _adherence = adherence,
        _fieldAnalytics = fieldAnalytics;

  final AnalyticsService _analytics;
  final DoseAdherenceService _adherence;
  final FieldAnalyticsService? _fieldAnalytics;

  Future<AnalyticsOverview> load(int days) async {
    final symptoms = await _analytics.symptomAnalytics(days);
    final daily = await _analytics.dailyTrends(days);
    final effect = await _analytics.medicationEffect(days);
    final adherence = await _adherence.doseAdherence(days);
    var fields = FieldAnalytics(days, const []);
    try {
      fields = await _fieldAnalytics?.analyze(days) ?? fields;
    } catch (_) {
      // Ek alanlar okunamazsa yalnız o sekme boş görünür.
    }
    return AnalyticsOverview(
      days: days,
      symptoms: symptoms,
      daily: daily,
      effect: effect,
      adherence: adherence,
      fields: fields,
    );
  }
}
