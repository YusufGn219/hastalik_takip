// Kronik hastalıklar: listele, ekle, düzenle (ad + ilaçlar), sil. Yerel
// veritabanına MedicationService üzerinden yazar.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/utils/turkish_text.dart';
import '../../../data/database/app_database.dart';
import '../../../domain/errors.dart';
import '../../../domain/services/medication_service.dart';
import '../../../l10n/app_localizations.dart';

/// Hata kodunu kullanıcıya gösterilecek metne çevirir.
String conditionErrorText(Object error, AppLocalizations l10n) {
  if (error is RuleViolation) {
    switch (error.code) {
      case RuleCodes.conditionNameEmpty:
        return l10n.condErrorEmpty;
      case RuleCodes.conditionNameTooLong:
        return l10n.condErrorTooLong;
      case RuleCodes.conditionNameExists:
        return l10n.condErrorExists;
      case RuleCodes.medicationNotFound:
        return l10n.condErrorMedication;
    }
  }
  return l10n.condErrorGeneric;
}

class ChronicConditionScreen extends ConsumerStatefulWidget {
  const ChronicConditionScreen({super.key});

  @override
  ConsumerState<ChronicConditionScreen> createState() =>
      _ChronicConditionScreenState();
}

class _ChronicConditionScreenState
    extends ConsumerState<ChronicConditionScreen> {
  List<ConditionSummary> _conditions = [];
  List<Medication> _medications = [];
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
      final conditions = await service.conditions();
      final medications = await service.available()
        ..sort((a, b) => compareTr(a.name, b.name));
      if (!mounted) return;
      setState(() {
        _conditions = conditions;
        _medications = medications;
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

  Future<void> _showEditor({ConditionSummary? existing}) async {
    final l10n = AppLocalizations.of(context);
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ConditionDialog(
        existing: existing,
        medications: _medications,
      ),
    );
    if (saved != true || !mounted) return;
    _snack(existing == null ? l10n.condAdded : l10n.condUpdated);
    await _load();
  }

  Future<void> _confirmDelete(ConditionSummary c) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.condDeleteTitle),
        content: Text(l10n.condDeleteBody(c.condition.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.condCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.condDeleteConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(medicationServiceProvider).deleteCondition(c.condition.id);
      if (!mounted) return;
      _snack(l10n.condDeleted);
    } catch (e) {
      if (!mounted) return;
      _snack(conditionErrorText(e, l10n), error: true);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.condTitle),
        actions: [
          IconButton(
            tooltip: l10n.condAddTooltip,
            icon: const Icon(Icons.add),
            onPressed: (_isLoading || _loadFailed) ? null : () => _showEditor(),
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
                      l10n.condLoadError,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              : _conditions.isEmpty
                  ? Center(child: Text(l10n.condEmpty))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _conditions.length,
                      itemBuilder: (ctx, i) {
                        final c = _conditions[i];
                        return Card(
                          key: ValueKey('cond-${c.condition.id}'),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        c.condition.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: l10n.condEditTooltip,
                                      icon: const Icon(Icons.edit, size: 20),
                                      onPressed: () =>
                                          _showEditor(existing: c),
                                    ),
                                    IconButton(
                                      tooltip: l10n.condDeleteTooltip,
                                      icon: const Icon(Icons.delete,
                                          size: 20, color: Colors.red),
                                      onPressed: () => _confirmDelete(c),
                                    ),
                                  ],
                                ),
                                if (c.medications.isEmpty)
                                  Text(
                                    l10n.condNoMeds,
                                    style: const TextStyle(color: Colors.grey),
                                  )
                                else
                                  for (final m in c.medications)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.medication,
                                              size: 16),
                                          const SizedBox(width: 6),
                                          Expanded(child: Text(m.name)),
                                        ],
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

/// Ekleme/düzenleme penceresi. Kaydı kendisi yapar; başarıda true ile kapanır,
/// hata olursa açık kalır ve mesajı pencerede gösterir (yazılanlar korunur).
class _ConditionDialog extends ConsumerStatefulWidget {
  const _ConditionDialog({required this.existing, required this.medications});

  final ConditionSummary? existing;
  final List<Medication> medications;

  @override
  ConsumerState<_ConditionDialog> createState() => _ConditionDialogState();
}

class _ConditionDialogState extends ConsumerState<_ConditionDialog> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.existing?.condition.name ?? '');
  late final Set<String> _selected = {
    for (final m in widget.existing?.medications ?? const <Medication>[]) m.id,
  };
  bool _saving = false;
  Object? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final service = ref.read(medicationServiceProvider);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final existing = widget.existing;
      if (existing == null) {
        await service.createCondition(
          name: _nameController.text,
          medicationIds: _selected.toList(),
        );
      } else {
        await service.updateCondition(
          id: existing.condition.id,
          name: _nameController.text,
          medicationIds: _selected.toList(),
        );
      }
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
    return AlertDialog(
      title: Text(
        widget.existing == null ? l10n.condNewTitle : l10n.condEditTitle,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [LengthLimitingTextInputFormatter(200)],
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(
                labelText: l10n.condNameLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.condMedsLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (widget.medications.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(l10n.condNoMedsAvailable),
              ),
            for (final m in widget.medications)
              CheckboxListTile(
                key: ValueKey('med-${m.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(m.name),
                value: _selected.contains(m.id),
                onChanged: _saving
                    ? null
                    : (val) => setState(() {
                          if (val == true) {
                            _selected.add(m.id);
                          } else {
                            _selected.remove(m.id);
                          }
                          _error = null;
                        }),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  conditionErrorText(_error!, l10n),
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text(l10n.condCancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(l10n.condSave),
        ),
      ],
    );
  }
}
