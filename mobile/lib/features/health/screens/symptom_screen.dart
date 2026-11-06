import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/providers.dart';
import '../../../core/utils/turkish_text.dart';
import '../../../data/database/app_database.dart';
import '../../../l10n/app_localizations.dart';

class SymptomScreen extends ConsumerStatefulWidget {
  const SymptomScreen({super.key});

  @override
  ConsumerState<SymptomScreen> createState() => _SymptomScreenState();
}

class _SymptomScreenState extends ConsumerState<SymptomScreen> {
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  List<Symptom> _symptoms = [];
  String? _selectedSymptomId;
  double _severity = 5;
  bool _isLoading = false;
  String _message = '';
  bool _messageIsError = false;

  /// Semptom listesi okunamadıysa kaydetmeye izin verilmez.
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadSymptoms();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _setMessage(String text, {required bool error}) {
    _message = text;
    _messageIsError = error;
  }

  /// Türkçe alfabe sırasıyla ("Öksürük", "Yorgunluk"tan önce).
  List<Symptom> _sorted(List<Symptom> symptoms) =>
      [...symptoms]..sort((a, b) => compareTr(a.name, b.name));

  /// Yerel veritabanından silinmemiş semptomları (hazır + kullanıcının
  /// eklediği) okur ve Türkçe sırayla gösterir.
  Future<void> _loadSymptoms() async {
    try {
      final symptoms = await ref.read(symptomRepositoryProvider).listActive();
      if (!mounted) return;
      setState(() {
        _symptoms = _sorted(symptoms);
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadFailed = true;
        _setMessage(AppLocalizations.of(context).symptomsLoadError, error: true);
      });
    }
  }

