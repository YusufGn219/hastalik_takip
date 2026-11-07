// Rutin ilaçlar: bugünün dozları (alındı / atlandı / kaydedilmedi, "Aldım" ve
// "Atladım"), tüm rutinler (kullanıcının bağladığı kronik hastalığa göre gruplu),
// rutin ekleme (birden fazla doz saati) ve kapatma. Yerel veritabanına
// MedicationService ve DoseService üzerinden yazar. Hatırlatma bildirimi bu
// ekranda planlanmaz (Sprint 4 Grup 3).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/utils/turkish_text.dart';
import '../../../data/database/app_database.dart';
import '../../../domain/errors.dart';
import '../../../domain/services/dose_service.dart';
import '../../../domain/services/medication_service.dart';
import '../../../domain/weekdays.dart';
import '../../../l10n/app_localizations.dart';

/// Gün anahtarının kısa Türkçe adı ("monday" → "Pzt").
String weekdayShortLabel(String key, AppLocalizations l10n) {
  switch (key) {
    case 'monday':
      return l10n.dayMonShort;
    case 'tuesday':
      return l10n.dayTueShort;
    case 'wednesday':
      return l10n.dayWedShort;
    case 'thursday':
      return l10n.dayThuShort;
    case 'friday':
      return l10n.dayFriShort;
    case 'saturday':
      return l10n.daySatShort;
    default:
      return l10n.daySunShort;
  }
}

/// "Her gün" ya da "Pzt, Çar, Cum".
String routineDaysText(List<String> days, AppLocalizations l10n) {
  if (days.length == weekdayKeys.length) return l10n.routineEveryDay;
  return days.map((d) => weekdayShortLabel(d, l10n)).join(', ');
}

/// Hata kodunu kullanıcıya gösterilecek metne çevirir.
String routineErrorText(Object error, AppLocalizations l10n) {
  if (error is RuleViolation) {
    switch (error.code) {
      case RuleCodes.routineTimeInvalid:
        return l10n.routineErrorTime;
      case RuleCodes.routineTimesEmpty:
        return l10n.routineErrorTimes;
      case RuleCodes.routineTooManyTimes:
        return l10n.routineErrorTooManyTimes;
      case RuleCodes.routineDaysEmpty:
      case RuleCodes.invalidRecurringDay:
        return l10n.routineErrorDays;
      case RuleCodes.medicationNotFound:
        return l10n.routineErrorMedication;
      case RuleCodes.doseAlreadyTaken:
        return l10n.routineErrorDoseTaken;
      case RuleCodes.doseAlreadySkipped:
        return l10n.routineErrorDoseSkipped;
      case RuleCodes.doseNotScheduled:
        return l10n.routineErrorDoseNotScheduled;
    }
  }
  return l10n.routineErrorGeneric;
}

/// Pencerede ilaç seçilmeden Kaydet'e basıldığını işaretler (serviste hata yok).
const Object _noMedicationChosen = 'ilac-secilmedi';

