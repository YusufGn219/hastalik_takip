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
import '../../../domain/errors.dart';
import '../../episode/episode_format.dart';
import 'category_dialogs.dart';

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
  List<MedicationCategory> _categories = [];
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
      final service = ref.read(medicationServiceProvider);
      final list = await service.available();
      final categories = await service.categories();
      if (!mounted) return;
      setState(() {
        _medications = _sorted(list);
        _categories = categories;
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

  /// Açılır listede ve etiketlerde ilaç adı; kategorisi varsa "Parol · Ağrı".
  String _medicationLabel(Medication m) {
    final category =
        _categories.where((c) => c.id == m.categoryId).firstOrNull;
    return category == null ? m.name : '${m.name} · ${category.name}';
  }

  Medication? get _selectedMedication =>
      _medications.where((m) => m.id == _selectedId).firstOrNull;

  Future<void> _showAddMedicationDialog() async {
    final result = await showDialog<_NewMedication>(
      context: context,
      builder: (ctx) => _AddMedicationDialog(categories: _categories),
    );
    if (result == null || !mounted) return;
    await _addMedication(result);
  }

  Future<void> _showCategoryManager() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const CategoryManagerDialog(),
    );
    if (!mounted) return;
    await _loadMedications(); // silinen kategoriler ilaç etiketlerinden düşer
  }

  /// Seçili ilacın kategorisini değiştirir (null = kategorisiz).
  Future<void> _changeCategory(String medicationId, String? categoryId) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(medicationServiceProvider)
          .setCategory(medicationId, categoryId);
      await _loadMedications();
      if (!mounted) return;
      setState(() {
        _isSuccess = true;
        _message = l10n.medLogCategoryChanged;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSuccess = false;
        _message = l10n.medLogCategoryError;
      });
    }
  }

  /// Aynı adlı ilaç (büyük/küçük harf ve fazla boşluk önemsiz) zaten varsa yeni
  /// satır açmaz, mevcut olanı seçer; yoksa kullanıcının kendi ilacı olarak
  /// (isteğe bağlı kategoriyle) ekler. Yeni kategori adı verildiyse önce o
  /// oluşturulur; aynı adlı kategori varsa o kullanılır.
  Future<void> _addMedication(_NewMedication input) async {
    final name = input.name;
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
      var categoryId = input.categoryId;
      final newCategory = input.newCategoryName?.trim();
      if (newCategory != null && newCategory.isNotEmpty) {
        final key = foldTr(newCategory);
        final known = (await service.categories())
            .where((c) => foldTr(c.name) == key)
            .firstOrNull;
        categoryId =
            known?.id ?? (await service.createCategory(newCategory)).id;
      }
      final created =
          await service.create(name: name.trim(), categoryId: categoryId);
      final categories = await service.categories();
      final updated = _sorted(await service.available());
      if (!mounted) return;
      setState(() {
        _medications = updated;
        _categories = categories;
        _selectedId = created.id;
        _formVersion++;
        _loadFailed = false;
        _isSuccess = true;
        _message = l10n.medLogAdded(created.name);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSuccess = false;
        _message = e is RuleViolation && e.code.startsWith('category_name')
            ? categoryErrorText(e, l10n)
            : l10n.medLogAddError;
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
                Wrap(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.label_outline),
                      label: Text(l10n.medLogManageCategories),
                      onPressed: _showCategoryManager,
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: Text(l10n.medLogAddNew),
                      onPressed: _showAddMedicationDialog,
                    ),
                  ],
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
                    child: Text(_medicationLabel(m)),
                  ),
              ],
              onChanged: (val) {
                setState(() => _selectedId = val);
                _clearMessage();
              },
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            if (_selectedMedication != null) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                key: ValueKey(
                    'cat-$_selectedId-${_selectedMedication!.categoryId}'),
                initialValue: _categories
                        .any((c) => c.id == _selectedMedication!.categoryId)
                    ? _selectedMedication!.categoryId
                    : null,
                isExpanded: true,
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(l10n.medLogNoCategory),
                  ),
                  for (final c in _categories)
                    DropdownMenuItem<String?>(value: c.id, child: Text(c.name)),
                ],
                onChanged: (val) => _changeCategory(_selectedId!, val),
                decoration: InputDecoration(
                  labelText: l10n.medLogCategoryLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
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

/// "Yeni ilaç ekle" penceresinin sonucu.
class _NewMedication {
  const _NewMedication(this.name, {this.categoryId, this.newCategoryName});

  final String name;
  final String? categoryId;

  /// Doluysa pencereden yeni kategori oluşturulması istenmiştir.
  final String? newCategoryName;
}

/// "Yeni ilaç ekle" penceresi. Ad (kırpılmış, boş değil) ve isteğe bağlı
/// kategoriyi döndürür; iptalde null. Denetleyicileri kendisi serbest bırakır.
class _AddMedicationDialog extends StatefulWidget {
  const _AddMedicationDialog({required this.categories});

  final List<MedicationCategory> categories;

  @override
  State<_AddMedicationDialog> createState() => _AddMedicationDialogState();
}

class _AddMedicationDialogState extends State<_AddMedicationDialog> {
  /// "Yeni kategori oluştur" satırının değeri (kimlikler UUID'dir, çakışmaz).
  static const _newCategoryMarker = '__new_category__';

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _newCategoryController = TextEditingController();
  String? _categoryChoice; // null = kategorisiz, kategori kimliği ya da işaret

  bool get _creatingCategory => _categoryChoice == _newCategoryMarker;

  @override
  void dispose() {
    _nameController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final newName = _newCategoryController.text.trim();
    Navigator.pop(
      context,
      _NewMedication(
        name,
        categoryId: _creatingCategory ? null : _categoryChoice,
        newCategoryName:
            _creatingCategory && newName.isNotEmpty ? newName : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.medLogNewTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
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
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _categoryChoice,
              isExpanded: true,
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(l10n.medLogNoCategory),
                ),
                for (final c in widget.categories)
                  DropdownMenuItem<String?>(value: c.id, child: Text(c.name)),
                DropdownMenuItem<String?>(
                  value: _newCategoryMarker,
                  child: Text(l10n.medLogNewCategory),
                ),
              ],
              onChanged: (val) => setState(() => _categoryChoice = val),
              decoration: InputDecoration(
                labelText: l10n.medLogCategoryLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_creatingCategory) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _newCategoryController,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: [LengthLimitingTextInputFormatter(100)],
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: l10n.medLogNewCategoryName,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ],
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
