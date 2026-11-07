// Zaman çizelgesi: seçilen günün günlük kaydı, semptom girişleri, ilaç alımları ve
// atlanan dozları zaman sırasıyla gösterir; bugün için süren dönemleri de üstte
// özetler. Yalnız okur; kayıt ekleme ve düzenleme kendi ekranlarındadır.
// Yerel veritabanından TimelineDayLoader ile okur.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/support.dart';
import '../../../domain/local_day.dart';
import '../../../l10n/app_localizations.dart';
import '../../episode/episode_format.dart';
import '../../episode/episode_overview.dart';
import '../timeline_day.dart';

/// 'YYYY-MM-DD' gününü [delta] gün kaydırır (takvim günü; yaz saati etkilemez).
String shiftDay(String day, int delta) {
  final p = day.split('-').map(int.parse).toList();
  final d = DateTime(p[0], p[1], p[2] + delta);
  return formatDay(d.year, d.month, d.day);
}

class DayTimelineScreen extends ConsumerStatefulWidget {
  const DayTimelineScreen({super.key});

  @override
  ConsumerState<DayTimelineScreen> createState() => _DayTimelineScreenState();
}

class _DayTimelineScreenState extends ConsumerState<DayTimelineScreen> {
  late String _today;
  late String _day;
  TimelineDay? _data;
  bool _isLoading = true;
  bool _loadFailed = false;

