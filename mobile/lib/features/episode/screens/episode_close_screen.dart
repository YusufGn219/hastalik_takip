import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../domain/errors.dart';
import '../../../l10n/app_localizations.dart';
import '../episode_overview.dart';

/// Devam eden bir dönemi kapatır. Kapanış zamanı "şimdi"dir; not isteğe
/// bağlıdır. Başarılıysa `true` ile geri döner (liste kendini yeniler).
class EpisodeCloseScreen extends ConsumerStatefulWidget {
  const EpisodeCloseScreen({super.key, required this.overview});

  final EpisodeOverview overview;

  @override
  ConsumerState<EpisodeCloseScreen> createState() => _EpisodeCloseScreenState();
}

class _EpisodeCloseScreenState extends ConsumerState<EpisodeCloseScreen> {
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;
  String _message = '';

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _closeEpisode() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isLoading = true;
      _message = '';
    });
    try {
      // Listedeki kart eski kalmış olabilir; kural kontrolü güncel kayda
      // yapılsın (kapalı bir dönemin bitişi üzerine yazılmasın).
      final fresh = await ref
          .read(episodeRepositoryProvider)
          .getById(widget.overview.episode.id);
      if (fresh == null) throw StateError('dönem bulunamadı');
      await ref.read(episodeServiceProvider).close(
            fresh,
            resolutionNotes: _notesController.text.trim(),
          );
      if (mounted) Navigator.pop(context, true);
    } on RuleViolation catch (e) {
      if (!mounted) return;
      setState(() {
        _message = switch (e.code) {
          RuleCodes.episodeAlreadyClosed => l10n.episodeCloseAlreadyClosed,
          RuleCodes.episodeEndBeforeStart => l10n.episodeCloseEndBeforeStart,
          _ => l10n.episodeCloseFailed,
        };
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = l10n.episodeCloseFailed;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final overview = widget.overview;
    final locations = overview.locations.map((l) => l.location).join(', ');

    return Scaffold(
      appBar: AppBar(title: Text(l10n.episodeClose)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tam genişlik: yoksa kart içeriği kadar dar kalır.
            SizedBox(
              width: double.infinity,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        overview.symptomName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (locations.isNotEmpty)
                        Text(l10n.episodeLocation(locations)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.episodeCloseNotesLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText: l10n.episodeCloseNotesHint,
                border: const OutlineInputBorder(),
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
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        l10n.episodeClose,
                        style: const TextStyle(color: Colors.white),
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
