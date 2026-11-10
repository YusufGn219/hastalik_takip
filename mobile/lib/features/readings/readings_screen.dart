// "Sağlık ölçümleri" ekranı: tür seçimi (tansiyon / nabız / kan şekeri), son
// ölçüm, grafik, geçmiş, ekleme-düzenleme-silme ve (şekerde) gösterim birimi.
// İnce bir ekrandır: kurallar `ReadingService`'te, katalog `ReadingCatalog`'ta.
// Renkler yalnızca tema renk şemasından alınır. "Normal / yüksek" gibi yorum
// gösterilmez.

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../data/database/app_database.dart';
import '../../domain/reading_catalog.dart';
import '../../l10n/l10n.dart';
import 'reading_edit_sheet.dart';
import 'reading_format.dart';
import 'readings_view.dart';

/// Grafikte gösterilen en son ölçüm sayısı.
const _chartPoints = 60;

class ReadingsScreen extends ConsumerStatefulWidget {
  const ReadingsScreen({super.key});

  @override
  ConsumerState<ReadingsScreen> createState() => _ReadingsScreenState();
}

class _ReadingsScreenState extends ConsumerState<ReadingsScreen> {
  String _type = ReadingCatalog.all.first.type;

  ReadingKind get _kind => ReadingCatalog.of(_type)!;