  /// Hızlı gün değiştirmede geç dönen eski yanıtın ekranı bozmaması için.
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _today = dayKey(ref.read(clockProvider)());
    _day = _today;
    _load();
  }

  bool get _isToday => _day == _today;

  Future<void> _load({bool showSpinner = true}) async {
    final id = ++_requestId;
    if (showSpinner) setState(() => _isLoading = true);
    try {
      final data = await ref
          .read(timelineDayLoaderProvider)
          .load(_day, withActiveEpisodes: _isToday);
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

  void _goTo(String day) {
    // Gün değişince "bugün" de yenilenir (ekran gece yarısını aşıp açık kalabilir).
    // Gelecek güne geçiş yok: ileri düğmesi bugünde kapalıdır.
    _today = dayKey(ref.read(clockProvider)());
    setState(() => _day = day);
    _load();
  }

  Future<void> _open(String route) async {
    await Navigator.of(context).pushNamed(route);
    if (!mounted) return;
    await _load(showSpinner: false);
  }

  String _dayTitle(AppLocalizations l10n) {
    final p = _day.split('-').map(int.parse).toList();
    final text = DateFormat('d MMMM y, EEEE', Localizations.localeOf(context).toString())
        .format(DateTime(p[0], p[1], p[2]));
    return _isToday ? '${l10n.timelineToday} · $text' : text;
  }

  /// Kaydın kendi UTC farkıyla saat ("08:30").
  String _hm(DateTime instant, int offsetMinutes) => DateFormat.Hm(
        Localizations.localeOf(context).toString(),
      ).format(instant.toUtc().add(Duration(minutes: offsetMinutes)));

  String _number(num value) =>
      NumberFormat.decimalPattern(Localizations.localeOf(context).toString())
          .format(value);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.timelineTitle)),
      body: Column(
        children: [
          _dayBar(l10n),
          Expanded(child: _body(l10n)),
        ],
      ),
    );
  }

  Widget _dayBar(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('timeline-prev'),
            tooltip: l10n.timelinePrevDay,
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _goTo(shiftDay(_day, -1)),
          ),
          Expanded(
            child: Text(
              _dayTitle(l10n),
              key: const ValueKey('timeline-day-title'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          if (!_isToday)
            IconButton(
              key: const ValueKey('timeline-today'),
              tooltip: l10n.timelineGoToday,
              icon: const Icon(Icons.today),
              onPressed: () => _goTo(_today),
            ),
          IconButton(
            key: const ValueKey('timeline-next'),
            tooltip: l10n.timelineNextDay,
            icon: const Icon(Icons.chevron_right),
            onPressed: _isToday ? null : () => _goTo(shiftDay(_day, 1)),
          ),
        ],
      ),
    );
  }

  Widget _body(AppLocalizations l10n) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final data = _data;
    if (_loadFailed || data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.timelineLoadError,
            key: const ValueKey('timeline-error'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(showSpinner: false),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (data.activeEpisodes.isNotEmpty) ...[
            _heading(l10n.timelineActiveTitle),
            for (final o in data.activeEpisodes) _episodeCard(o, l10n),
            const SizedBox(height: 16),
          ],
          _heading(l10n.timelineDailyTitle),
          _dailyLogCard(data, l10n),
          const SizedBox(height: 16),
          _heading(l10n.timelineEventsTitle),
          if (data.items.isEmpty)
            Text(
              l10n.timelineEventsEmpty,
              key: const ValueKey('timeline-events-empty'),
              style: const TextStyle(color: Colors.grey),
            )
          else
            for (final item in data.items) _itemCard(item, l10n),
        ],
      ),
    );
  }

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      );

  Widget _episodeCard(EpisodeOverview o, AppLocalizations l10n) {
    final e = o.episode;
    final now = ref.read(clockProvider)();
    final locale = Localizations.localeOf(context).toString();
    return Card(
      key: ValueKey('timeline-episode-${e.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.timeline, color: AppColors.episode),
        title: Text(o.symptomName),
        subtitle: Text(
          '${l10n.episodeStart(formatEpisodeMoment(e.startTime, e.startUtcOffsetMinutes, now, locale))}'
          ' · ${l10n.episodeSeverity(o.lastSeverity?.toString() ?? '-')}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _open('/episodes'),
      ),
    );
  }

  Widget _dailyLogCard(TimelineDay data, AppLocalizations l10n) {
    final log = data.dailyLog;
    if (log == null) {
      return Card(
        key: const ValueKey('timeline-daily-empty'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.timelineNoDailyLog,
                  style: const TextStyle(color: Colors.grey)),
              // Günlük kayıt ekranı bugünü düzenler; geçmiş güne düğme konmaz.
              if (_isToday) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const ValueKey('timeline-add-daily'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () => _open('/daily-log'),
                  child: Text(l10n.timelineAddDailyLog),
                ),
              ],
            ],
          ),
        ),
      );
    }
    final notes = log.notes;
    return Card(
      key: const ValueKey('timeline-daily'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.timelineSleep(_number(log.sleepHours))),
            Text(l10n.timelineWater(_number(log.waterIntake))),
            Text(l10n.timelineMood(log.mood)),
            Text(l10n.timelineEnergy(log.energyLevel)),
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(notes, style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
            if (_isToday) ...[
              const SizedBox(height: 8),
              TextButton(
                key: const ValueKey('timeline-edit-daily'),
                onPressed: () => _open('/daily-log'),
                child: Text(l10n.homeDailyLog),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _itemCard(TimelineItem item, AppLocalizations l10n) {
    final time = _hm(item.instant, item.offsetMinutes);
    final IconData icon;
    final Color color;
    final String title;
    final String? subtitle;
    switch (item) {
      case SymptomTimelineItem():
        icon = Icons.healing;
        color = AppColors.symptom;
        title = l10n.timelineSymptomLine(item.symptomName, item.entry.severity);
        subtitle = item.entry.notes.isEmpty ? null : item.entry.notes;
      case IntakeTimelineItem():
        icon = Icons.medication;
        color = AppColors.medication;
        final amount = item.log.doseAmount;
        title = amount == null
            ? l10n.timelineIntakeLine(item.medicationName)
            : l10n.timelineIntakeDoseLine(
                item.medicationName,
                '${_number(amount)} ${doseUnitLabel(item.log.doseUnit, l10n)}',
              );
        subtitle = item.scheduledTime == null
            ? null
            : l10n.timelineScheduledDose(item.scheduledTime!);
      case SkipTimelineItem():
        icon = Icons.do_not_disturb_on_outlined;
        color = Colors.orange;
        title = l10n.timelineSkippedLine(item.medicationName);
        subtitle = l10n.timelineScheduledDose(item.scheduledTime);
    }
    return Card(
      key: ValueKey('timeline-item-${item.runtimeType}-$time-${title.hashCode}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: Text(time, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
