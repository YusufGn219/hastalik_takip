import 'package:flutter/material.dart';
import '../episode_service.dart';

class EpisodeCloseScreen extends StatefulWidget {
  final Map<String, dynamic> episode;

  const EpisodeCloseScreen({super.key, required this.episode});

  @override
  State<EpisodeCloseScreen> createState() => _EpisodeCloseScreenState();
}

class _EpisodeCloseScreenState extends State<EpisodeCloseScreen> {
  final EpisodeService _episodeService = EpisodeService();
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;
  String _message = '';

  Future<void> _closeEpisode() async {
    setState(() => _isLoading = true);
    try {
      await _episodeService.closeEpisode(
        episodeId: widget.episode['id'],
        endedAt: DateTime.now(),
        resolutionNotes: _notesController.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _message = 'Atak kapatılamadı');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final symptomName = widget.episode['symptom_name'];
    final locations = (widget.episode['locations'] as List<dynamic>? ?? [])
        .map((l) => l['location'])
        .join(', ');

    return Scaffold(
      appBar: AppBar(title: const Text('Atağı Kapat')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      symptomName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (locations.isNotEmpty)
                      Text('Lokasyon: $locations'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Nasıl geçti? (opsiyonel)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                hintText: 'Örn: Uyuyarak geçirdim, ilaç aldım...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade400,
                ),
                onPressed: _isLoading ? null : _closeEpisode,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text(
                        'Atağı Kapat',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ),
            if (_message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _message,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}