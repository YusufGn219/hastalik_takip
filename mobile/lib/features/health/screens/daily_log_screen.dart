import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class DailyLogScreen extends StatefulWidget {
  const DailyLogScreen({super.key});

  @override
  State<DailyLogScreen> createState() => _DailyLogScreenState();
}

class _DailyLogScreenState extends State<DailyLogScreen> {
  final _sleepController = TextEditingController();
  final _waterController = TextEditingController();
  final _notesController = TextEditingController();
  int _mood = 3;
  int _energyLevel = 3;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _sleepController.dispose();
    _waterController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveLog() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiClient.dio.post(
        '/health/logs/',
        data: {
          'date': DateTime.now().toIso8601String().split('T')[0],
          'sleep_hours': double.tryParse(_sleepController.text.trim()) ?? 0,
          'water_intake': double.tryParse(_waterController.text.trim()) ?? 0,
          'mood': _mood,
          'energy_level': _energyLevel,
          'notes': _notesController.text.trim(),
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Günlük kayıt kaydedildi'),
          backgroundColor: AppColors.daily,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context);
    } on DioException catch (e) {
      setState(() =>
          _errorMessage = e.response?.data['message'] ?? 'Bir hata oluştu');
    } finally {
      setState(() => _isLoading = false);
    }
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
        title: const Text('Günlük Kayıt'),
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
      body: SingleChildScrollView(
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
              onPressed: _isLoading ? null : _saveLog,
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