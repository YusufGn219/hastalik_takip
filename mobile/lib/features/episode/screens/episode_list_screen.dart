import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../episode_format.dart';
import '../episode_overview.dart';
import 'episode_close_screen.dart';
import 'episode_medication_sheet.dart';

class EpisodeListScreen extends ConsumerStatefulWidget {
  const EpisodeListScreen({super.key});

  @override
  ConsumerState<EpisodeListScreen> createState() => _EpisodeListScreenState();
}

class _EpisodeListScreenState extends ConsumerState<EpisodeListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<EpisodeOverview> _activeEpisodes = [];
  List<EpisodeOverview> _historyEpisodes = [];
  bool _isLoading = true;
  bool _loadFailed = false;

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

  /// Dönemleri yerel veritabanından okur. [showSpinner] kapalıysa (çek-bırak
  /// yenileme) mevcut liste ekranda kalır.
  Future<void> _loadEpisodes({bool showSpinner = true}) async {
    if (showSpinner) setState(() => _isLoading = true);
    try {
      final result = await ref.read(episodeOverviewLoaderProvider).load();
      if (!mounted) return;
      setState(() {
        _activeEpisodes = result.active;
        _historyEpisodes = result.history;
        _loadFailed = false;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadFailed = true;
        _isLoading = false;
      });
    }
  }

  /// Kapatma ekranını açar; kapatıldıysa listeyi yeniler ve haber verir.
  Future<void> _openClose(EpisodeOverview o) async {
    final closed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EpisodeCloseScreen(overview: o)),
    );
    if (closed != true || !mounted) return;
    await _loadEpisodes(showSpinner: false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).episodeClosed)),
    );
  }

  /// İlaç penceresini açar; kaydedildiyse haber verir (liste değişmez: kartta
  /// ilaç gösterilmiyor).
  Future<void> _openAddMedication(EpisodeOverview o) async {
    final saved = await showEpisodeMedicationSheet(
      context,
      episodeId: o.episode.id,
    );
    if (saved != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).episodeMedicationSaved)),
    );
  }

  String _moment(DateTime instant, int offsetMinutes) => formatEpisodeMoment(
        instant,
        offsetMinutes,
        ref.read(clockProvider)(),
        Localizations.localeOf(context).toString(),
      );

  String _locations(EpisodeOverview o, AppLocalizations l10n) {
    if (o.locations.isEmpty) return l10n.episodeNoLocation;
    return l10n.episodeLocation(o.locations.map((l) => l.location).join(', '));
  }

  Widget _buildActiveCard(EpisodeOverview o, AppLocalizations l10n) {
    final episode = o.episode;
    final start = _moment(episode.startTime, episode.startUtcOffsetMinutes);
    final severity = o.lastSeverity?.toString() ?? '-';

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
                    o.symptomName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l10n.episodeSeverity(severity)),
            Text(l10n.episodeStart(start)),
            Text(_locations(o, l10n)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.medication, size: 16),
                    label: Text(l10n.episodeAddMedication),
                    onPressed: () => _openAddMedication(o),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade400,
                    ),
                    onPressed: () => _openClose(o),
                    child: Text(
                      l10n.episodeClose,
                      style: const TextStyle(color: Colors.white),
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

  Widget _buildHistoryCard(EpisodeOverview o, AppLocalizations l10n) {
    final episode = o.episode;
    final start = _moment(episode.startTime, episode.startUtcOffsetMinutes);
    final ended = episode.endedAt;
    final end = ended == null
        ? '-'
        : _moment(ended, episode.endUtcOffsetMinutes ?? 0);
    final minutes = o.durationMinutes;
    final duration =
        minutes == null ? '' : formatEpisodeDuration(minutes, l10n);
    final notes = episode.resolutionNotes;

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
                    o.symptomName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l10n.episodeMaxSeverity(o.maxSeverity?.toString() ?? '-')),
            Text(l10n.episodeRange(start, end, duration)),
            Text(_locations(o, l10n)),
            if (notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '📝 $notes',
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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.episodesTitle),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.episodesTabActive),
            Tab(text: l10n.episodesTabHistory),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadFailed
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.episodesLoadError,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadEpisodes(showSpinner: false),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _activeEpisodes.isEmpty
                          ? Center(child: Text(l10n.episodesEmptyActive))
                          : ListView.builder(
                              itemCount: _activeEpisodes.length,
                              itemBuilder: (_, i) =>
                                  _buildActiveCard(_activeEpisodes[i], l10n),
                            ),
                      _historyEpisodes.isEmpty
                          ? Center(child: Text(l10n.episodesEmptyHistory))
                          : ListView.builder(
                              itemCount: _historyEpisodes.length,
                              itemBuilder: (_, i) =>
                                  _buildHistoryCard(_historyEpisodes[i], l10n),
                            ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadEpisodes,
        tooltip: l10n.episodesRefresh,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
