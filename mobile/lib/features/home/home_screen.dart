// Bugün sekmesi: bugünün dozları (Aldım / Atla), semptom kısayolu, günlük kaydın
// dört alanı ve adımlar. Yalnız okur ve mevcut servislere yazar (DoseService);
// veri katmanına dokunmaz. Ekleme için ana kabuğun "+" düğmesi kullanılır.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/support.dart' show dayKey;
import '../../domain/services/dose_service.dart';
import '../../l10n/app_localizations.dart';
import '../medication/screens/recurring_screen.dart' show routineErrorText;
import '../profile/profile_avatar.dart';
import '../timeline/timeline_day.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.refresh});

  /// Dışarıdan "yeniden oku" sinyali (ana kabuk: "+" ile bir şey eklenince ya da
  /// sekmeye dönülünce).
  final Listenable? refresh;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<Dose>? _doses;
  TimelineDay? _today;
  bool _loading = true;
  bool _failed = false;

  /// Hızlı art arda yenilemede geç dönen eski yanıtın ekranı bozmaması için.
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    widget.refresh?.addListener(_onRefresh);
    _load();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refresh != widget.refresh) {
      oldWidget.refresh?.removeListener(_onRefresh);
      widget.refresh?.addListener(_onRefresh);
    }
  }

  @override
  void dispose() {
    widget.refresh?.removeListener(_onRefresh);
    super.dispose();
  }

  void _onRefresh() => _load(showSpinner: false);

  Future<void> _load({bool showSpinner = true}) async {
    final id = ++_requestId;
    if (showSpinner && mounted) setState(() => _loading = true);
    List<Dose>? doses;
    TimelineDay? today;
    var failed = false;
    try {
      final service = ref.read(doseServiceProvider);
      doses = await service.dosesForDay(service.today());
    } catch (_) {
      failed = true;
    }
    try {
      final day = dayKey(ref.read(clockProvider)());
      today = await ref.read(timelineDayLoaderProvider).load(day);
    } catch (_) {
      failed = true;
    }
    if (!mounted || id != _requestId) return;
    setState(() {
      _doses = doses;
      _today = today;
      _failed = failed;
      _loading = false;
    });
  }

  Future<void> _open(String route) async {
    await Navigator.of(context).pushNamed(route);
    if (!mounted) return;
    await _load(showSpinner: false);
  }

  Future<void> _markDose(Dose d, {required bool take}) async {
    final l10n = AppLocalizations.of(context);
    try {
      final service = ref.read(doseServiceProvider);
      if (take) {
        await service.markTaken(medicationId: d.medication.id, time: d.time);
      } else {
        await service.markSkipped(medicationId: d.medication.id, time: d.time);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(routineErrorText(e, l10n))));
    }
    // Hata olsa da durum değişmiş olabilir (ör. başka yerden kaydedilmiş).
    if (!mounted) return;
    await _load(showSpinner: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final dateText = DateFormat('EEEE, d MMMM', locale).format(ref.read(clockProvider)());
    final profile = ref.watch(profileProvider).valueOrNull;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _load(showSpinner: false),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dateText,
                            style: Theme.of(context).textTheme.bodyMedium),
                        Text(
                          l10n.shellTabToday,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('ana_ayarlar'),
                    tooltip: l10n.homeSettings,
                    iconSize: 44,
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).pushNamed('/settings'),
                    icon: ProfileAvatar(photo: profile?.photo, radius: 22),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                if (_failed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      l10n.todayLoadError,
                      key: const Key('bugun_hata'),
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (_doses != null) _dosesSection(l10n),
                const SizedBox(height: 18),
                _feelingSection(l10n),
                const SizedBox(height: 18),
                _dailySection(l10n, locale),
                if (_today?.steps != null) ...[
                  const SizedBox(height: 18),
                  _stepsRow(l10n, locale),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading(String text, {String? trailing}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            if (trailing != null)
              Text(trailing, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );

  Widget _dosesSection(AppLocalizations l10n) {
    final doses = _doses!;
    final taken = doses.where((d) => d.state == DoseState.taken).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          l10n.todayDosesTitle,
          trailing: doses.isEmpty ? null : l10n.todayDosesSummary(taken, doses.length),
        ),
        if (doses.isEmpty)
          Text(l10n.todayDosesEmpty,
              key: const Key('bugun_doz_yok'),
              style: Theme.of(context).textTheme.bodyMedium)
        else
          for (final d in doses) _doseCard(d, l10n),
      ],
    );
  }

  Widget _doseCard(Dose d, AppLocalizations l10n) {
    final key = '${d.medication.id}-${d.time}';
    final Widget action;
    switch (d.state) {
      case DoseState.pending:
        action = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              key: Key('doz_atla_$key'),
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              onPressed: () => _markDose(d, take: false),
              child: Text(l10n.todayDoseSkip),
            ),
            FilledButton(
              key: Key('doz_al_$key'),
              style: FilledButton.styleFrom(minimumSize: const Size(72, 44)),
              onPressed: () => _markDose(d, take: true),
              child: Text(l10n.todayDoseTake),
            ),
          ],
        );
      case DoseState.taken:
        action = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check, color: AppColors.daily, size: 20),
            const SizedBox(width: 4),
            Text(l10n.todayDoseTaken,
                key: Key('doz_alindi_$key'),
                style: const TextStyle(
                    color: AppColors.daily, fontWeight: FontWeight.w600)),
          ],
        );
      case DoseState.skipped:
        action = Text(l10n.todayDoseSkipped,
            key: Key('doz_atlandi_$key'),
            style: Theme.of(context).textTheme.bodyMedium);
    }
    return Card(
      key: Key('doz_$key'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Text(d.time,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.medication)),
            ),
            Expanded(
              child: Text(d.medication.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            action,
          ],
        ),
      ),
    );
  }

  Widget _feelingSection(AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(l10n.todayFeelingTitle),
        OutlinedButton.icon(
          key: const Key('bugun_semptom'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            foregroundColor: AppColors.symptom,
            side: BorderSide(color: AppColors.symptom.withValues(alpha: 0.4)),
            // Koyu temada açık pembe zemin göz alıyordu: şeffaf ton kullanılır.
            backgroundColor: isDark
                ? AppColors.symptom.withValues(alpha: 0.14)
                : AppColors.symptomBg,
          ),
          onPressed: () => _open('/symptoms'),
          icon: const Icon(Icons.healing_outlined),
          label: Text(l10n.todayFeelingAction),
        ),
      ],
    );
  }

  Widget _dailySection(AppLocalizations l10n, String locale) {
    final log = _today?.dailyLog;
    final nf = NumberFormat.decimalPattern(locale);
    final filled = log == null ? 0 : 4;
    final tiles = <(String, String?)>[
      (l10n.todayFieldSleep, log == null ? null : l10n.todayUnitHours(nf.format(log.sleepHours))),
      (l10n.todayFieldWater, log == null ? null : l10n.todayUnitLiters(nf.format(log.waterIntake))),
      (l10n.todayFieldMood, log == null ? null : '${log.mood}/5'),
      (l10n.todayFieldEnergy, log == null ? null : '${log.energyLevel}/5'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(l10n.homeDailyLog, trailing: l10n.todayDailyFilled(filled)),
        Row(
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: _dailyTile(i, tiles[i].$1, tiles[i].$2, l10n)),
            ],
          ],
        ),
      ],
    );
  }

  Widget _dailyTile(int index, String label, String? value, AppLocalizations l10n) {
    final done = value != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Koyu temada dolu kutu açık yeşil zemin yerine şeffaf yeşil ton, metin açık.
    final doneLabel = isDark ? const Color(0xFFB5D98A) : const Color(0xFF3F6A10);
    final doneValue = isDark ? const Color(0xFFDDF0C4) : const Color(0xFF2B4A0A);
    return InkWell(
      key: Key('bugun_gunluk_$index'),
      borderRadius: BorderRadius.circular(14),
      onTap: () => _open('/daily-log'),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: done
              ? (isDark ? AppColors.daily.withValues(alpha: 0.18) : AppColors.dailyBg)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: done
                ? AppColors.daily.withValues(alpha: 0.35)
                : Theme.of(context).dividerColor,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: done ? doneLabel : null)),
            const SizedBox(height: 2),
            Text(
              value ?? l10n.todayDailyAdd,
              style: TextStyle(
                fontSize: 15,
                fontWeight: done ? FontWeight.w600 : FontWeight.w500,
                color: done ? doneValue : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepsRow(AppLocalizations l10n, String locale) {
    final steps = _today!.steps!;
    final total = NumberFormat.decimalPattern(locale).format(steps.totalRounded);
    return Card(
      key: const Key('bugun_adimlar'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.directions_walk, color: AppColors.primary600),
            const SizedBox(width: 10),
            Expanded(
              child: Text(l10n.stepsTitle,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            ),
            Text(total,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            if (steps.hasEstimate) ...[
              const SizedBox(width: 6),
              Text(l10n.todayStepsEstimated,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
