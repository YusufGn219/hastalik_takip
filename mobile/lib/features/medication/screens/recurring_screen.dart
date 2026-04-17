import 'package:flutter/material.dart';
import '../medication_service.dart';

class RecurringScreen extends StatefulWidget {
  const RecurringScreen({super.key});

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> {
  final MedicationService _service = MedicationService();

  List<dynamic> _medications = [];
  List<dynamic> _recurringMeds = [];
  bool _isLoading = false;

  final List<String> _dayKeys = [
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'
  ];
  final List<String> _dayLabels = [
    'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final meds = await _service.getMedications();
      setState(() {
        _medications = meds;
        _recurringMeds = meds.where((m) => m['is_recurring'] == true).toList();
      });
    } catch (e) {
      _showSnack('Veriler yüklenemedi: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  String _todayKey() {
    final day = DateTime.now().weekday;
    return _dayKeys[day - 1];
  }

  List<dynamic> get _todaysRoutines {
    final today = _todayKey();
    return _recurringMeds.where((m) {
      final days = m['recurring_days'] as List?;
      if (days == null) return false;
      return days.contains(today);
    }).toList();
  }

  void _showAddRoutineDialog() {
    int? selectedMedId;
    TimeOfDay selectedTime = TimeOfDay.now();
    List<String> selectedDays = [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Yeni Rutin'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<int>(
                  hint: const Text('İlaç seçin...'),
                  items: _medications.map((m) {
                    return DropdownMenuItem<int>(
                      value: m['id'] as int,
                      child: Text(m['name'] as String),
                    );
                  }).toList(),
                  onChanged: (val) => setLocal(() => selectedMedId = val),
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Saat: '),
                    TextButton(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: selectedTime,
                        );
                        if (picked != null) {
                          setLocal(() => selectedTime = picked);
                        }
                      },
                      child: Text(selectedTime.format(ctx)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Günler:'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: List.generate(_dayKeys.length, (i) {
                    final key = _dayKeys[i];
                    final label = _dayLabels[i];
                    final selected = selectedDays.contains(key);
                    return FilterChip(
                      label: Text(label),
                      selected: selected,
                      onSelected: (val) {
                        setLocal(() {
                          if (val) {
                            selectedDays.add(key);
                          } else {
                            selectedDays.remove(key);
                          }
                        });
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedMedId == null || selectedDays.isEmpty) {
                  _showSnack('İlaç ve en az bir gün seçin.', isError: true);
                  return;
                }
                Navigator.pop(ctx);
                final timeStr =
                    '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}:00';
                try {
                  await _service.createMedication(
                    name: _medications
                        .firstWhere((m) => m['id'] == selectedMedId)['name'],
                    type: 'chronic',
                    isRecurring: true,
                    recurringTime: timeStr,
                    recurringDays: selectedDays,
                  );
                  _showSnack('Rutin eklendi.');
                  _load();
                } catch (e) {
                  _showSnack('Hata: $e', isError: true);
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markAsTaken(Map<String, dynamic> med) async {
    try {
      await _service.createMedicationLog(
        medicationId: med['id'] as int,
        takenAt: DateTime.now().toIso8601String(),
      );
      _showSnack('${med['name']} alındı olarak işaretlendi.');
    } catch (e) {
      _showSnack('Hata: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rutinlerim'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddRoutineDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Bugünün Rutinleri',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_todaysRoutines.isEmpty)
                  const Text('Bugün için rutin yok.',
                      style: TextStyle(color: Colors.grey))
                else
                  ..._todaysRoutines.map((m) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.medication),
                          title: Text(m['name'] as String),
                          subtitle: Text(
                              m['recurring_time'] != null
                                  ? '${m['recurring_time']}'
                                  : ''),
                          trailing: ElevatedButton(
                            onPressed: () => _markAsTaken(m),
                            child: const Text('Aldım'),
                          ),
                        ),
                      )),
                const SizedBox(height: 24),
                const Text(
                  'Tüm Rutinler',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_recurringMeds.isEmpty)
                  const Text('Henüz rutin tanımlanmamış.',
                      style: TextStyle(color: Colors.grey))
                else
                  ..._recurringMeds.map((m) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.repeat),
                          title: Text(m['name'] as String),
                          subtitle: Text(
                            m['recurring_time'] != null
                                ? '${m['recurring_time']}'
                                : '',
                          ),
                        ),
                      )),
              ],
            ),
    );
  }
}