String _hhmm(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay _parseHhmm(String s) => TimeOfDay(
      hour: int.parse(s.substring(0, 2)),
      minute: int.parse(s.substring(3, 5)),
    );

class RecurringScreen extends ConsumerStatefulWidget {
  const RecurringScreen({super.key});

  @override
  ConsumerState<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends ConsumerState<RecurringScreen> {
  List<Dose> _doses = [];
  List<RoutineGroup> _groups = [];
  List<Medication> _freeMedications = [];
  bool _isLoading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final service = ref.read(medicationServiceProvider);
      final doseService = ref.read(doseServiceProvider);
      final all = await service.routines();
      final groups = await service.routineGroups();
      final doses = await doseService.dosesForDay(doseService.today());
      final withRoutine = {for (final r in all) r.medication.id};
      final free = (await service.available())
          .where((m) => !withRoutine.contains(m.id))
          .toList()
        ..sort((a, b) => compareTr(a.name, b.name));
      if (!mounted) return;
      setState(() {
        _doses = doses;
        _groups = groups;
        _freeMedications = free;
        _loadFailed = false;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadFailed = true;
        _isLoading = false;
      });
    }
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Colors.red : Colors.green,
    ));
  }

  Future<void> _showAddDialog() async {
    final l10n = AppLocalizations.of(context);
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _RoutineDialog(medications: _freeMedications),
    );
    if (saved != true || !mounted) return;
    _snack(l10n.routineAdded);
    await _load();
  }

  Future<void> _confirmClose(Routine r) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.routineCloseTitle),
        content: Text(l10n.routineCloseBody(r.medication.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.routineCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.routineCloseConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(medicationServiceProvider).clearRoutine(r.medication.id);
      if (!mounted) return;
      _snack(l10n.routineClosed);
    } catch (e) {
      if (!mounted) return;
      _snack(routineErrorText(e, l10n), error: true);
    }
    await _load();
  }

  Future<void> _take(Dose d) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(doseServiceProvider)
          .markTaken(medicationId: d.medication.id, time: d.time);
      if (!mounted) return;
      _snack(l10n.routineTakenSaved(d.medication.name));
    } catch (e) {
      if (!mounted) return;
      _snack(routineErrorText(e, l10n), error: true);
    }
    // Hata olsa da durum değişmiş olabilir (ör. başka yerden kaydedilmiş).
    await _load();
  }

  Future<void> _skip(Dose d) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(doseServiceProvider)
          .markSkipped(medicationId: d.medication.id, time: d.time);
      if (!mounted) return;
      _snack(l10n.routineSkippedSaved(d.medication.name));
    } catch (e) {
      if (!mounted) return;
      _snack(routineErrorText(e, l10n), error: true);
    }
    await _load();
  }

  /// Doz saati şimdiye geldi ya da geçti mi (cihazın yerel saatine göre).
  bool _isDue(String time) {
    final now = ref.read(clockProvider)();
    final t = _parseHhmm(time);
    return now.hour * 60 + now.minute >= t.hour * 60 + t.minute;
  }

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      );

  Widget _subtitle(Routine r, AppLocalizations l10n) {
    final days = routineDaysText(r.days, l10n);
    final times = r.times.join(', ');
    return Text(times.isEmpty ? days : '$times · $days');
  }

  Widget _doseCard(Dose d, AppLocalizations l10n) {
    final String label;
    final Color color;
    switch (d.state) {
      case DoseState.taken:
        label = '${l10n.routineStateTaken} ✓';
        color = Colors.green;
      case DoseState.skipped:
        label = l10n.routineStateSkipped;
        color = Colors.orange;
      case DoseState.pending:
        final due = _isDue(d.time);
        label = due ? l10n.routineStateUnrecorded : l10n.routineStateWaiting;
        color = due ? Colors.redAccent : Colors.grey;
    }
    final id = '${d.medication.id}-${d.time}';
    return Card(
      key: ValueKey('dose-$id'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.medication),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.medication.name,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${d.time} · $label',
                        key: ValueKey('dose-state-$id'),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (d.state != DoseState.taken) ...[
              const SizedBox(height: 8),
              // Düğmeler Expanded içinde: tema tam genişlik ister.
              Row(
                children: [
                  if (d.state == DoseState.pending) ...[
                    Expanded(
                      child: OutlinedButton(
                        key: ValueKey('skip-$id'),
                        onPressed: () => _skip(d),
                        child: Text(l10n.routineSkip),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      key: ValueKey('take-$id'),
                      onPressed: () => _take(d),
                      child: Text(l10n.routineTaken),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.routineTitle),
        actions: [
          IconButton(
            tooltip: l10n.routineAddTooltip,
            icon: const Icon(Icons.add),
            onPressed: (_isLoading || _loadFailed) ? null : _showAddDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadFailed
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.routineLoadError,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _heading(l10n.routineTodayTitle),
                    if (_doses.isEmpty)
                      Text(l10n.routineTodayEmpty,
                          style: const TextStyle(color: Colors.grey))
                    else
                      for (final d in _doses) _doseCard(d, l10n),
                    const SizedBox(height: 24),
                    _heading(l10n.routineAllTitle),
                    if (_groups.isEmpty)
                      Text(l10n.routineAllEmpty,
                          style: const TextStyle(color: Colors.grey)),
                    for (final g in _groups) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Text(
                          g.condition?.name ?? l10n.routineOtherGroup,
                          key: ValueKey('group-${g.condition?.id ?? 'other'}'),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      for (final r in g.routines)
                        Card(
                          key: ValueKey(
                              'routine-${g.condition?.id ?? 'other'}-${r.medication.id}'),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.repeat),
                            title: Text(r.medication.name),
                            subtitle: _subtitle(r, l10n),
                            trailing: IconButton(
                              tooltip: l10n.routineCloseTooltip,
                              icon: const Icon(Icons.alarm_off),
                              onPressed: () => _confirmClose(r),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
    );
  }
}

/// Rutin ekleme penceresi. Kaydı kendisi yapar; başarıda true ile kapanır, hata
/// olursa açık kalır ve mesajı pencerenin en üstünde gösterir.
class _RoutineDialog extends ConsumerStatefulWidget {
  const _RoutineDialog({required this.medications});

  final List<Medication> medications;

  @override
  ConsumerState<_RoutineDialog> createState() => _RoutineDialogState();
}

class _RoutineDialogState extends ConsumerState<_RoutineDialog> {
  String? _medicationId;
  final Set<String> _times = {'08:00'};
  final Set<String> _days = {};
  Object? _error;
  bool _saving = false;

  List<String> get _sortedTimes => _times.toList()..sort();

  /// Yeni saat için seçici, son saatten bir saat sonrasını önerir.
  Future<void> _addTime() async {
    final last = _sortedTimes.isEmpty
        ? const TimeOfDay(hour: 7, minute: 0)
        : _parseHhmm(_sortedTimes.last);
    final initial = TimeOfDay(
      hour: last.hour < 23 ? last.hour + 1 : 23,
      minute: last.minute,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        _times.add(_hhmm(picked));
        _error = null;
      });
    }
  }

  Future<void> _save() async {
    if (_medicationId == null) {
      setState(() => _error = _noMedicationChosen);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(medicationServiceProvider).setRoutine(
            medicationId: _medicationId!,
            times: _sortedTimes,
            days: _days.toList(),
          );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final noMeds = widget.medications.isEmpty;
    return AlertDialog(
      title: Text(l10n.routineNewTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  identical(_error, _noMedicationChosen)
                      ? l10n.routineErrorNoMed
                      : routineErrorText(_error!, l10n),
                  key: const ValueKey('routine-dialog-error'),
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (noMeds)
              Text(l10n.routineNoMedsAvailable)
            else
              DropdownButtonFormField<String>(
                key: const ValueKey('routine-med'),
                isExpanded: true,
                initialValue: _medicationId,
                hint: Text(l10n.routineMedHint),
                items: [
                  for (final m in widget.medications)
                    DropdownMenuItem(value: m.id, child: Text(m.name)),
                ],
                onChanged: _saving
                    ? null
                    : (v) => setState(() {
                          _medicationId = v;
                          _error = null;
                        }),
                decoration: InputDecoration(
                  labelText: l10n.routineMedLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 16),
            Text(l10n.routineTimesLabel),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in _sortedTimes)
                  InputChip(
                    key: ValueKey('time-$t'),
                    label: Text(t),
                    deleteButtonTooltipMessage: l10n.routineRemoveTime,
                    onDeleted: _saving
                        ? null
                        : () => setState(() {
                              _times.remove(t);
                              _error = null;
                            }),
                  ),
                ActionChip(
                  key: const ValueKey('routine-add-time'),
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(l10n.routineAddTime),
                  onPressed: (_saving ||
                          _times.length >= MedicationService.maxRoutineTimes)
                      ? null
                      : _addTime,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l10n.routineDaysLabel),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final key in weekdayKeys)
                  FilterChip(
                    key: ValueKey('day-$key'),
                    label: Text(weekdayShortLabel(key, l10n)),
                    selected: _days.contains(key),
                    onSelected: _saving
                        ? null
                        : (on) => setState(() {
                              on ? _days.add(key) : _days.remove(key);
                              _error = null;
                            }),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text(l10n.routineCancel),
        ),
        FilledButton(
          onPressed: (_saving || noMeds) ? null : _save,
          child: Text(l10n.routineSave),
        ),
      ],
    );
  }
}
