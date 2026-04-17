import 'package:flutter/material.dart';
import '../episode_service.dart';
import 'episode_close_screen.dart';
import 'package:mobile/features/medication/medication_service.dart';

class EpisodeListScreen extends StatefulWidget {
  const EpisodeListScreen({super.key});

  @override
  State<EpisodeListScreen> createState() => _EpisodeListScreenState();
}

class _EpisodeListScreenState extends State<EpisodeListScreen>
    with SingleTickerProviderStateMixin {
  final EpisodeService _episodeService = EpisodeService();
  late TabController _tabController;

  List<dynamic> _activeEpisodes = [];
  List<dynamic> _historyEpisodes = [];
  bool _isLoading = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadEpisodes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadEpisodes() async {
    setState(() => _isLoading = true);
    try {
      final active = await _episodeService.getActiveEpisodes();
      final history = await _episodeService.getHistoryEpisodes();
      setState(() {
        _activeEpisodes = active;
        _historyEpisodes = history;
      });
    } catch (e) {
      setState(() => _message = 'Ataklar yüklenemedi');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatDateTime(String isoString) {
    final dt = DateTime.parse(isoString).toLocal();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(int? minutes) {
    if (minutes == null) return '';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0) return '$h saat $m dakika';
    return '$m dakika';
  }

  String _formatLocations(List<dynamic> locations) {
    if (locations.isEmpty) return 'Lokasyon belirtilmemiş';
    return locations.map((l) => l['location']).join(', ');
  }

  void _showAddMedicationSheet(int episodeId) {
    final MedicationService medService = MedicationService();
    List<dynamic> medications = [];
    int? selectedMedId;
    double? doseAmount;
    String doseUnit = 'tablet';
    final doseController = TextEditingController();
    final List<String> doseUnits = ['tablet', 'mg', 'ml', 'damla', 'kapsul'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          if (medications.isEmpty) {
            medService.getMedications().then((data) {
              setLocal(() => medications = data);
            });
          }
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Atağa İlaç Ekle',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  hint: const Text('İlaç seçin...'),
                  items: medications.map((m) {
                    return DropdownMenuItem<int>(
                      value: m['id'] as int,
                      child: Text(m['name'] as String),
                    );
                  }).toList(),
                  onChanged: (val) => setLocal(() => selectedMedId = val),
                  decoration:
                      const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: doseController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Doz miktarı',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) => doseAmount = double.tryParse(val),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: doseUnit,
                      items: doseUnits.map((u) {
                        return DropdownMenuItem(value: u, child: Text(u));
                      }).toList(),
                      onChanged: (val) =>
                          setLocal(() => doseUnit = val ?? 'tablet'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (selectedMedId == null) return;
                      Navigator.pop(ctx);
                      try {
                        await medService.createMedicationLog(
                          medicationId: selectedMedId!,
                          takenAt: DateTime.now().toIso8601String(),
                          doseAmount: doseAmount,
                          doseUnit: doseUnit,
                          episodeId: episodeId,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('İlaç atağa eklendi.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Hata: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    child: const Text('Kaydet'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActiveCard(Map<String, dynamic> episode) {
    final startTime = _formatDateTime(episode['start_time']);
    final locations = _formatLocations(episode['locations'] ?? []);
    final entries = episode['entries'] as List<dynamic>? ?? [];
    final lastSeverity = entries.isNotEmpty ? entries.last['severity'] : '-';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🟡 ', style: TextStyle(fontSize: 18)),
                Expanded(
                  child: Text(
                    episode['symptom_name'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Şiddet: $lastSeverity/10'),
            Text('Başlangıç: $startTime'),
            Text('Lokasyon: $locations'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.medication, size: 16),
                    label: const Text('İlaç Ekle'),
                    onPressed: () =>
                        _showAddMedicationSheet(episode['id'] as int),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade400,
                    ),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              EpisodeCloseScreen(episode: episode),
                        ),
                      );
                      if (result == true) _loadEpisodes();
                    },
                    child: const Text(
                      'Atağı Kapat',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> episode) {
    final startTime = _formatDateTime(episode['start_time']);
    final endTime = episode['ended_at'] != null
        ? _formatDateTime(episode['ended_at'])
        : '-';
    final duration = _formatDuration(episode['duration_minutes']);
    final locations = _formatLocations(episode['locations'] ?? []);
    final entries = episode['entries'] as List<dynamic>? ?? [];
    final maxSeverity = entries.isNotEmpty
        ? entries
            .map((e) => e['severity'] as int)
            .reduce((a, b) => a > b ? a : b)
        : '-';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('✅ ', style: TextStyle(fontSize: 18)),
                Expanded(
                  child: Text(
                    episode['symptom_name'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Maks. şiddet: $maxSeverity/10'),
            Text('$startTime → $endTime · $duration'),
            Text('Lokasyon: $locations'),
            if (episode['resolution_notes'] != null &&
                episode['resolution_notes'].isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '📝 ${episode['resolution_notes']}',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ataklar'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Aktif'),
            Tab(text: 'Geçmiş'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadEpisodes,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _activeEpisodes.isEmpty
                      ? const Center(child: Text('Aktif atak yok'))
                      : ListView.builder(
                          itemCount: _activeEpisodes.length,
                          itemBuilder: (_, i) =>
                              _buildActiveCard(_activeEpisodes[i]),
                        ),
                  _historyEpisodes.isEmpty
                      ? const Center(child: Text('Geçmiş atak yok'))
                      : ListView.builder(
                          itemCount: _historyEpisodes.length,
                          itemBuilder: (_, i) =>
                              _buildHistoryCard(_historyEpisodes[i]),
                        ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadEpisodes,
        tooltip: 'Yenile',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}