// Analizler: dört sekme (semptomlar, günlük, ilaç etkisi, ilaç uyumu), 7/30/90
// gün. Yerel veritabanından AnalyticsOverviewLoader ile okur. İlaç uyumu doz
// bazlıdır (alındı / atlandı / kaydedilmedi). Yalnız okur.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/services/analytics_service.dart';
import '../../../domain/services/dose_adherence_service.dart';
import '../../../l10n/app_localizations.dart';
import '../analytics_overview.dart';

/// Seçilebilen dönemler (gün).
const analyticsPeriods = [7, 30, 90];

class AnalyticsDashboardScreen extends ConsumerStatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  ConsumerState<AnalyticsDashboardScreen> createState() =>
      _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState
    extends ConsumerState<AnalyticsDashboardScreen> {
  int _days = 30;
  AnalyticsOverview? _data;
  bool _isLoading = true;
  bool _loadFailed = false;

  /// Dönem hızlı değişince geç dönen eski yanıtın ekranı bozmaması için.
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = ++_requestId;
    setState(() => _isLoading = true);
    try {
      final data = await ref.read(analyticsOverviewLoaderProvider).load(_days);
      if (!mounted || id != _requestId) return;
      setState(() {
        _data = data;
        _loadFailed = false;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _loadFailed = true;
        _isLoading = false;
      });
    }
  }

  void _setDays(int days) {
    if (days == _days) return;
    setState(() => _days = days);
    _load();
  }

  // ------------------------------------------------------------ yardımcılar

  String get _locale => Localizations.localeOf(context).toString();

  String _n(num v) => NumberFormat.decimalPattern(_locale).format(v);

  Color get _muted =>
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  // ------------------------------------------------------------------ ekran

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.analyticsTitle),
          bottom: TabBar(
            indicatorColor: AppColors.primary400,
            labelColor: AppColors.primary400,
            unselectedLabelColor: _muted,
            indicatorSize: TabBarIndicatorSize.label,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: l10n.analyticsTabSymptoms),
              Tab(text: l10n.analyticsTabDaily),
              Tab(text: l10n.analyticsTabEffect),
              Tab(text: l10n.analyticsTabAdherence),
            ],
          ),
        ),
        body: Column(
          children: [
            _periodSelector(l10n),
            Expanded(child: _body(l10n)),
          ],
        ),
      ),
    );
  }

  Widget _periodSelector(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          for (final days in analyticsPeriods)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: ValueKey('analytics-days-$days'),
                label: Text(l10n.analyticsDays(days)),
                selected: _days == days,
                onSelected: (_) => _setDays(days),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body(AppLocalizations l10n) {
    if (_isLoading && _data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final data = _data;
    if (_loadFailed || data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.analyticsLoadError,
            key: const ValueKey('analytics-error'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
    return Stack(
      children: [
        TabBarView(
          children: [
            _symptomsTab(data, l10n),
            _dailyTab(data, l10n),
            _effectTab(data, l10n),
            _adherenceTab(data, l10n),
          ],
        ),
        if (_isLoading) const LinearProgressIndicator(minHeight: 2),
      ],
    );
  }

  // ------------------------------------------------------------ semptomlar

  Widget _symptomsTab(AnalyticsOverview data, AppLocalizations l10n) {
    final freq = data.symptoms.frequency;
    final trend = data.symptoms.severityTrend;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle(l10n.analyticsSymptomFrequency),
        const SizedBox(height: 8),
        if (freq.isEmpty)
          _emptyCard(l10n.analyticsNoSymptoms, 'analytics-symptoms-empty')
        else
          _card(child: _frequencyBars(freq, l10n)),
        const SizedBox(height: 20),
        _sectionTitle(l10n.analyticsSeverityTrend),
        const SizedBox(height: 8),
        if (trend.isEmpty)
          _emptyCard(l10n.analyticsNotEnoughData, 'analytics-trend-empty')
        else
          _card(
            child: _lineChart(
              dates: [for (final p in trend) p.date],
              maxY: 10,
              lines: [
                _Line(
                  AppColors.episode,
                  [for (final p in trend) p.avgSeverity],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _frequencyBars(List<SymptomFrequency> items, AppLocalizations l10n) {
    final maxCount = items.map((e) => e.count).reduce((a, b) => a > b ? a : b);
    return Column(
      children: [
        for (final item in items)
          Padding(
            key: ValueKey('freq-${item.symptomName}'),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(item.symptomName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 14)),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.symptomBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(l10n.analyticsCount(item.count),
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.symptom)),
                    ),
                    const SizedBox(width: 6),
                    Text(l10n.analyticsAvg(_n(item.avgSeverity)),
                        style: TextStyle(fontSize: 11, color: _muted)),
                  ],
                ),
                const SizedBox(height: 6),
                _bar(item.count / maxCount, AppColors.symptom, height: 8),
              ],
            ),
          ),
      ],
    );
  }

  // ----------------------------------------------------------------- günlük

  Widget _dailyTab(AnalyticsOverview data, AppLocalizations l10n) {
    final trends = data.daily.trends;
    final a = data.daily.averages;
    String v(double? x, String Function(String) f) => x == null ? '-' : f(_n(x));
    final rows = [
      ('😴', l10n.analyticsSleep, v(a['sleep_hours'], l10n.analyticsHours),
          AppColors.primary400),
      ('💧', l10n.analyticsWater, v(a['water_intake'], l10n.analyticsLiters),
          AppColors.medication),
      ('😊', l10n.analyticsMood, v(a['mood'], l10n.analyticsOutOf5),
          Colors.green),
      ('⚡', l10n.analyticsEnergy, v(a['energy_level'], l10n.analyticsOutOf5),
          Colors.amber),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle(l10n.analyticsDailyAverages(data.days)),
        const SizedBox(height: 8),
        _card(
          child: Column(
            children: [
              for (final (emoji, label, value, color) in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                            child: Text(emoji, style: const TextStyle(fontSize: 18))),
                      ),
                      const SizedBox(width: 12),
                      Text(label, style: const TextStyle(fontSize: 14)),
                      const Spacer(),
                      Text(value,
                          key: ValueKey('daily-avg-$label'),
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: color)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _sectionTitle(l10n.analyticsMoodEnergyTrend),
        const SizedBox(height: 8),
        if (trends.isEmpty)
          _emptyCard(l10n.analyticsNoDaily, 'analytics-daily-empty')
        else
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  _legend(AppColors.primary400, l10n.analyticsMood),
                  const SizedBox(width: 16),
                  _legend(Colors.amber, l10n.analyticsEnergy),
                ]),
                const SizedBox(height: 16),
                _lineChart(
                  dates: [for (final p in trends) p.date],
                  maxY: 5,
                  lines: [
                    _Line(AppColors.primary400,
                        [for (final p in trends) p.mood.toDouble()]),
                    _Line(Colors.amber,
                        [for (final p in trends) p.energyLevel.toDouble()]),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  // -------------------------------------------------------------- ilaç etkisi

  Widget _effectTab(AnalyticsOverview data, AppLocalizations l10n) {
    final effects = data.effect.effects;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle(l10n.analyticsEffectTitle),
        const SizedBox(height: 8),
        if (effects.isEmpty)
          _emptyCard(l10n.analyticsNoEffect, 'analytics-effect-empty')
        else
          for (final e in effects) _effectCard(e, l10n),
        const SizedBox(height: 8),
        Text(l10n.analyticsDisclaimer,
            style: TextStyle(fontSize: 12, color: _muted)),
      ],
    );
  }

  Widget _effectCard(MedicationEffectItem e, AppLocalizations l10n) {
    final diff = e.avgSeverityBefore - e.avgSeverityAfter;
    final relief = e.avgReliefMinutes;
    return Padding(
      key: ValueKey('effect-${e.medicationName}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.medicationName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      Text(l10n.analyticsUsed(e.usageCount),
                          style: TextStyle(fontSize: 12, color: _muted)),
                    ],
                  ),
                ),
                if (diff > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.dailyBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('-${_n(double.parse(diff.toStringAsFixed(1)))}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.daily)),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _effectBar(l10n.analyticsBefore, e.avgSeverityBefore, AppColors.episode),
            const SizedBox(height: 8),
            _effectBar(l10n.analyticsAfter, e.avgSeverityAfter, AppColors.daily),
            if (relief != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.timer_outlined, size: 14, color: _muted),
                  const SizedBox(width: 4),
                  Text(l10n.analyticsReliefMinutes(relief),
                      style: TextStyle(fontSize: 12, color: _muted)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _effectBar(String label, double value, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(label, style: TextStyle(fontSize: 12, color: _muted)),
        ),
        Expanded(child: _bar(value / 10, color, height: 10)),
        const SizedBox(width: 8),
        Text(_n(value),
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  // --------------------------------------------------------------------- uyum

  Widget _adherenceTab(AnalyticsOverview data, AppLocalizations l10n) {
    final items = data.adherence.items;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle(l10n.analyticsAdherenceTitle),
        const SizedBox(height: 8),
        if (items.isEmpty)
          _emptyCard(l10n.analyticsNoAdherence, 'analytics-adherence-empty')
        else
          for (final item in items) _adherenceCard(item, l10n),
        const SizedBox(height: 8),
        Text(l10n.analyticsAdherenceNote,
            style: TextStyle(fontSize: 12, color: _muted)),
        const SizedBox(height: 8),
        Text(l10n.analyticsDisclaimer,
            style: TextStyle(fontSize: 12, color: _muted)),
      ],
    );
  }

  Widget _adherenceCard(DoseAdherenceItem item, AppLocalizations l10n) {
    final rate = item.rate;
    final color = rate == null
        ? Colors.grey
        : rate >= 80
            ? AppColors.daily
            : rate >= 50
                ? AppColors.symptom
                : AppColors.episode;
    return Padding(
      key: ValueKey('adherence-${item.medicationId}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(item.medicationName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    rate == null
                        ? l10n.analyticsNoAdherenceData
                        : '%${_n(rate)}',
                    key: ValueKey('adherence-rate-${item.medicationId}'),
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: color, fontSize: 14),
                  ),
                ),
              ],
            ),
            if (rate != null) ...[
              const SizedBox(height: 10),
              _bar(rate / 100, color, height: 10),
              const SizedBox(height: 8),
              Text(
                l10n.analyticsAdherenceLine(
                    item.taken, item.skipped, item.unrecorded),
                key: ValueKey('adherence-line-${item.medicationId}'),
                style: TextStyle(fontSize: 12, color: _muted),
              ),
            ],
            if (item.extraIntakes > 0) ...[
              const SizedBox(height: 4),
              Text(l10n.analyticsExtra(item.extraIntakes),
                  style: TextStyle(fontSize: 12, color: _muted)),
            ],
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ ortak parçalar

  Widget _bar(double value, Color color, {required double height}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: color.withValues(alpha: 0.1),
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }

  Widget _lineChart({
    required List<String> dates,
    required double maxY,
    required List<_Line> lines,
  }) {
    final grid = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.07);
    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: grid, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          minY: 0,
          maxY: maxY,
          titlesData: _titles(dates),
          lineBarsData: [
            for (final line in lines)
              LineChartBarData(
                spots: [
                  for (var i = 0; i < line.values.length; i++)
                    FlSpot(i.toDouble(), line.values[i]),
                ],
                isCurved: true,
                color: line.color,
                barWidth: 2.5,
                dotData: FlDotData(
                  getDotPainter: (spot, percent, bar, index) =>
                      FlDotCirclePainter(
                    radius: 4,
                    color: line.color,
                    strokeWidth: 0,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: line.color.withValues(alpha: 0.07),
                ),
              ),
          ],
        ),
      ),
    );
  }

  FlTitlesData _titles(List<String> dates) {
    final style = TextStyle(fontSize: 10, color: _muted);
    return FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          // Çok noktada etiketler üst üste binmesin.
          interval: dates.length > 8 ? (dates.length / 6).ceilToDouble() : 1,
          getTitlesWidget: (value, meta) {
            final i = value.toInt();
            if (i < 0 || i >= dates.length) return const SizedBox();
            final p = dates[i].split('-');
            return Text('${p[2]}/${p[1]}', style: style);
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          getTitlesWidget: (value, meta) =>
              Text(value.toInt().toString(), style: style),
        ),
      ),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  Widget _legend(Color color, String label) => Row(children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ]);

  Widget _sectionTitle(String title) => Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: _muted,
        ),
      );

  Widget _emptyCard(String message, String key) => _card(
        child: Center(
          key: ValueKey(key),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppColors.primary50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bar_chart,
                      color: AppColors.primary400, size: 24),
                ),
                const SizedBox(height: 10),
                Text(message,
                    style: TextStyle(fontSize: 13, color: _muted),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isDark ? const Color(0xFF1A1825) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.07),
            width: 0.5,
          ),
        ),
        child: child,
      );
}

/// Grafikte tek çizgi: renk ve noktalar (gün sırasıyla).
class _Line {
  const _Line(this.color, this.values);

  final Color color;
  final List<double> values;
}
