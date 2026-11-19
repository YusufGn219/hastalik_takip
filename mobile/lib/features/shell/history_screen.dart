// Geçmiş sekmesi: üstte "Gün / Eğilimler" ayracı. Gün = zaman çizelgesi, Eğilimler =
// analiz ekranı; ikisi de mevcut ekranlardır, burada yalnız gömülü gösterilir.

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../analytics/screens/analytics_dashboard_screen.dart';
import '../timeline/screens/day_timeline_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _segment = 0;
  bool _trendsVisited = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.shellTabHistory,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: SegmentedButton<int>(
                key: const Key('gecmis_ayrac'),
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(minimumSize: const Size(0, 44)),
                segments: [
                  ButtonSegment(value: 0, label: Text(l10n.historySegmentDay)),
                  ButtonSegment(value: 1, label: Text(l10n.historySegmentTrends)),
                ],
                selected: {_segment},
                onSelectionChanged: (s) => setState(() {
                  _segment = s.first;
                  if (_segment == 1) _trendsVisited = true;
                }),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _segment,
                children: [
                  const DayTimelineScreen(embedded: true),
                  // Eğilimler ilk açılışta kurulur (analiz verisi gerekmedikçe okunmasın).
                  _trendsVisited
                      ? const AnalyticsDashboardScreen(embedded: true)
                      : const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
