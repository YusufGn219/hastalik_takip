import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

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
  String? _successMessage;

  Future<void> _saveLog() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await ApiClient.dio.post(
        '/health/logs/',
        data: {
          'date': DateTime.now().toIso8601String().split('T')[0],
          'sleep_hours': double.parse(_sleepController.text.trim()),
          'water_intake': double.parse(_waterController.text.trim()),
          'mood': _mood,
          'energy_level': _energyLevel,
          'notes': _notesController.text.trim(),
        },
      );
      setState(() => _successMessage = 'Kayıt başarıyla oluşturuldu!');
    } on DioException catch (e) {
      setState(() =>
          _errorMessage = e.response?.data['message'] ?? 'Bir hata oluştu');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildSlider(String label, int value, Function(int) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: $value / 5'),
        Slider(
          value: value.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          label: value.toString(),
          onChanged: (v) => onChanged(v.toInt()),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Günlük Kayıt'),
        actions: [
          IconButton(
            icon: const Icon(Icons.medical_services),
            tooltip: 'semptom ekle',
            onPressed: () => Navigator.pushNamed(context, '/symptoms'),
          )
        ],),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _sleepController,
                decoration: const InputDecoration(
                  labelText: 'Uyku Süresi (saat)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _waterController,
                decoration: const InputDecoration(
                  labelText: 'Su Tüketimi (litre)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              _buildSlider('Ruh Hali', _mood, (v) => setState(() => _mood = v)),
              _buildSlider('Enerji Seviyesi', _energyLevel,
                  (v) => setState(() => _energyLevel = v)),
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notlar (opsiyonel)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_errorMessage!,
                      style: const TextStyle(color: Colors.red)),
                ),
              if (_successMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(_successMessage!,
                      style: const TextStyle(color: Colors.green)),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveLog,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Kaydet'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}