  Future<void> _showAddSymptomDialog() async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => const _AddSymptomDialog(),
    );
    if (name == null || !mounted) return;
    await _addSymptom(name);
  }

  /// Aynı adlı semptom (büyük/küçük harf ve fazla boşluk önemsiz) zaten varsa
  /// yeni satır açmaz, mevcut olanı seçer; yoksa özel semptom olarak ekler.
  Future<void> _addSymptom(String name) async {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(symptomRepositoryProvider);
    try {
      final current = _sorted(await repository.listActive());
      final key = foldTr(name);
      final existing = current.where((s) => foldTr(s.name) == key).firstOrNull;
      if (existing != null) {
        if (!mounted) return;
        setState(() {
          _symptoms = current;
          _selectedSymptomId = existing.id;
          _loadFailed = false;
          _setMessage(l10n.symptomExistsSelected, error: false);
        });
        return;
      }
      final created = await repository.createCustom(name: name.trim());
      final updated = _sorted(await repository.listActive());
      if (!mounted) return;
      setState(() {
        _symptoms = updated;
        _selectedSymptomId = created.id;
        _loadFailed = false;
        _setMessage(l10n.symptomAdded, error: false);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _setMessage(l10n.symptomAddError, error: true));
    }
  }

  Future<void> _submitEntry() async {
    final l10n = AppLocalizations.of(context);
    final symptomId = _selectedSymptomId;
    if (symptomId == null) {
      setState(() => _setMessage(l10n.symptomSelectRequired, error: true));
      return;
    }

    setState(() {
      _isLoading = true;
      _setMessage('', error: false);
    });

    // Formu sıfırlamadan önce: dönem sorusunda semptomun adı gerekir.
    final symptomName =
        _symptoms.where((s) => s.id == symptomId).firstOrNull?.name ?? '';

    final SymptomEntry entry;
    try {
      entry = await ref.read(symptomEntryRepositoryProvider).create(
            symptomId: symptomId,
            severity: _severity.round(),
            timestamp: ref.read(clockProvider)(),
            location: _locationController.text.trim(),
            notes: _notesController.text.trim(),
          );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _setMessage(l10n.symptomSaveError, error: true);
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _selectedSymptomId = null;
      _severity = 5;
      _notesController.clear();
      _locationController.clear();
      _setMessage(l10n.symptomSaved, error: false);
    });

    await _offerEpisode(entry, symptomName);
  }

  /// Giriş kaydedildikten sonra dönem (başlangıcı ve sonu olan şikâyet dönemi)
  /// akışı: semptom için devam eden dönem yoksa takip etmek isteyip istemediği
  /// sorulur; varsa girişin nasıl ekleneceği sorulur. Giriş her durumda zaten
  /// kayıtlıdır; buradaki bir hata girişi etkilemez.
  Future<void> _offerEpisode(SymptomEntry entry, String symptomName) async {
    final l10n = AppLocalizations.of(context);
    final episodes = ref.read(episodeServiceProvider);
    try {
      final active = await episodes.activeEpisode(entry.symptomId);
      if (!mounted) return;
      if (active == null) {
        final start = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.symptomEpisodeTrackTitle),
            content: Text(l10n.symptomEpisodeTrackQuestion),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.symptomEpisodeTrackNo),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.symptomEpisodeTrackYes),
              ),
            ],
          ),
        );
        if (start != true) return;
        await episodes.start(entry);
        if (!mounted) return;
        setState(() =>
            _setMessage(l10n.symptomSavedEpisodeStarted, error: false));
        return;
      }

      final choice = await showDialog<_EpisodeChoice>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.symptomEpisodeOngoingTitle(symptomName)),
          content: Text(l10n.symptomEpisodeOngoingQuestion),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, _EpisodeChoice.independent),
              child: Text(l10n.symptomEpisodeIndependent),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, _EpisodeChoice.add),
              child: Text(l10n.symptomEpisodeAdd),
            ),
            // Konum yazılmadıysa "yeni konum" seçeneğinin anlamı yoktur.
            if (entry.location.isNotEmpty)
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, _EpisodeChoice.newLocation),
                child: Text(l10n.symptomEpisodeNewLocation),
              ),
          ],
        ),
      );
      switch (choice) {
        case _EpisodeChoice.add:
          await episodes.addEntry(active, entry);
          if (!mounted) return;
          setState(() =>
              _setMessage(l10n.symptomAddedToEpisode, error: false));
        case _EpisodeChoice.newLocation:
          await episodes.addEntry(active, entry, isNewLocation: true);
          if (!mounted) return;
          setState(() => _setMessage(l10n.symptomAddedToEpisodeNewLocation,
              error: false));
        case _EpisodeChoice.independent:
        case null:
          return;
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _setMessage(l10n.symptomEpisodeError, error: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Semptom Ekle')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Semptom',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Yeni ekle'),
                  onPressed: _showAddSymptomDialog,
                ),
              ],
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: _selectedSymptomId,
              hint: const Text('Semptom seçin'),
              isExpanded: true,
              items: _symptoms.map((s) {
                return DropdownMenuItem<String>(
                  value: s.id,
                  child: Text(s.name),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedSymptomId = val),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            Text(
              'Şiddet: ${_severity.round()}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Slider(
              value: _severity,
              min: 1,
              max: 10,
              divisions: 9,
              label: _severity.round().toString(),
              onChanged: (val) => setState(() => _severity = val),
            ),
            const SizedBox(height: 16),
            const Text('Lokasyon', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                hintText: 'Opsiyonel (örn: Şakaklarda, Göz arkasında)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Notlar', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                hintText: 'Opsiyonel not ekleyin',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isLoading || _loadFailed) ? null : _submitEntry,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Kaydet'),
              ),
            ),
            if (_message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _message,
                  style: TextStyle(
                    color: _messageIsError ? Colors.red : Colors.green,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Devam eden dönem varken yeni girişin nasıl ekleneceği.
enum _EpisodeChoice { independent, add, newLocation }

/// "Yeni semptom ekle" penceresi. Adı döndürür (kırpılmış, boş değil); iptalde
/// null. Denetleyiciyi kendisi serbest bırakır.
class _AddSymptomDialog extends StatefulWidget {
  const _AddSymptomDialog();

  @override
  State<_AddSymptomDialog> createState() => _AddSymptomDialogState();
}

class _AddSymptomDialogState extends State<_AddSymptomDialog> {
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
    return AlertDialog(
      title: const Text('Yeni Semptom Ekle'),
      content: TextField(
        controller: _nameController,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        // Veritabanı alanı en çok 100 karakter alır.
        inputFormatters: [LengthLimitingTextInputFormatter(100)],
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(
          labelText: 'Semptom adı',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Ekle'),
        ),
      ],
    );
  }
}
