// Günlük kayıt (taslaktaki "Hızlı ekle: günlük kayıt" alt sayfası): uyku ve su
// "− değer +" alanlarıyla, ruh hali ve enerji 1-5 sayı düğmeleriyle, ek alanlar
// ve (isteğe bağlı) not. Kaydetme mantığı değişmedi: dört çekirdek alan zorunlu,
// günde tek kayıt (upsert).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/form_sheet.dart';
import '../../../data/repositories/support.dart';
import '../../../l10n/app_localizations.dart';
import '../extra_fields_controller.dart';
import '../widgets/extra_fields_section.dart';

class DailyLogScreen extends ConsumerStatefulWidget {
  const DailyLogScreen({super.key});

  @override
  ConsumerState<DailyLogScreen> createState() => _DailyLogScreenState();
}

class _DailyLogScreenState extends ConsumerState<DailyLogScreen> {
  final _sleepController = TextEditingController();
  final _waterController = TextEditingController();
  final _notesController = TextEditingController();
  int _mood = 3;
  int _energyLevel = 3;
  bool _isLoading = false;
  bool _isFetchingExisting = true;
  String? _errorMessage;
  String? _existingLogId;

  /// Ek alanlar (kafein, spor...). Kurulamazsa null: bölüm görünmez ve günlük
  /// kaydı bundan etkilenmez.
  ExtraFieldsController? _extras;

  /// Ekran açıldığındaki yerel gün ('YYYY-MM-DD'). Gece yarısı geçilse bile
  /// okunan ve yazılan gün aynı kalır.
  late final String _logDate;

