// "Boy ve kilo" ekranı: boy (güncel değer), kilo (tarihli kayıtlar, grafik ve
// geçmiş). Veri yalnızca bu telefondaki şifreli veritabanındadır. VKİ gibi
// yorum içeren değerler gösterilmez.

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/support.dart';
import '../../domain/errors.dart';
import '../../domain/services/body_measurement_service.dart';
import '../../l10n/l10n.dart';
import 'unsaved_guard.dart';

/// Grafikte gösterilen en son kayıt sayısı.
const _chartPoints = 60;

/// Grafiğin noktaları: en yeni [_chartPoints] kayıt, eskiden yeniye.
/// [newestFirst] en yeni önce sıralı olmalıdır.
@visibleForTesting
List<Measurement> chartSeries(List<Measurement> newestFirst) =>
    newestFirst.take(_chartPoints).toList().reversed.toList();

class BodyMeasurementsScreen extends ConsumerStatefulWidget {
  const BodyMeasurementsScreen({super.key});

  @override
  ConsumerState<BodyMeasurementsScreen> createState() =>
      _BodyMeasurementsScreenState();
}

class _BodyMeasurementsScreenState
    extends ConsumerState<BodyMeasurementsScreen> {
  final _height = TextEditingController();
  final _weight = TextEditingController();

  bool _heightLoaded = false;

  /// Yüklendiği andaki boy alanı metni; null = henüz yüklenmedi.
  String? _initialHeight;
  bool _busy = false;
  String? _heightError;
  String? _weightError;

  /// Seçilen kilo günü ('YYYY-MM-DD'); null = bugün.
  String? _day;

  @override
  void dispose() {
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  BodyMeasurementService get _service =>
      ref.read(bodyMeasurementServiceProvider);

  /// Virgül ya da nokta; boş ya da sayı değilse null.
  double? _parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  String _plain(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  String _errorText(Object error) {
    final l10n = context.l10n;
    if (error is RuleViolation) {
      return switch (error.code) {
        RuleCodes.heightOutOfRange => l10n.bodyErrHeight,
        RuleCodes.weightOutOfRange => l10n.bodyErrWeight,
        RuleCodes.measurementDayInvalid ||
        RuleCodes.measurementDayInFuture => l10n.bodyErrDay,
        _ => l10n.bodyErrGeneric,
      };
    }
    return l10n.bodyErrGeneric;
  }

  Future<void> _saveHeight() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final value = _parse(_height.text);
    if (value == null) {
      setState(() => _heightError = l10n.bodyErrNumber);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _heightError = null;
    });
    try {
      await _service.saveHeight(value);
    } catch (e) {
      debugPrint('Boy kaydedilemedi: ${e.runtimeType}');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _heightError = _errorText(e);
      });
      return;
    }
    ref.invalidate(bodyMeasurementsProvider);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _initialHeight = _height.text;
    });
    messenger.showSnackBar(SnackBar(content: Text(l10n.bodyHeightSaved)));
  }

  Future<void> _clearHeight() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.bodyHeightClearTitle),
        content: Text(l10n.bodyHeightClearBody),
        actions: [
          TextButton(
            key: const Key('vucut_boy_sil_vazgec'),
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            key: const Key('vucut_boy_sil_onay'),
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.bodyDeleteAction),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _service.clearHeight();
    } catch (e) {
      debugPrint('Boy silinemedi: ${e.runtimeType}');
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.bodyErrGeneric)));
      return;
    }
    ref.invalidate(bodyMeasurementsProvider);
    if (!mounted) return;
    setState(() {
      _height.clear();
      _initialHeight = '';
      _heightError = null;
    });
    messenger.showSnackBar(SnackBar(content: Text(l10n.bodyHeightCleared)));
  }

  /// Kaydedilmemiş değişiklik var mı: boy metni değişti, kilo yazıldı ya da gün seçildi.
  bool get _dirty =>
      _initialHeight != null &&
      (_height.text != _initialHeight ||
          _weight.text.isNotEmpty ||
          _day != null);

  Future<void> _addWeight() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final value = _parse(_weight.text);
    if (value == null) {
      setState(() => _weightError = l10n.bodyErrNumber);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _weightError = null;
    });
    try {
      await _service.addWeight(kg: value, day: _day);
    } catch (e) {
      debugPrint('Kilo kaydedilemedi: ${e.runtimeType}');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _weightError = _errorText(e);
      });
      return;
    }
    ref.invalidate(bodyMeasurementsProvider);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _weight.clear();
      _day = null;
    });
    messenger.showSnackBar(SnackBar(content: Text(l10n.bodyWeightAdded)));
  }

  Future<void> _pickDay() async {
    final now = ref.read(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final current = _day == null ? today : _dayToDate(_day!);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(BodyMeasurementService.minYear),
      lastDate: today,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _day = dayKey(picked);
      _weightError = null;
    });
  }

  DateTime _dayToDate(String day) {
    final p = day.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  Future<void> _delete(Measurement m) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.bodyDeleteTitle),
        content: Text(l10n.bodyDeleteBody),
        actions: [
          TextButton(
            key: const Key('vucut_sil_vazgec'),
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            key: const Key('vucut_sil_onay'),
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.bodyDeleteAction),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _service.deleteWeight(m.id);
    } catch (e) {
      debugPrint('Kilo silinemedi: ${e.runtimeType}');
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.bodyErrGeneric)));
      return;
    }
    ref.invalidate(bodyMeasurementsProvider);
    messenger.showSnackBar(SnackBar(content: Text(l10n.bodyDeleted)));
  }

  // ------------------------------------------------------------------ görünüm

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final data = ref.watch(bodyMeasurementsProvider);

    Widget body = data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.bodyLoadFailed, key: const Key('vucut_okunamadi')),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('vucut_tekrar'),
                onPressed: () => ref.invalidate(bodyMeasurementsProvider),
                child: Text(l10n.profileRetry),
              ),
            ],
          ),
        ),
      ),
      data: _content,
    );

    // Metin alanları değişince koruma yeniden hesaplanır.
    return ListenableBuilder(
      listenable: Listenable.merge([_height, _weight]),
      builder: (context, _) => UnsavedChangesGuard(
        dirty: _dirty,
        child: Scaffold(
          appBar: AppBar(title: Text(l10n.bodyTitle)),
          body: SafeArea(child: body),
        ),
      ),
    );
  }

  Widget _content(BodyMeasurements d) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final number = NumberFormat('0.#', locale);
    final dateFormat = DateFormat('d MMMM y', locale);

    // Boy alanı ilk yüklemede güncel değerle dolar; sonra kullanıcının yazdığına dokunulmaz.
    if (!_heightLoaded) {
      _heightLoaded = true;
      final h = d.height;
      if (h != null) _height.text = _plain(h.value);
      _initialHeight = _height.text;
    }

    final dayLabel = _day == null
        ? l10n.bodyToday
        : dateFormat.format(_dayToDate(_day!));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.bodyHeightSection, style: text.titleSmall),
        const SizedBox(height: 8),
        TextField(
          key: const Key('vucut_boy'),
          controller: _height,
          enabled: !_busy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: l10n.bodyHeightLabel,
            errorText: _heightError,
          ),
          onChanged: (_) {
            if (_heightError != null) setState(() => _heightError = null);
          },
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          key: const Key('vucut_boy_kaydet'),
          onPressed: _busy ? null : _saveHeight,
          child: Text(l10n.bodyHeightSave),
        ),
        if (d.height != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('vucut_boy_temizle'),
              onPressed: _busy ? null : _clearHeight,
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              child: Text(l10n.bodyHeightClear),
            ),
          ),
        const SizedBox(height: 24),
        Text(l10n.bodyWeightSection, style: text.titleSmall),
        const SizedBox(height: 8),
        TextField(
          key: const Key('vucut_kilo'),
          controller: _weight,
          enabled: !_busy,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: l10n.bodyWeightLabel,
            errorText: _weightError,
          ),
          onChanged: (_) {
            if (_weightError != null) setState(() => _weightError = null);
          },
        ),
        const SizedBox(height: 12),
        InkWell(
          key: const Key('vucut_tarih'),
          onTap: _busy ? null : _pickDay,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: l10n.bodyWeightDate,
              suffixIcon: const Icon(Icons.calendar_today_outlined),
            ),
            child: Text(dayLabel, key: const Key('vucut_tarih_deger')),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          key: const Key('vucut_kilo_ekle'),
          onPressed: _busy ? null : _addWeight,
          child: Text(l10n.bodyWeightAdd),
        ),
        const SizedBox(height: 24),
        Text(l10n.bodyChartTitle, style: text.titleSmall),
        const SizedBox(height: 8),
        if (d.weights.length < 2)
          Text(
            l10n.bodyChartNeedMore,
            key: const Key('vucut_grafik_bos'),
            style: text.bodyMedium,
          )
        else
          _chart(d.weights, scheme),
        const SizedBox(height: 24),
        Text(l10n.bodyHistoryTitle, style: text.titleSmall),
        const SizedBox(height: 8),
        if (d.weights.isEmpty)
          Text(
            l10n.bodyHistoryEmpty,
            key: const Key('vucut_gecmis_bos'),
            style: text.bodyMedium,
          )
        else
          for (final m in d.weights)
            Card(
              key: Key('vucut_kayit_${m.id}'),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text('${number.format(m.value)} kg'),
                subtitle: Text(dateFormat.format(_dayToDate(m.logDate))),
                trailing: IconButton(
                  key: Key('vucut_sil_${m.id}'),
                  tooltip: l10n.bodyDeleteAction,
                  icon: Icon(Icons.delete_outline, color: scheme.error),
                  onPressed: _busy ? null : () => _delete(m),
                ),
              ),
            ),
      ],
    );
  }

  /// Kilo çizgisi: en yeni [_chartPoints] kayıt, eskiden yeniye.
  Widget _chart(List<Measurement> newestFirst, ColorScheme scheme) {
    final recent = chartSeries(newestFirst);
    final values = recent.map((m) => m.value).toList();
    final minY = (values.reduce(math.min) - 1).floorToDouble();
    final maxY = (values.reduce(math.max) + 1).ceilToDouble();
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    final style = TextStyle(fontSize: 10, color: muted);
    final grid = scheme.onSurface.withValues(alpha: 0.07);
    final labels = recent.map((m) => m.logDate).toList();

    // Sağdaki son tarih etiketi ekran kenarında kırpılmasın.
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: SizedBox(
        key: const Key('vucut_grafik'),
        height: 200,
        child: LineChart(
          LineChartData(
            minY: minY,
            maxY: maxY,
            gridData: FlGridData(
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: grid, strokeWidth: 0.5),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 34,
                  getTitlesWidget: (value, meta) =>
                      Text(value.toInt().toString(), style: style),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: labels.length > 8
                      ? (labels.length / 5).ceilToDouble()
                      : 1,
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
              LineChartBarData(
                spots: [
                  for (var i = 0; i < values.length; i++)
                    FlSpot(i.toDouble(), values[i]),
                ],
                isCurved: false,
                color: scheme.primary,
                barWidth: 2.5,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  color: scheme.primary.withValues(alpha: 0.08),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
