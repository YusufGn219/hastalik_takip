import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/providers.dart';
import '../../../core/theme/app_theme.dart';
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

  String _moodEmoji(int mood) {
    const emojis = ['', '😞', '😕', '😐', '🙂', '😊'];
    return emojis[mood];
  }

  String _moodLabel(int mood) {
    const labels = ['', 'Çok Kötü', 'Kötü', 'Orta', 'İyi', 'Harika'];
    return labels[mood];
  }

  Color _moodColor(int mood) {
    if (mood <= 1) return Colors.red;
    if (mood == 2) return Colors.orange;
    if (mood == 3) return Colors.amber;
    if (mood == 4) return Colors.lightGreen;
    return Colors.green;
  }

  String _energyLabel(int energy) {
    const labels = ['', 'Çok Düşük', 'Düşük', 'Orta', 'İyi', 'Yüksek'];
    return labels[energy];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_existingLogId != null ? 'Kaydı Güncelle' : 'Günlük Kayıt'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.symptomBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.medical_services,
                    color: AppColors.symptom, size: 18),
              ),
              tooltip: 'Semptom Ekle',
              onPressed: () => Navigator.pushNamed(context, '/symptoms'),
            ),
          ),
        ],
      ),
      body: _isFetchingExisting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Uyku & Su yan yana
            Row(
              children: [
                Expanded(
                  child: _buildInputCard(
                    icon: Icons.bedtime_outlined,
                    iconColor: AppColors.primary600,
                    iconBg: AppColors.primary50,
                    label: 'Uyku Süresi',
                    hint: '7.5',
                    suffix: 'saat',
                    controller: _sleepController,
                    onChanged: _clearValidationError,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInputCard(
                    icon: Icons.water_drop_outlined,
                    iconColor: AppColors.medication,
                    iconBg: AppColors.medicationBg,
                    label: 'Su Tüketimi',
                    hint: '2.0',
                    suffix: 'litre',
                    controller: _waterController,
                    onChanged: _clearValidationError,
                    isDark: isDark,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Ruh hali kartı
            _buildSectionCard(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(_moodEmoji(_mood),
                          style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Ruh Hali',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(
                            _moodLabel(_mood),
                            style: TextStyle(
                              fontSize: 12,
                              color: _moodColor(_mood),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _moodColor(_mood).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$_mood / 5',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _moodColor(_mood),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(5, (i) {
                      final val = i + 1;
                      final selected = val == _mood;
                      return GestureDetector(
                        onTap: () => setState(() => _mood = val),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: selected ? 52 : 44,
                          height: selected ? 52 : 44,
                          decoration: BoxDecoration(
                            color: selected
                                ? _moodColor(val).withValues(alpha: 0.15)
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.black.withValues(alpha: 0.04)),
                            borderRadius: BorderRadius.circular(14),
                            border: selected
                                ? Border.all(
                                    color: _moodColor(val), width: 1.5)
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              _moodEmoji(val),
                              style: TextStyle(fontSize: selected ? 24 : 20),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Enerji kartı
            _buildSectionCard(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Text('⚡',
                            style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Enerji Seviyesi',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(
                            _energyLabel(_energyLevel),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.amber,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$_energyLevel / 5',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 6,
                      activeTrackColor: Colors.amber,
                      inactiveTrackColor:
                          Colors.amber.withValues(alpha: 0.15),
                      thumbColor: Colors.amber,
                      overlayColor: Colors.amber.withValues(alpha: 0.12),
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 10),
                    ),
                    child: Slider(
                      value: _energyLevel.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      onChanged: (v) =>
                          setState(() => _energyLevel = v.toInt()),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['Çok Düşük', 'Düşük', 'Orta', 'İyi', 'Yüksek']
                        .map((l) => Text(l,
                            style: TextStyle(
                                fontSize: 9,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.4))))
                        .toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Ek alanlar (kafein, spor, ağrı, kendi alanları)
            if (_extras != null)
              ListenableBuilder(
                listenable: _extras!,
                builder: (context, _) => ExtraFieldsSection(
                  controller: _extras!,
                  onEdit: _editFields,
                ),
              ),

            // Notlar kartı
            _buildSectionCard(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.primary50,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(Icons.notes,
                            color: AppColors.primary600, size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Text('Notlar',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      Text('(opsiyonel)',
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.4))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Bugün nasıl hissettin?',
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.black.withValues(alpha: 0.03),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Hata mesajı
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.episodeBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.episode.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.episode, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                            color: AppColors.episode, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // Kaydet butonu
            ElevatedButton(
              onPressed: (_isLoading || _loadFailed) ? null : _saveLog,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Kaydet'),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String hint,
    required String suffix,
    required TextEditingController controller,
    required VoidCallback onChanged,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1825) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.07),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            onChanged: (_) => onChanged(),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.2)),
              suffixText: suffix,
              suffixStyle: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4)),
              filled: true,
              fillColor: Colors.transparent,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required Widget child,
    required bool isDark,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1825) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.07),
          width: 0.5,
        ),
      ),
      child: child,
    );
  }
}