  /// Bugünün kaydı okunamadıysa kaydetmeye izin verilmez: aksi halde mevcut
  /// değerlerin habersizce üzerine yazılabilir.
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _logDate = dayKey(ref.read(clockProvider)());
    try {
      _extras = ExtraFieldsController(
        service: ref.read(dailyFieldServiceProvider),
        day: _logDate,
        formatNumber: _numText,
      )..load();
    } catch (_) {
      // Ek alanlar kurulamazsa bölüm gösterilmez.
    }
    _loadTodayLog();
  }

  @override
  void dispose() {
    _sleepController.dispose();
    _waterController.dispose();
    _notesController.dispose();
    _extras?.dispose();
    super.dispose();
  }

  /// 8.0 → "8", 7.5 → "7,5" (yerel ondalık ayracıyla): alanda gereksiz ondalık
  /// görünmesin ve yazılan "7,5" geri "7.5" olmasın. Değer yuvarlanmaz.
  String _numText(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    final separator = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toString(),
    ).symbols.DECIMAL_SEP;
    return v.toString().replaceAll('.', separator);
  }

  /// Doğrulama uyarısı, kullanıcı alanı düzeltmeye başlayınca kalkar. Bugünün
  /// kaydı okunamadığında çıkan uyarı (kaydetme kapalı) kalır.
  void _clearValidationError() {
    if (_errorMessage != null && !_loadFailed) {
      setState(() => _errorMessage = null);
    }
  }

  /// Bugünün (yerel gün) kaydı varsa alanları onun değerleriyle doldurur.
  Future<void> _loadTodayLog() async {
    final repository = ref.read(dailyLogRepositoryProvider);
    try {
      final log = await repository.getByDate(_logDate);
      if (!mounted) return;
      setState(() {
        if (log != null) {
          _existingLogId = log.id;
          _sleepController.text = _numText(log.sleepHours);
          _waterController.text = _numText(log.waterIntake);
          _mood = log.mood;
          _energyLevel = log.energyLevel;
          _notesController.text = log.notes ?? '';
        }
        _isFetchingExisting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadFailed = true;
        _errorMessage = AppLocalizations.of(context).dailyLogLoadError;
        _isFetchingExisting = false;
      });
    }
  }

  /// Ondalık virgül (Türkçe klavye) de kabul edilir: "7,5" → 7.5. Boş, sayı
  /// olmayan veya [min]..[max] dışındaki değer için null döner.
  double? _parseInRange(String text, {required double min, required double max}) {
    final v = double.tryParse(text.trim().replaceAll(',', '.'));
    if (v == null || v.isNaN || v < min || v > max) return null;
    return v;
  }

  Future<void> _saveLog() async {
    final l10n = AppLocalizations.of(context);

    // Dört alan zorunlu (istatistikleri etkiler); ruh hali ve enerji her zaman
    // seçili olduğundan burada yalnız uyku ve su doğrulanır.
    final sleep = _parseInRange(_sleepController.text, min: 0, max: 24);
    if (sleep == null) {
      setState(() => _errorMessage = l10n.dailyLogSleepInvalid);
      return;
    }
    final water = _parseInRange(_waterController.text, min: 0, max: 10);
    if (water == null) {
      setState(() => _errorMessage = l10n.dailyLogWaterInvalid);
      return;
    }

    final badExtra = _extras?.firstInvalid();
    if (badExtra != null) {
      setState(
        () => _errorMessage = l10n.extraFieldInvalid(
          badExtra.name,
          '${_numText(badExtra.minValue)}–${_numText(badExtra.maxValue)}',
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final wasUpdate = _existingLogId != null;
    final notes = _notesController.text.trim();
    try {
      await ref.read(dailyLogRepositoryProvider).upsert(
            logDate: _logDate,
            sleepHours: sleep,
            waterIntake: water,
            mood: _mood,
            energyLevel: _energyLevel,
            notes: notes.isEmpty ? null : notes,
          );
      try {
        await _extras?.save();
      } catch (_) {
        // Günlük kaydı yazıldı; yalnız ek alanlar yazılamadı. Ekran açık kalır.
        if (!mounted) return;
        setState(() => _errorMessage = l10n.extraFieldsSaveError);
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(wasUpdate ? l10n.dailyLogUpdated : l10n.dailyLogSaved),
          backgroundColor: AppColors.daily,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = l10n.dailyLogSaveError);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _editFields() async {
    await Navigator.pushNamed(context, '/daily-fields');
    if (!mounted) return;
    await _extras?.reloadFields();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    final footer = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorMessage != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.episodeBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.episode.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.episode, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.episode, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ElevatedButton(
          onPressed: (_isLoading || _loadFailed || _isFetchingExisting) ? null : _saveLog,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Kaydet'),
        ),
      ],
    );

    return FormSheet(
      title: _existingLogId != null ? 'Kaydı güncelle' : 'Günlük kayıt',
      footer: footer,
      child: _isFetchingExisting
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StepperField(
                  label: 'Uyku',
                  controller: _sleepController,
                  unit: 'saat',
                  step: 0.5,
                  min: 0,
                  max: 24,
                  start: 7,
                  format: _numText,
                  onChanged: _clearValidationError,
                ),
                StepperField(
                  label: 'Su',
                  controller: _waterController,
                  unit: 'litre',
                  step: 0.5,
                  min: 0,
                  max: 10,
                  start: 1.5,
                  format: _numText,
                  onChanged: _clearValidationError,
                ),
                ScaleButtons(
                  label: 'Ruh hali',
                  value: _mood,
                  keyPrefix: 'ruh_hali',
                  onChanged: (v) => setState(() => _mood = v),
                ),
                ScaleButtons(
                  label: 'Enerji',
                  value: _energyLevel,
                  keyPrefix: 'enerji',
                  onChanged: (v) => setState(() => _energyLevel = v),
                ),
                // Ek alanlar (kafein, spor, ağrı, kendi alanları)
                if (_extras != null)
                  ListenableBuilder(
                    listenable: _extras!,
                    builder: (context, _) => ExtraFieldsSection(
                      controller: _extras!,
                      onEdit: _editFields,
                    ),
                  ),
                const SizedBox(height: 10),
                Text('Not (isteğe bağlı)',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: muted)),
                const SizedBox(height: 6),
                TextField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(hintText: 'Bugün nasıl hissettin?'),
                ),
              ],
            ),
    );
  }
}
