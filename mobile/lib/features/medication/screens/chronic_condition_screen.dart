import 'package:flutter/material.dart';
import '../medication_service.dart';
import '../../../core/utils/parse_utils.dart';

class ChronicConditionScreen extends StatefulWidget {
  const ChronicConditionScreen({super.key});

  @override
  State<ChronicConditionScreen> createState() => _ChronicConditionScreenState();
}

class _ChronicConditionScreenState extends State<ChronicConditionScreen> {
  final MedicationService _service = MedicationService();

  List<dynamic> _conditions = [];
  List<dynamic> _medications = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final conditions = await _service.getChronicConditions();
      final medications = await _service.getMedications();
      setState(() {
        _conditions = conditions;
        _medications = medications;
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

  void _showConditionDialog({Map<String, dynamic>? existing}) {
    final nameController = TextEditingController(
      text: existing != null ? existing['name'] as String : '',
    );
    List<int> selectedIds = existing != null
        ? (existing['medications'] as List)
            .map((m) => parseInt(m['id']))
            .toList()
        : [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing != null ? 'Düzenle' : 'Yeni Kronik Hastalık'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Hastalık adı',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('İlaçlar:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._medications.map((m) {
                  final id = parseInt(m['id']);
                  final name = m['name'] as String;
                  return CheckboxListTile(
                    title: Text(name),
                    value: selectedIds.contains(id),
                    onChanged: (val) {
                      setLocal(() {
                        if (val == true) {
                          selectedIds.add(id);
                        } else {
                          selectedIds.remove(id);
                        }
                      });
                    },
                  );
                }),
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
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  if (existing != null) {
                    await _service.updateChronicCondition(
                      id: parseInt(existing['id']),
                      name: name,
                      medicationIds: selectedIds,
                    );
                    _showSnack('Güncellendi.');
                  } else {
                    await _service.createChronicCondition(
                      name: name,
                      medicationIds: selectedIds,
                    );
                    _showSnack('Eklendi.');
                  }
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

  Future<void> _delete(int id) async {
    try {
      await _service.deleteChronicCondition(id);
      _showSnack('Silindi.');
      _load();
    } catch (e) {
      _showSnack('Hata: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kronik Hastalıklarım'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showConditionDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conditions.isEmpty
              ? const Center(child: Text('Henüz kronik hastalık eklenmemiş.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _conditions.length,
                  itemBuilder: (ctx, i) {
                    final c = _conditions[i];
                    final meds = c['medications'] as List;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  c['name'] as String,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 20),
                                      onPressed: () => _showConditionDialog(existing: c),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                      onPressed: () => _delete(parseInt(c['id'])),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (meds.isEmpty)
                              const Text('İlaç eklenmemiş.',
                                  style: TextStyle(color: Colors.grey))
                            else
                              ...meds.map((m) => Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.medication, size: 16),
                                        const SizedBox(width: 6),
                                        Text(m['name'] as String),
                                      ],
                                    ),
                                  )),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}