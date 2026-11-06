// İlaç / takviye alımı kaydı: yerel veritabanına (MedicationService) yazar.
// Döneme bağlı değildir; döneme ilaç eklemek Dönemler ekranındaki "İlaç Ekle"
// penceresiyle yapılır.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/utils/turkish_text.dart';
import '../../../data/database/app_database.dart';
import '../../../data/database/enums.dart';
import '../../../l10n/app_localizations.dart';
import '../../episode/episode_format.dart';

class MedicationLogScreen extends ConsumerStatefulWidget {
  const MedicationLogScreen({super.key});

  @override
  ConsumerState<MedicationLogScreen> createState() =>
      _MedicationLogScreenState();
}

class _MedicationLogScreenState extends ConsumerState<MedicationLogScreen> {
  final _doseController = TextEditingController();
  final _notesController = TextEditingController();

  List<Medication> _medications = [];
  String? _selectedId;
  DoseUnit _unit = DoseUnit.tablet;
  bool _isSaving = false;
  String _message = '';
  bool _isSuccess = false;

  /// İlaç listesi okunamadıysa kaydetmeye izin verilmez.
  bool _loadFailed = false;

  /// Seçim koddan değiştiğinde (kayıttan sonra sıfırlama, yeni ilaç seçme)
  /// açılır listenin yeniden kurulması için artırılır.
  int _formVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadMedications();
  }

  @override
  void dispose() {
    _doseController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Türkçe alfabe sırasıyla ("Çinko", "Zinc"ten önce).
  List<Medication> _sorted(List<Medication> medications) =>
      [...medications]..sort((a, b) => compareTr(a.name, b.name));

  Future<void> _loadMedications() async {
    try {
      final list = await ref.read(medicationServiceProvider).available();
      if (!mounted) return;
      setState(() {
        _medications = _sorted(list);
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Metin build'de üretilir: bu blok initState içinden eşzamanlı çalışabilir
      // ve orada AppLocalizations.of(context) kullanılamaz.
      setState(() {
        _loadFailed = true;
        _isSuccess = false;
      });
    }
  }

  /// Kullanıcı bir alanı değiştirince eski uyarı ya da bilgi kalkar (liste
  /// okunamadığında çıkan uyarı kalır: kaydetme kapalı).
  void _clearMessage() {
    if (_message.isNotEmpty && !_loadFailed) {
      setState(() => _message = '');
    }
  }

  Future<void> _showAddMedicationDialog() async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => const _AddMedicationDialog(),
    );
    if (name == null || !mounted) return;
    await _addMedication(name);
  }

  /// Aynı adlı ilaç (büyük/küçük harf ve fazla boşluk önemsiz) zaten varsa yeni
  /// satır açmaz, mevcut olanı seçer; yoksa kullanıcının kendi ilacı olarak
  /// (semptomatik) ekler.
  Future<void> _addMedication(String name) async {
    final l10n = AppLocalizations.of(context);
    final service = ref.read(medicationServiceProvider);
    try {
      final current = _sorted(await service.available());
      final key = foldTr(name);
      final existing = current.where((m) => foldTr(m.name) == key).firstOrNull;
      if (existing != null) {
        if (!mounted) return;
        setState(() {
          _medications = current;
          _selectedId = existing.id;
          _formVersion++;
          _loadFailed = false;
          _isSuccess = true;
          _message = l10n.medLogExistsSelected(existing.name);
        });
        return;
      }
      final created = await service.create(name: name.trim());
      final updated = _sorted(await service.available());
      if (!mounted) return;
      setState(() {
        _medications = updated;
        _selectedId = created.id;
        _formVersion++;
        _loadFailed = false;
        _isSuccess = true;
        _message = l10n.medLogAdded(created.name);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSuccess = false;
        _message = l10n.medLogAddError;
      });
    }
  }

  /// Boş = doz yok (null). Dolu ama sayı değilse ya da 0'dan büyük değilse
  /// geçersiz. Ondalık virgül kabul edilir.
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
    final medicationId = _selectedId;
    if (medicationId == null) {
      setState(() {
        _isSuccess = false;
        _message = l10n.medLogPickRequired;
      });
      return;
    }
    final dose = _parseDose();
    if (!dose.valid) {
      setState(() {
        _isSuccess = false;
        _message = l10n.episodeDoseInvalid;
      });
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isSaving = true;
      _message = '';
    });
    try {
      await ref.read(medicationServiceProvider).logIntake(
            medicationId: medicationId,
            takenAt: ref.read(clockProvider)(),
            doseAmount: dose.amount,
            doseUnit: _unit,
            notes: _notesController.text.trim(),
          );
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isSuccess = true;
        _message = l10n.medLogSaved;
        _selectedId = null;
        _formVersion++;
        _unit = DoseUnit.tablet;
        _doseController.clear();
        _notesController.clear();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isSuccess = false;
        _message = l10n.medLogSaveError; // değerler korunur
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Liste okunamadıysa kaydetme kapalıdır ve bu uyarı her zaman görünür.
    final shownMessage = _loadFailed ? l10n.medLogLoadError : _message;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.medLogTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.medLogPick,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(l10n.medLogAddNew),
                  onPressed: _showAddMedicationDialog,
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey(_formVersion),
              initialValue: _selectedId,
              hint: Text(l10n.medLogPickHint),
              isExpanded: true,
              items: [
                for (final m in _medications)
                  DropdownMenuItem<String>(
                    value: m.id,
                    child: Text(m.name),
                  ),
              ],
              onChanged: (val) {
                setState(() => _selectedId = val);
                _clearMessage();
              },
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _doseController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.medLogDoseLabel,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => _clearMessage(),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<DoseUnit>(
                  value: _unit,
                  items: [
                    for (final u in DoseUnit.values)
                      DropdownMenuItem(
                        value: u,
                        child: Text(doseUnitLabel(u, l10n)),
                      ),
                  ],
                  onChanged: (val) => setState(() => _unit = val ?? _unit),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: l10n.medLogNoteLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            if (shownMessage.isNotEmpty)
              Text(
                shownMessage,
                style: TextStyle(
                  color: _isSuccess && !_loadFailed ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isSaving || _loadFailed) ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.medLogSave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Yeni ilaç ekle" penceresi. Adı döndürür (kırpılmış, boş değil); iptalde
/// null. Denetleyiciyi kendisi serbest bırakır.
class _AddMedicationDialog extends StatefulWidget {
  const _AddMedicationDialog();

  @override
  State<_AddMedicationDialog> createState() => _AddMedicationDialogState();
}

class _AddMedicationDialogState extends State<_AddMedicationDialog> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.medLogNewTitle),
      content: TextField(
        controller: _nameController,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        // Veritabanı alanı en çok 100 karakter alır.
        inputFormatters: [LengthLimitingTextInputFormatter(100)],
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: l10n.medLogNewName,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.medLogCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.medLogAdd)),
      ],
    );
  }
}
