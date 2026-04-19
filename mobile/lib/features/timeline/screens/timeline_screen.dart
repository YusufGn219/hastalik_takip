import 'package:flutter/material.dart';
import '../../timeline/timeline_service.dart';
import '../../episode/episode_service.dart';
import '../../episode/screens/episode_list_screen.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen>
    with SingleTickerProviderStateMixin {
  final TimelineService _timelineService = TimelineService();
  final EpisodeService _episodeService = EpisodeService();
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic>? _timelineData;
  List<dynamic> _activeEpisodes = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _fabExpanded = false;
  late AnimationController _fabAnimController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimController,
      curve: Curves.easeInOut,
    );
    _fetchTimeline();
    _fetchActiveEpisodes();
  }

  @override
  void dispose() {
    _fabAnimController.dispose();
    super.dispose();
  }

  Future<void> _fetchTimeline() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final dateStr =
          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
      final data = await _timelineService.getTimeline(dateStr);
      setState(() => _timelineData = data['data']);
    } catch (e) {
      setState(() => _errorMessage = 'Veri yüklenemedi');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchActiveEpisodes() async {
    try {
      final episodes = await _episodeService.getActiveEpisodes();
      setState(() => _activeEpisodes = episodes);
    } catch (_) {}
  }

  void _goToDate(DateTime date) {
    setState(() => _selectedDate = date);
    _fetchTimeline();
  }

  void _previousDay() => _goToDate(_selectedDate.subtract(const Duration(days: 1)));

  void _nextDay() {
    if (_isBeforeToday) _goToDate(_selectedDate.add(const Duration(days: 1)));
  }

  void _goToToday() => _goToDate(DateTime.now());

  bool get _isBeforeToday {
    final now = DateTime.now();
    return _selectedDate.year < now.year ||
        _selectedDate.month < now.month ||
        _selectedDate.day < now.day;
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) _goToDate(picked);
  }

  void _toggleFab() {
    setState(() => _fabExpanded = !_fabExpanded);
    if (_fabExpanded) {
      _fabAnimController.forward();
    } else {
      _fabAnimController.reverse();
    }
  }

  void _closeFab() {
    if (_fabExpanded) {
      setState(() => _fabExpanded = false);
      _fabAnimController.reverse();
    }
  }

  String _formatDisplayDate() {
    const months = [
      '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    if (_isToday) return 'Bugün, ${_selectedDate.day} ${months[_selectedDate.month]}';
    return '${_selectedDate.day} ${months[_selectedDate.month]} ${_selectedDate.year}';
  }

  String _formatTime(String isoString) {
    final dt = DateTime.parse(isoString).toLocal();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String _moodEmoji(int mood) {
    const emojis = ['', '😞', '😕', '😐', '🙂', '😊'];
    return mood >= 1 && mood <= 5 ? emojis[mood] : '?';
  }

  String _energyLabel(int energy) {
    const labels = ['', 'Çok Düşük', 'Düşük', 'Orta', 'İyi', 'Yüksek'];
    return energy >= 1 && energy <= 5 ? labels[energy] : '?';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _closeFab,
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! < -300) _previousDay();
        if (details.primaryVelocity! > 300 && _isBeforeToday) _nextDay();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sağlık Takibi'),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) => Navigator.pushNamed(context, value),
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: '/chronic-conditions',
                  child: Row(children: [
                    Icon(Icons.favorite, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Kronik Hastalıklar'),
                  ]),
                ),
                const PopupMenuItem(
                  value: '/recurring',
                  child: Row(children: [
                    Icon(Icons.repeat, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Rutinler'),
                  ]),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            _buildDateBar(),
            Expanded(child: _buildBody()),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: 0,
          onDestinationSelected: (index) {
            _closeFab();
            if (index == 1) Navigator.pushNamed(context, '/analytics');
            if (index == 2) Navigator.pushNamed(context, '/profile');
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Ana Ekran',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Analizler',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
        floatingActionButton: _buildExpandableFab(),
      ),
    );
  }

  Widget _buildExpandableFab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ScaleTransition(
          scale: _fabAnimation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildMiniFab(
                icon: Icons.edit_note,
                label: 'Günlük Kayıt',
                color: Colors.green,
                onPressed: () async {
                  _closeFab();
                  await Navigator.pushNamed(context, '/daily-log');
                  _fetchTimeline();
                },
              ),
              const SizedBox(height: 8),
              _buildMiniFab(
                icon: Icons.medication,
                label: 'İlaç Al',
                color: Colors.blue,
                onPressed: () async {
                  _closeFab();
                  await Navigator.pushNamed(context, '/medication-log');
                  _fetchTimeline();
                },
              ),
              const SizedBox(height: 8),
              _buildMiniFab(
                icon: Icons.medical_services,
                label: 'Semptom Ekle',
                color: Colors.orange,
                onPressed: () async {
                  _closeFab();
                  await Navigator.pushNamed(context, '/symptoms');
                  _fetchTimeline();
                  _fetchActiveEpisodes();
                },
              ),
              const SizedBox(height: 8),
              _buildMiniFab(
                icon: Icons.crisis_alert,
                label: 'Ataklar',
                color: Colors.red,
                onPressed: () async {
                  _closeFab();
                  await Navigator.pushNamed(context, '/episodes');
                  _fetchActiveEpisodes();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        FloatingActionButton(
          onPressed: _toggleFab,
          child: AnimatedRotation(
            turns: _fabExpanded ? 0.125 : 0,
            duration: const Duration(milliseconds: 220),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniFab({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
        const SizedBox(width: 8),
        FloatingActionButton.small(
          heroTag: label,
          backgroundColor: color,
          foregroundColor: Colors.white,
          onPressed: onPressed,
          child: Icon(icon, size: 20),
        ),
      ],
    );
  }

  Widget _buildDateBar() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      color: colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _previousDay,
          ),
          Expanded(
            child: GestureDetector(
              onTap: _pickDate,
              child: Column(
                children: [
                  Text(
                    _formatDisplayDate(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _isToday ? colorScheme.primary : null,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (!_isToday)
                    GestureDetector(
                      onTap: _goToToday,
                      child: Text(
                        'Bugüne Dön',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _isBeforeToday ? _nextDay : null,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(_errorMessage!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _fetchTimeline,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }
    if (_timelineData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchTimeline();
        await _fetchActiveEpisodes();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          if (_activeEpisodes.isNotEmpty) ...[
            _buildActiveEpisodesSection(),
            const SizedBox(height: 16),
          ],
          _buildDailyLogCard(),
          const SizedBox(height: 16),
          _buildTimelineItems(),
        ],
      ),
    );
  }

  Widget _buildActiveEpisodesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'Aktif Ataklar',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_activeEpisodes.length}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._activeEpisodes.map((episode) => _buildActiveEpisodeCard(episode)),
      ],
    );
  }

  Widget _buildActiveEpisodeCard(Map<String, dynamic> episode) {
    final startTime = _formatTime(episode['start_time']);
    final locations = (episode['locations'] as List<dynamic>? ?? [])
        .map((l) => l['location'] as String)
        .join(', ');

    return Card(
      color: Colors.red.shade50,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    episode['symptom_name'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$startTime\'den beri devam ediyor',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  if (locations.isNotEmpty)
                    Text(
                      locations,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade100,
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EpisodeListScreen()),
                );
                _fetchActiveEpisodes();
              },
              child: const Text('Kapat', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyLogCard() {
    final dailyLog = _timelineData?['daily_log'];

    if (dailyLog == null) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            await Navigator.pushNamed(context, '/daily-log');
            _fetchTimeline();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit_note, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Günlük Kayıt Girilmedi',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Bugünkü durumunu kaydet',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
              ],
            ),
          ),
        ),
      );
    }

    final mood = _parseInt(dailyLog['mood']);
    final energy = _parseInt(dailyLog['energy_level']);
    final sleep = _parseDouble(dailyLog['sleep_hours']);
    final water = _parseDouble(dailyLog['water_intake']);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Günlük Özet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    await Navigator.pushNamed(context, '/daily-log');
                    _fetchTimeline();
                  },
                  child: const Icon(Icons.edit_outlined, size: 16, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Ruh hali ve enerji
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    emoji: _moodEmoji(mood),
                    label: 'Ruh Hali',
                    value: '$mood/5',
                    progress: mood / 5,
                    color: _moodColor(mood),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    emoji: '⚡',
                    label: 'Enerji',
                    value: _energyLabel(energy),
                    progress: energy / 5,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Uyku ve su
            Row(
              children: [
                Expanded(
                  child: _buildInfoTile(
                    icon: Icons.bedtime_outlined,
                    iconColor: Colors.indigo,
                    label: 'Uyku',
                    value: '$sleep saat',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoTile(
                    icon: Icons.water_drop_outlined,
                    iconColor: Colors.blue,
                    label: 'Su',
                    value: '$water L',
                  ),
                ),
              ],
            ),
            if (dailyLog['notes'] != null &&
                (dailyLog['notes'] as String).isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      dailyLog['notes'],
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _moodColor(int mood) {
    if (mood <= 1) return Colors.red;
    if (mood == 2) return Colors.orange;
    if (mood == 3) return Colors.amber;
    if (mood == 4) return Colors.lightGreen;
    return Colors.green;
  }

  Widget _buildMetricTile({
    required String emoji,
    required String label,
    required String value,
    required double progress,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 4),
          Text(value,
              style:
                  TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItems() {
    final symptomEntries = (_timelineData?['symptom_entries'] as List? ?? [])
        .map((e) => {'type': 'symptom', 'time': e['timestamp'], 'data': e})
        .toList();

    final medicationLogs = (_timelineData?['medication_logs'] as List? ?? [])
        .map((e) => {'type': 'medication', 'time': e['taken_at'], 'data': e})
        .toList();

    final allItems = [...symptomEntries, ...medicationLogs];
    allItems.sort((a, b) => DateTime.parse(a['time'] as String)
        .compareTo(DateTime.parse(b['time'] as String)));

    if (allItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          children: [
            Icon(Icons.health_and_safety_outlined,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'Bu gün için kayıt yok',
              style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Text(
              'Semptom veya ilaç eklemek için + düğmesini kullan',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Günlük Aktiviteler',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600),
          ),
        ),
        ...allItems.map((item) {
          if (item['type'] == 'symptom') {
            return _buildSymptomCard(item['data'] as Map<String, dynamic>);
          } else {
            return _buildMedicationCard(item['data'] as Map<String, dynamic>);
          }
        }),
      ],
    );
  }

  Widget _buildSymptomCard(Map<String, dynamic> entry) {
    final timestamp = DateTime.parse(entry['timestamp']).toLocal();
    final timeStr =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    final severity = _parseInt(entry['severity']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 44,
              child: Column(
                children: [
                  Text(timeStr,
                      style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Container(
                      width: 1,
                      color: Colors.orange.shade200,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.orange.shade100),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.sick,
                              color: Colors.orange, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              entry['symptom_name'],
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          _buildSeverityBadge(severity),
                        ],
                      ),
                      if (entry['notes'] != null &&
                          (entry['notes'] as String).isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          entry['notes'],
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeverityBadge(int severity) {
    Color color;
    if (severity <= 3) {
      color = Colors.green;
    } else if (severity <= 6) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$severity/10',
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildMedicationCard(Map<String, dynamic> log) {
    final timestamp = DateTime.parse(log['taken_at']).toLocal();
    final timeStr =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    final dose = log['dose_amount'] != null
        ? ' ${log['dose_amount']} ${log['dose_unit']}'
        : '';
    final isChronic = log['medication_type'] == 'chronic';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 44,
              child: Column(
                children: [
                  Text(timeStr,
                      style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Container(
                      width: 1,
                      color: Colors.blue.shade200,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Card(
                margin: EdgeInsets.zero,
                color: Colors.blue.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.blue.shade100),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.medication,
                          color: Colors.blue, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${log['medication_name']}$dose',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isChronic
                                        ? Colors.purple.shade50
                                        : Colors.teal.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isChronic ? 'Kronik' : 'Semptomatik',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isChronic
                                          ? Colors.purple
                                          : Colors.teal,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (log['notes'] != null &&
                                (log['notes'] as String).isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  log['notes'] as String,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
