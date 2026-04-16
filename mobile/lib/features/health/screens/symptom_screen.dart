import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../episode/episode_service.dart';

class SymptomScreen extends StatefulWidget {
  const SymptomScreen({super.key});

  @override
  State<SymptomScreen> createState() => _SymptomScreenState();
}

class _SymptomScreenState extends State<SymptomScreen> {
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final EpisodeService _episodeService = EpisodeService();

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
      final response = await ApiClient.dio.get('/health/symptoms/');
      setState(() => _symptoms = response.data);
    } catch (e) {
      setState(() => _message = 'Semptomlar yüklenemedi');
    }
  }

  Future<void> _submitEntry() async {
    if (_selectedSymptomId == null) {
      setState(() => _message = 'Lütfen bir semptom seçin');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiClient.dio.post(
        '/health/symptom-entries/',
        data: {
          'symptom': _selectedSymptomId,
          'severity': _severity.round(),
          'timestamp': DateTime.now().toIso8601String(),
          'notes': _notesController.text,
          'location': _locationController.text,
        },
      );

      final entryId = response.data['id'];
      final activeEpisode = response.data['active_episode'];

      setState(() {
        _selectedSymptomId = null;
        _severity = 5;
        _notesController.clear();
        _locationController.clear();
        _message = '';
      });

      if (activeEpisode != null && mounted) {
        await _showEpisodeDialog(entryId, activeEpisode);
      } else {
        if (mounted) {
          await _showStartEpisodeDialog(entryId);
        }
      }
    } catch (e) {
      setState(() => _message = 'Kayıt oluşturulamadı');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showStartEpisodeDialog(int entryId) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Atak Takibi'),
        content: const Text('Bu semptomu takip etmek ister misin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hayır, sadece kaydet'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Evet, atak başlat'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _startEpisode(entryId);
    } else {
      setState(() => _message = 'Semptom kaydedildi');
    }
  }

  Future<void> _showEpisodeDialog(int entryId, Map<String, dynamic> activeEpisode) async {
    final symptomName = activeEpisode['symptom_name'];

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Devam eden $symptomName atağın var'),
        content: const Text('Bu kayıt nasıl eklensin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'independent'),
            child: const Text('Bağımsız kayıt'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'add'),
            child: const Text('Atağa ekle'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'new_location'),
            child: const Text('Yeni lokasyon'),
          ),
        ],
      ),
    );

    if (result == 'add') {
      await _addToEpisode(entryId, activeEpisode['id'], false);
    } else if (result == 'new_location') {
      await _addToEpisode(entryId, activeEpisode['id'], true);
    } else {
      setState(() => _message = 'Semptom kaydedildi');
    }
  }

  Future<void> _startEpisode(int entryId) async {
    try {
      await _episodeService.startEpisode(entryId);
      setState(() => _message = 'Semptom kaydedildi ve atak başlatıldı');
    } catch (e) {
      setState(() => _message = 'Atak başlatılamadı');
    }
  }

  Future<void> _addToEpisode(int entryId, int episodeId, bool isNewLocation) async {
    try {
      await _episodeService.addToEpisode(
        symptomEntryId: entryId,
        episodeId: episodeId,
        isNewLocation: isNewLocation,
      );
      setState(() => _message = isNewLocation
          ? 'Yeni lokasyon ile atağa eklendi'
          : 'Atağa eklendi');
    } catch (e) {
      setState(() => _message = 'Atağa eklenemedi');
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
                    color: _message.contains('kaydedildi') ||
                            _message.contains('eklendi') ||
                            _message.contains('başlatıldı')
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