import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
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

  void _previousDay() =>
      _goToDate(_selectedDate.subtract(const Duration(days: 1)));

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
      '',
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık'
    ];
    if (_isToday) {
      return 'Bugün, ${_selectedDate.day} ${months[_selectedDate.month]}';
    }
    return '${_selectedDate.day} ${months[_selectedDate.month]} ${_selectedDate.year}';
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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: _closeFab,
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! < -300) _previousDay();
        if (details.primaryVelocity! > 300 && _isBeforeToday) _nextDay();
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 20,
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary400,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text('Sağlık Takibi'),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) => Navigator.pushNamed(context, value),
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: '/chronic-conditions',
                  child: Row(children: [
                    Icon(Icons.favorite,
                        color: AppColors.episode, size: 20),
                    const SizedBox(width: 10),
                    const Text('Kronik Hastalıklar'),
                  ]),
                ),
                PopupMenuItem(
                  value: '/recurring',
                  child: Row(children: [
                    Icon(Icons.repeat,
                        color: AppColors.medication, size: 20),
                    const SizedBox(width: 10),
                    const Text('Rutinler'),
                  ]),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            _buildDateBar(isDark),
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

  Widget _buildDateBar(bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1825) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.07),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left,
                color: colorScheme.onSurface.withValues(alpha: 0.5)),
            onPressed: _previousDay,
          ),
          Expanded(
            child: GestureDetector(
              onTap: _pickDate,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isToday)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: const BoxDecoration(
                            color: AppColors.primary400,
                            shape: BoxShape.circle,
                          ),
                        ),
                      Text(
                        _formatDisplayDate(),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _isToday
                              ? AppColors.primary400
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  if (!_isToday)
                    GestureDetector(
                      onTap: _goToToday,
                      child: const Text(
                        'Bugüne Dön',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primary400,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.primary400,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.chevron_right,
              color: _isBeforeToday
                  ? colorScheme.onSurface.withValues(alpha: 0.5)
                  : colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            onPressed: _isBeforeToday ? _nextDay : null,
          ),
        ],
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
                color: AppColors.daily,
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
                color: AppColors.medication,
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
                color: AppColors.symptom,
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
                color: AppColors.episode,
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
          backgroundColor: AppColors.primary400,
          foregroundColor: Colors.white,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1825) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.07),
              width: 0.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 8),
        FloatingActionButton.small(
          heroTag: label,
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          onPressed: onPressed,
          child: Icon(icon, size: 20),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primary400),
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 52, color: AppColors.primary200),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
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
      return Center(
        child: CircularProgressIndicator(color: AppColors.primary400),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary400,
      onRefresh: () async {
        await _fetchTimeline();
        await _fetchActiveEpisodes();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        children: [
          if (_activeEpisodes.isNotEmpty) ...[
            _buildActiveEpisodesSection(),
            const SizedBox(height: 12),
          ],
          _buildDailyLogCard(),
          const SizedBox(height: 12),
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
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: AppColors.episode,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'Aktif Ataklar',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.episode,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.episodeBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_activeEpisodes.length}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.episode,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A1825) : AppColors.episodeBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.episode.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.episode.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: AppColors.episode, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    episode['symptom_name'],
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$startTime\'den beri devam ediyor',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5)),
                  ),
                  if (locations.isNotEmpty)
                    Text(
                      locations,
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5)),
                    ),
                ],
              ),
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.episode.withValues(alpha: 0.12),
                foregroundColor: AppColors.episode,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
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

  String _formatTime(String isoString) {
    final dt = DateTime.parse(isoString).toLocal();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildDailyLogCard() {
    final dailyLog = _timelineData?['daily_log'];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (dailyLog == null) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1825) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.07),
            width: 0.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              await Navigator.pushNamed(context, '/daily-log');
              _fetchTimeline();
            },
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(
                    width: 4,
                    decoration: const BoxDecoration(
                      color: AppColors.primary400,
                      borderRadius:
                          BorderRadius.horizontal(left: Radius.circular(16)),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: AppColors.primary50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.edit_note,
                                color: AppColors.primary600, size: 20),
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
                                SizedBox(height: 2),
                                Text(
                                  'Bugünkü durumunu kaydet',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios,
                              size: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.3)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final mood = _parseInt(dailyLog['mood']);
    final energy = _parseInt(dailyLog['energy_level']);
    final sleep = _parseDouble(dailyLog['sleep_hours']);
    final water = _parseDouble(dailyLog['water_intake']);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1825) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.07),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 4,
                decoration: const BoxDecoration(
                  color: AppColors.primary400,
                  borderRadius:
                      BorderRadius.horizontal(left: Radius.circular(16)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppColors.primary50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.assignment,
                                color: AppColors.primary600, size: 18),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Günlük Özet',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () async {
                              await Navigator.pushNamed(context, '/daily-log');
                              _fetchTimeline();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primary50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.edit_outlined,
                                  size: 14, color: AppColors.primary600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
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
                          const SizedBox(width: 10),
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
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoTile(
                              icon: Icons.bedtime_outlined,
                              iconColor: AppColors.primary600,
                              label: 'Uyku',
                              value: '$sleep saat',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildInfoTile(
                              icon: Icons.water_drop_outlined,
                              iconColor: AppColors.medication,
                              label: 'Su',
                              value: '$water L',
                            ),
                          ),
                        ],
                      ),
                      if (dailyLog['notes'] != null &&
                          (dailyLog['notes'] as String).isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Divider(
                            height: 1,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.08)),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.notes,
                                size: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.4)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                dailyLog['notes'],
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? color.withValues(alpha: 0.12)
            : color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5))),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor:
                  Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 5),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5))),
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
        padding: const EdgeInsets.only(top: 32),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.health_and_safety_outlined,
                size: 36,
                color: AppColors.primary400,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Bu gün için kayıt yok',
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Semptom veya ilaç eklemek için + düğmesini kullan',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4)),
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
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'Günlük Aktiviteler',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Container(
                      width: 2,
                      decoration: BoxDecoration(
                        color: AppColors.symptom.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1825) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.symptom.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Container(
                          width: 3,
                          color: AppColors.symptom,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: AppColors.symptomBg,
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                      child: const Icon(Icons.sick,
                                          color: AppColors.symptom, size: 14),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        entry['symptom_name'],
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14),
                                      ),
                                    ),
                                    _buildSeverityBadge(severity),
                                  ],
                                ),
                                if (entry['notes'] != null &&
                                    (entry['notes'] as String).isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    entry['notes'],
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.5)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
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
    Color bgColor;
    if (severity <= 3) {
      color = AppColors.severityLow;
      bgColor = AppColors.dailyBg;
    } else if (severity <= 6) {
      color = AppColors.severityMid;
      bgColor = AppColors.symptomBg;
    } else {
      color = AppColors.severityHigh;
      bgColor = AppColors.episodeBg;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        '$severity/10',
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Container(
                      width: 2,
                      decoration: BoxDecoration(
                        color: AppColors.medication.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1825) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.medication.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Container(
                          width: 3,
                          color: AppColors.medication,
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: AppColors.medicationBg,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: const Icon(Icons.medication,
                                      color: AppColors.medication, size: 14),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${log['medication_name']}$dose',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14),
                                      ),
                                      const SizedBox(height: 3),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isChronic
                                              ? AppColors.primary50
                                              : AppColors.dailyBg,
                                          borderRadius:
                                              BorderRadius.circular(5),
                                        ),
                                        child: Text(
                                          isChronic
                                              ? 'Kronik'
                                              : 'Semptomatik',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: isChronic
                                                ? AppColors.primary600
                                                : AppColors.daily,
                                          ),
                                        ),
                                      ),
                                      if (log['notes'] != null &&
                                          (log['notes'] as String).isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 3),
                                          child: Text(
                                            log['notes'] as String,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.5)),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
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