  Future<void> _setUnit(String code) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = SnackBar(content: Text(context.l10n.readingErrGeneric));
    try {
      await ref.read(readingServiceProvider).setPreferredUnit(_type, code);
    } catch (e) {
      debugPrint('Birim kaydedilemedi: ${e.runtimeType}');
      messenger.showSnackBar(failed);
      return;
    }
    ref.invalidate(readingsViewProvider(_type));
  }

  Future<void> _openSheet(ReadingsView view, {Measurement? existing}) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = context.l10n.readingSaved;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ReadingEditSheet(kind: _kind, unit: view.unit, existing: existing),
    );
    if (ok != true || !mounted) return;
    ref.invalidate(readingsViewProvider(_type));
    messenger.showSnackBar(SnackBar(content: Text(saved)));
  }

  Future<void> _delete(Measurement m) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.readingDeleteTitle),
        content: Text(l10n.readingDeleteBody),
        actions: [
          TextButton(
            key: const Key('olcum_sil_vazgec'),
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            key: const Key('olcum_sil_onay'),
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            child: Text(l10n.readingDeleteAction),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(readingServiceProvider).delete(m.id);
    } catch (e) {
      debugPrint('Ölçüm silinemedi: ${e.runtimeType}');
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.readingErrGeneric)));
      return;
    }
    ref.invalidate(readingsViewProvider(_type));
    messenger.showSnackBar(SnackBar(content: Text(l10n.readingDeleted)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final data = ref.watch(readingsViewProvider(_type));
    final view = data.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.readingsTitle)),
      floatingActionButton: view == null
          ? null
          : FloatingActionButton.extended(
              key: const Key('olcum_ekle'),
              onPressed: () => _openSheet(view),
              icon: const Icon(Icons.add),
              label: Text(l10n.readingAdd),
            ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final kind in ReadingCatalog.all)
                  ChoiceChip(
                    key: Key('olcum_tur_${kind.type}'),
                    label: Text(readingTypeName(l10n, kind.type)),
                    selected: kind.type == _type,
                    onSelected: (_) => setState(() => _type = kind.type),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            data.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Column(
                children: [
                  Text(l10n.readingLoadFailed, key: const Key('olcum_okunamadi')),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    key: const Key('olcum_tekrar'),
                    onPressed: () => ref.invalidate(readingsViewProvider(_type)),
                    child: Text(l10n.profileRetry),
                  ),
                ],
              ),
              data: _content,
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(ReadingsView d) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final kind = _kind;
    final dateFormat = DateFormat('d MMMM y', locale);

    String valueText(Measurement m) =>
        '${formatReadingValue(kind, m, d.unit, locale)} ${d.unit}';
    String whenText(Measurement m) {
      final base = '${dateFormat.format(readingDay(m.logDate))} · ${readingClock(m, locale)}';
      final c = m.context;
      return c == null ? base : '$base · ${readingContextName(l10n, c)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (kind.units.length > 1) ...[
          Text(l10n.readingUnitTitle, style: text.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final u in kind.units)
                ChoiceChip(
                  key: Key('olcum_ekran_birim_${u.code}'),
                  label: Text(u.code),
                  selected: u.code == d.unit,
                  onSelected: (_) => _setUnit(u.code),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (d.items.isEmpty)
          Text(l10n.readingEmpty, key: const Key('olcum_bos'), style: text.bodyMedium)
        else ...[
          Card(
            key: const Key('olcum_son'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.readingLatest, style: text.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    valueText(d.items.first),
                    key: const Key('olcum_son_deger'),
                    style: text.headlineSmall,
                  ),
                  Text(whenText(d.items.first), style: text.bodySmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(l10n.readingChartTitle, style: text.titleSmall),
          const SizedBox(height: 8),
          if (d.items.length < 2)
            Text(l10n.readingChartNeedMore, key: const Key('olcum_grafik_bos'), style: text.bodyMedium)
          else
            _chart(kind, d, scheme),
          const SizedBox(height: 16),
          Text(l10n.readingHistoryTitle, style: text.titleSmall),
          const SizedBox(height: 8),
          for (final m in d.items)
            Card(
              key: Key('olcum_kayit_${m.id}'),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(valueText(m)),
                subtitle: Text(
                  m.notes == null ? whenText(m) : '${whenText(m)}\n${m.notes}',
                ),
                isThreeLine: m.notes != null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: Key('olcum_duzenle_${m.id}'),
                      tooltip: l10n.readingEditAction,
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _openSheet(d, existing: m),
                    ),
                    IconButton(
                      key: Key('olcum_sil_${m.id}'),
                      tooltip: l10n.readingDeleteAction,
                      icon: Icon(Icons.delete_outline, color: scheme.error),
                      onPressed: () => _delete(m),
                    ),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 8),
        Text(l10n.readingDisclaimer, key: const Key('olcum_uyari'), style: text.bodySmall),
      ],
    );
  }

  /// Çizgi grafik: en yeni [_chartPoints] ölçüm, eskiden yeniye; tansiyonda iki çizgi.
  Widget _chart(ReadingKind kind, ReadingsView d, ColorScheme scheme) {
    final l10n = context.l10n;
    final recent = d.items.take(_chartPoints).toList().reversed.toList();
    final unit = kind.unitOf(d.unit);
    final first = [for (final m in recent) kind.fromBase(m.value, d.unit)];
    final second = kind.hasSecond
        ? [for (final m in recent) kind.fromBase(m.value2 ?? m.value, d.unit)]
        : const <double>[];
    final all = [...first, ...second];
    final lo = all.reduce(math.min);
    final hi = all.reduce(math.max);
    final pad = math.max((hi - lo) * 0.15, unit.decimals > 0 ? 0.5 : 5.0);
    final minY = unit.decimals > 0 ? lo - pad : (lo - pad).floorToDouble();
    final maxY = unit.decimals > 0 ? hi + pad : (hi + pad).ceilToDouble();
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    final style = TextStyle(fontSize: 10, color: muted);
    final grid = scheme.onSurface.withValues(alpha: 0.07);
    final labels = [for (final m in recent) m.logDate];
    final firstColor = scheme.primary;
    final secondColor = scheme.secondary;

    LineChartBarData line(List<double> values, Color color) => LineChartBarData(
      spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
      isCurved: false,
      color: color,
      barWidth: 2.5,
      dotData: const FlDotData(show: true),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (kind.hasSecond)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                _legend(firstColor, l10n.readingLegendSystolic),
                const SizedBox(width: 16),
                _legend(secondColor, l10n.readingLegendDiastolic),
              ],
            ),
          ),
        // Sağdaki son tarih etiketi ekran kenarında kırpılmasın.
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: SizedBox(
            key: const Key('olcum_grafik'),
            height: 200,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(color: grid, strokeWidth: 0.5),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      getTitlesWidget: (value, meta) => Text(
                        value.toStringAsFixed(unit.decimals > 0 ? 1 : 0),
                        style: style,
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: labels.length > 8 ? (labels.length / 5).ceilToDouble() : 1,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= labels.length || value != i.toDouble()) {
                          return const SizedBox();
                        }
                        final p = labels[i].split('-');
                        return Text('${p[2]}/${p[1]}', style: style);
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  line(first, firstColor),
                  if (kind.hasSecond) line(second, secondColor),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _legend(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
