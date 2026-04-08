import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/storage/token_storage.dart';

class SymptomScreen extends StatefulWidget {
  const SymptomScreen({super.key});

  @override
  State<SymptomScreen> createState() => _SymptomScreenState();
}

class _SymptomScreenState extends State<SymptomScreen> {
  final TextEditingController _notesController = TextEditingController();

  List<dynamic> _symptoms = [];
  int? _selectedSymptomId;
  double _severity = 5;
  bool _isLoading = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _loadSymptoms();
  }

  Future<void> _loadSymptoms() async {
    try {
      final token = await TokenStorage.getAccessToken();
      final dio = Dio();
      final response = await dio.get(
        'http://192.168.1.103:8000/api/v1/health/symptoms/',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      setState(() {
        _symptoms = response.data;
      });
    } catch (e) {
      setState(() {
        _message = 'Semptomlar yüklenemedi';
      });
    }
  }

  Future<void> _submitEntry() async {
    if (_selectedSymptomId == null) {
      setState(() => _message = 'Lütfen bir semptom seçin');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final token = await TokenStorage.getAccessToken();
      final dio = Dio();
      await dio.post(
        'http://192.168.1.103:8000/api/v1/health/symptom-entries/',
        data: {
          'symptom': _selectedSymptomId,
          'severity': _severity.round(),
          'timestamp': DateTime.now().toIso8601String(),
          'notes': _notesController.text,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      setState(() {
        _message = 'Semptom kaydedildi';
        _selectedSymptomId = null;
        _severity = 5;
        _notesController.clear();
      });
    } catch (e) {
      setState(() => _message = 'Kayıt oluşturulamadı');
    } finally {
      setState(() => _isLoading = false);
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
            const Text('Semptom', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _selectedSymptomId,
              hint: const Text('Semptom seçin'),
              items: _symptoms.map((s) {
                return DropdownMenuItem<int>(
                  value: s['id'] as int,
                  child: Text(s['name']),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedSymptomId = val),
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
            const SizedBox(height: 24),
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
                onPressed: _isLoading ? null : _submitEntry,
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
                    color: _message.contains('kaydedildi')
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}