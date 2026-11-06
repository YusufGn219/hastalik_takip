import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/utils/turkish_text.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/enums.dart';
import '../../../l10n/app_localizations.dart';

/// Devam eden döneme ilaç alımı ekleyen alt pencere. Başarılıysa `true` ile
/// kapanır (liste ekranı bilgi gösterir).
Future<bool?> showEpisodeMedicationSheet(
  BuildContext context, {
  required String episodeId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => EpisodeMedicationSheet(episodeId: episodeId),
  );
}

class EpisodeMedicationSheet extends ConsumerStatefulWidget {
  const EpisodeMedicationSheet({super.key, required this.episodeId});

  final String episodeId;

  @override
  ConsumerState<EpisodeMedicationSheet> createState() =>
      _EpisodeMedicationSheetState();
}

class _EpisodeMedicationSheetState
    extends ConsumerState<EpisodeMedicationSheet> {
  final TextEditingController _doseController = TextEditingController();

  List<Medication> _medications = [];
  String? _selectedId;
  DoseUnit _unit = DoseUnit.tablet;
  bool _loading = true;
  bool _loadFailed = false;
  bool _saving = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _loadMedications();
  }

  @override
  void dispose() {
    _doseController.dispose();
    super.dispose();
  }

  Future<void> _loadMedications() async {
    try {
      final list = await ref.read(medicationServiceProvider).available();
      if (!mounted) return;
      setState(() {
        _medications = [...list]..sort((a, b) => compareTr(a.name, b.name));
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadFailed = true;
        _loading = false;
      });
    }
  }

  String _unitLabel(DoseUnit unit, AppLocalizations l10n) => switch (unit) {
    DoseUnit.tablet => l10n.doseUnitTablet,
    DoseUnit.mg => l10n.doseUnitMg,
    DoseUnit.ml => l10n.doseUnitMl,
    DoseUnit.drop => l10n.doseUnitDrop,
    DoseUnit.capsule => l10n.doseUnitCapsule,
  };

  /// Boş = doz yok (null). Dolu ama sayı değilse ya da 0'dan büyük değilse
  /// `false`. Ondalık virgül kabul edilir.
  ({bool valid, double? amount}) _parseDose() {
    final text = _doseController.text.trim().replaceAll(',', '.');
    if (text.isEmpty) return (valid: true, amount: null);
    final value = double.tryParse(text);
    if (value == null || !value.isFinite || value <= 0) {
      return (valid: false, amount: null);
    }
    return (valid: true, amount: value);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (_selectedId == null) {
      setState(() => _message = l10n.episodeMedicationPick);
      return;
    }
    final dose = _parseDose();
    if (!dose.valid) {
      setState(() => _message = l10n.episodeDoseInvalid);
      return;
    }
    setState(() {
      _saving = true;
      _message = '';
    });
    try {
      await ref
          .read(medicationServiceProvider)
          .logIntake(
            medicationId: _selectedId!,
            takenAt: ref.read(clockProvider)(),
            doseAmount: dose.amount,
            doseUnit: _unit,
            episodeId: widget.episodeId,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = l10n.episodeMedicationSaveFailed;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    // Klavye açıkken geri tuşu önce yalnız klavyeyi kapatır; pencere bir
    // sonraki geri tuşuyla kapanır.
    return PopScope(
      canPop: !keyboardOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.episodeMedicationTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_loadFailed)
                Text(
                  l10n.episodeMedicationLoadError,
                  style: const TextStyle(color: Colors.red),
                )
              else if (_medications.isEmpty)
                Text(l10n.episodeMedicationNone)
              else ...[
                DropdownButtonFormField<String>(
                  hint: Text(l10n.episodeMedicationHint),
                  initialValue: _selectedId,
                  isExpanded: true,
                  items: [
                    for (final m in _medications)
                      DropdownMenuItem<String>(
                        value: m.id,
                        child: Text(m.name),
                      ),
                  ],
                  onChanged: (val) => setState(() {
                    _selectedId = val;
                    _message = ''; // eski uyarı kalmasın
                  }),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _doseController,
                        onChanged: (_) {
                          if (_message.isNotEmpty) {
                            setState(() => _message = '');
                          }
                        },
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: l10n.episodeDoseLabel,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<DoseUnit>(
                      value: _unit,
                      items: [
                        for (final u in DoseUnit.values)
                          DropdownMenuItem(
                            value: u,
                            child: Text(_unitLabel(u, l10n)),
                          ),
                      ],
                      onChanged: (val) => setState(() => _unit = val ?? _unit),
                    ),
                  ],
                ),
              ],
              if (_message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _message,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_loading || _loadFailed || _saving)
                      ? null
                      : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.episodeMedicationSave),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
