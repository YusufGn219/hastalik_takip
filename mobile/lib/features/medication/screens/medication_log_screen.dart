import 'package:flutter/material.dart';
import '../medication_service.dart';

class MedicationLogScreen extends StatefulWidget {
  const MedicationLogScreen({super.key});

  @override
  State<MedicationLogScreen> createState() => _MedicationLogScreenState();
}

class _MedicationLogScreenState extends State<MedicationLogScreen> {
  final MedicationService _service = MedicationService();

  List<dynamic> _medications = [];
  int? _selectedMedicationId;
  String _doseUnit = 'tablet';
  String _notes = '';
  double? _doseAmount;
  bool _isLoading = false;
  String? _message;
  bool _isSuccess = false;

  final _doseController = TextEditingController();
  final _notesController = TextEditingController();

  final List<String> _doseUnits = ['tablet', 'mg', 'ml', 'damla', 'kapsul'];

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

  Future<void> _loadMedications() async {
    try {
      final data = await _service.getMedications();
      setState(() => _medications = data);
    } catch (e) {
      setState(() {
        _message = 'İlaçlar yüklenemedi.';
        _isSuccess = false;
      });
    }
  }

 void _showAddMedicationDialog() {
  final nameController = TextEditingController();
  final descController = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Yeni İlaç Ekle'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'İlaç adı',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descController,
            decoration: const InputDecoration(
              labelText: 'Açıklama (opsiyonel)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: () async {
            final name = nameController.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(ctx);
            try {
              await _service.createMedication(
                name: name,
                type: 'symptomatic',
              );
              await _loadMedications();
              setState(() {
                _message = '$name eklendi.';
                _isSuccess = true;
              });
            } catch (e) {
              setState(() {
                _message = 'Hata: $e';
                _isSuccess = false;
              });
            }
          },
          child: const Text('Kaydet'),
        ),
      ],
    ),
  );
}

  Future<void> _save() async {
    if (_selectedMedicationId == null) {
      setState(() {
        _message = 'Lütfen bir ilaç seçin.';
        _isSuccess = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _service.createMedicationLog(
        medicationId: _selectedMedicationId!,
        takenAt: DateTime.now().toIso8601String(),
        doseAmount: _doseAmount,
        doseUnit: _doseUnit,
        notes: _notes,
      );
      setState(() {
        _message = 'İlaç kaydedildi.';
        _isSuccess = true;
        _selectedMedicationId = null;
        _doseController.clear();
        _notesController.clear();
        _doseAmount = null;
      });
    } catch (e) {
      setState(() {
        _message = 'Hata oluştu: $e';
        _isSuccess = false;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('İlaç / Takviye Al')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('İlaç seç',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Yeni ilaç ekle'),
                  onPressed: _showAddMedicationDialog,
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _selectedMedicationId,
              hint: const Text('İlaç seçin...'),
              items: _medications.map((m) {
                final type = m['type'] == 'chronic' ? 'Kronik' : 'Semptomatik';
                return DropdownMenuItem<int>(
                  value: m['id'] as int,
                  child: Text('${m['name']} · $type'),
                );
              }).toList(),
              onChanged: (val) =>
                  setState(() => _selectedMedicationId = val),
              decoration:
                  const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _doseController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Doz miktarı (opsiyonel)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => _doseAmount = double.tryParse(val),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _doseUnit,
                  items: _doseUnits.map((u) {
                    return DropdownMenuItem(value: u, child: Text(u));
                  }).toList(),
                  onChanged: (val) =>
                      setState(() => _doseUnit = val ?? 'tablet'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Not (opsiyonel)',
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => _notes = val,
            ),
            const SizedBox(height: 24),
            if (_message != null)
              Text(
                _message!,
                style: TextStyle(
                  color: _isSuccess ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}