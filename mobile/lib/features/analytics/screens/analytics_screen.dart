import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../analytics_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/parse_utils.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  final AnalyticsService _service = AnalyticsService();

  late TabController _tabController;
  int _selectedDays = 7;

  Map<String, dynamic>? _symptomData;
  Map<String, dynamic>? _dailyData;
  Map<String, dynamic>? _medicationEffectData;
  Map<String, dynamic>? _adherenceData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _fetchAll();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    _fetchForTab(_tabController.index);
  }

  void _fetchAll() {
    _fetchSymptoms();
    _fetchDaily();
    _fetchMedEffect();
    _fetchAdherence();
  }

  Future<void> _fetchSymptoms() async {
    try {
      final data = await _service.getSymptomAnalytics(_selectedDays);
      setState(() => _symptomData = data['data']);
    } catch (_) {}
  }

  Future<void> _fetchDaily() async {
    try {
      final data = await _service.getDailyTrends(_selectedDays);
      setState(() => _dailyData = data['data']);
    } catch (_) {}
  }

  Future<void> _fetchMedEffect() async {
    try {
      final data = await _service.getMedicationEffect(_selectedDays);
      setState(() => _medicationEffectData = data['data']);
    } catch (_) {}
  }

  Future<void> _fetchAdherence() async {
    try {
      final data = await _service.getMedicationAdherence(_selectedDays);
      setState(() => _adherenceData = data['data']);
    } catch (_) {}
  }

  void _fetchForTab(int index) {
    switch (index) {
      case 0: _fetchSymptoms(); break;
      case 1: _fetchDaily(); break;
      case 2: _fetchMedEffect(); break;
      case 3: _fetchAdherence(); break;
    }
  }

  void _onDaysChanged(int days) {
    setState(() {
      _selectedDays = days;
      _symptomData = null;
      _dailyData = null;
      _medicationEffectData = null;
      _adherenceData = null;
    });
    _fetchAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analizler'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary400,
          labelColor: AppColors.primary400,
          unselectedLabelColor:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Semptomlar'),
            Tab(text: 'Günlük'),
            Tab(text: 'İlaç Etkisi'),
            Tab(text: 'Uyum'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildDaysSelector(isDark),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSymptomsTab(isDark),
                _buildDailyTab(isDark),
                _buildMedEffectTab(isDark),
                _buildAdherenceTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [7, 30, 90].map((days) {
          final selected = _selectedDays == days;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _onDaysChanged(days),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary400
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$days Gün',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- SEMPTOMLAR ---
  Widget _buildSymptomsTab(bool isDark) {
    if (_symptomData == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary400));
    }

    final frequency = List<Map<String, dynamic>>.from(
        _symptomData!['symptom_frequency'] ?? []);
    final trend = List<Map<String, dynamic>>.from(
        _symptomData!['severity_trend'] ?? []);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('Semptom Sıklığı'),
        const SizedBox(height: 8),
        if (frequency.isEmpty)
          _emptyCard('Bu dönemde semptom kaydı yok', isDark)
        else
          _buildFrequencyBars(frequency, isDark),
        const SizedBox(height: 20),
        _sectionTitle('Günlük Ortalama Şiddet'),
        const SizedBox(height: 8),
        if (trend.isEmpty)
          _emptyCard('Yeterli veri yok', isDark)
        else
          _buildSeverityTrendChart(trend, isDark),
      ],
    );
  }

  Widget _buildFrequencyBars(
      List<Map<String, dynamic>> data, bool isDark) {
    final maxCount = data
        .map((e) => parseInt(e['count']))
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    return _card(
      isDark: isDark,
      child: Column(
        children: data.map((item) {
          final count = parseInt(item['count']);
          final avgSev = item['avg_severity'];
          final progress = count / maxCount;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(item['symptom_name'],
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 14)),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.symptomBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('$count kez',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.symptom)),
                        ),
                        const SizedBox(width: 6),
                        Text('Ort: $avgSev',
                            style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.4))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppColors.symptom.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.symptom),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSeverityTrendChart(
      List<Map<String, dynamic>> trend, bool isDark) {
    final spots = trend.asMap().entries.map((e) {
      return FlSpot(
          e.key.toDouble(), parseDouble(e.value['avg_severity']));
    }).toList();

    return _card(
      isDark: isDark,
      child: SizedBox(
        height: 180,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              getDrawingHorizontalLine: (value) => FlLine(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.07),
                strokeWidth: 0.5,
              ),
              drawVerticalLine: false,
            ),
            borderData: FlBorderData(show: false),
            minY: 0,
            maxY: 10,
            titlesData: _buildTitlesData(trend, 'date'),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: AppColors.episode,
                barWidth: 2.5,
                dotData: FlDotData(
                  getDotPainter: (spot, percent, bar, index) =>
                      FlDotCirclePainter(
                    radius: 4,
                    color: AppColors.episode,
                    strokeWidth: 0,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.episode.withValues(alpha: 0.08),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- GÜNLÜK ---
  Widget _buildDailyTab(bool isDark) {
    if (_dailyData == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary400));
    }

    final trends =
        List<Map<String, dynamic>>.from(_dailyData!['trends'] ?? []);
    final averages =
        (_dailyData!['averages'] as Map<String, dynamic>?) ?? {};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('Ortalamalar (Son $_selectedDays Gün)'),
        const SizedBox(height: 8),
        _buildAveragesCard(averages, isDark),
        const SizedBox(height: 20),
        _sectionTitle('Mood & Enerji Trendi'),
        const SizedBox(height: 8),
        if (trends.isEmpty)
          _emptyCard('Bu dönemde günlük kayıt yok', isDark)
        else
          _buildDailyTrendChart(trends, isDark),
      ],
    );
  }

  Widget _buildAveragesCard(Map<String, dynamic> avgs, bool isDark) {
    final items = [
      {'emoji': '😴', 'label': 'Uyku', 'value': '${avgs['sleep_hours'] ?? '-'} saat', 'color': AppColors.primary400},
      {'emoji': '💧', 'label': 'Su', 'value': '${avgs['water_intake'] ?? '-'} litre', 'color': AppColors.medication},
      {'emoji': '😊', 'label': 'Mood', 'value': '${avgs['mood'] ?? '-'} / 5', 'color': Colors.green},
      {'emoji': '⚡', 'label': 'Enerji', 'value': '${avgs['energy_level'] ?? '-'} / 5', 'color': Colors.amber},
    ];

    return _card(
      isDark: isDark,
      child: Column(
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: (item['color'] as Color).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(item['emoji'] as String,
                        style: const TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 12),
                Text(item['label'] as String,
                    style: const TextStyle(fontSize: 14)),
                const Spacer(),
                Text(item['value'] as String,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: item['color'] as Color)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDailyTrendChart(
      List<Map<String, dynamic>> trends, bool isDark) {
    final moodSpots = <FlSpot>[];
    final energySpots = <FlSpot>[];

    for (int i = 0; i < trends.length; i++) {
      final mood = trends[i]['mood'];
      final energy = trends[i]['energy_level'];
      if (mood != null)
        moodSpots.add(FlSpot(i.toDouble(), parseDouble(mood)));
      if (energy != null)
        energySpots.add(FlSpot(i.toDouble(), parseDouble(energy)));
    }

    return _card(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _legend(AppColors.primary400, 'Mood'),
            const SizedBox(width: 16),
            _legend(Colors.amber, 'Enerji'),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.07),
                    strokeWidth: 0.5,
                  ),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: 5,
                titlesData: _buildTitlesData(trends, 'date'),
                lineBarsData: [
                  LineChartBarData(
                    spots: moodSpots,
                    isCurved: true,
                    color: AppColors.primary400,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                        radius: 4,
                        color: AppColors.primary400,
                        strokeWidth: 0,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary400.withValues(alpha: 0.06),
                    ),
                  ),
                  LineChartBarData(
                    spots: energySpots,
                    isCurved: true,
                    color: Colors.amber,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                        radius: 4,
                        color: Colors.amber,
                        strokeWidth: 0,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.amber.withValues(alpha: 0.06),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- İLAÇ ETKİSİ ---
  Widget _buildMedEffectTab(bool isDark) {
    if (_medicationEffectData == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary400));
    }

    final effects = List<Map<String, dynamic>>.from(
        _medicationEffectData!['effects'] ?? []);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('İlaç Öncesi / Sonrası Şiddet'),
        const SizedBox(height: 8),
        if (effects.isEmpty)
          _emptyCard('Bu dönemde ilaç-semptom eşleşmesi yok', isDark)
        else
          ...effects.map((e) => _buildMedEffectCard(e, isDark)),
      ],
    );
  }

  Widget _buildMedEffectCard(Map<String, dynamic> effect, bool isDark) {
    final before = parseDouble(effect['avg_severity_before']);
    final after = parseDouble(effect['avg_severity_after']);
    final relief = effect['avg_relief_minutes'];
    final diff = before - after;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _card(
        isDark: isDark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(effect['medication_name'],
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      Text('${effect['usage_count']} kez kullanıldı',
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.4))),
                    ],
                  ),
                ),
                if (diff > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.dailyBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '-${diff.toStringAsFixed(1)}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.daily),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _effectBar('Önce', before, AppColors.episode, isDark),
            const SizedBox(height: 8),
            _effectBar('Sonra', after, AppColors.daily, isDark),
            if (relief != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.timer_outlined,
                      size: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4)),
                  const SizedBox(width: 4),
                  Text('Ortalama etki: $relief dakika',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _effectBar(String label, double value, Color color, bool isDark) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5))),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: value / 10,
              minHeight: 10,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(value.toStringAsFixed(1),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color)),
      ],
    );
  }

  // --- UYUM ---
  Widget _buildAdherenceTab(bool isDark) {
    if (_adherenceData == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary400));
    }

    final adherence = List<Map<String, dynamic>>.from(
        _adherenceData!['adherence'] ?? []);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('Rutin İlaç Uyumu'),
        const SizedBox(height: 8),
        if (adherence.isEmpty)
          _emptyCard(
              'Rutin ilaç tanımlanmamış veya bu dönemde veri yok', isDark)
        else
          ...adherence.map((e) => _buildAdherenceCard(e, isDark)),
      ],
    );
  }

  Widget _buildAdherenceCard(Map<String, dynamic> item, bool isDark) {
    final rate = parseDouble(item['adherence_rate']);
    final color = rate >= 80
        ? AppColors.daily
        : rate >= 50
            ? AppColors.symptom
            : AppColors.episode;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _card(
        isDark: isDark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item['medication_name'],
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${rate.toInt()}%',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: color,
                          fontSize: 14)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: rate / 100,
                minHeight: 10,
                backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${item['taken_days']} / ${item['expected_days']} gün · ${item['missed_days']} gün atlandı',
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4)),
            ),
          ],
        ),
      ),
    );
  }

  // --- YARDIMCI ---
  FlTitlesData _buildTitlesData(
      List<Map<String, dynamic>> data, String dateKey) {
    return FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          getTitlesWidget: (value, meta) {
            final idx = value.toInt();
            if (idx < 0 || idx >= data.length) return const SizedBox();
            final parts = (data[idx][dateKey] as String).split('-');
            return Text('${parts[2]}/${parts[1]}',
                style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4)));
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          getTitlesWidget: (value, meta) => Text(
              value.toInt().toString(),
              style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4))),
        ),
      ),
      rightTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(children: [
      Container(
          width: 10,
          height: 10,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: Theme.of(context)
            .colorScheme
            .onSurface
            .withValues(alpha: 0.4),
      ),
    );
  }

  Widget _emptyCard(String message, bool isDark) {
    return _card(
      isDark: isDark,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.primary50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bar_chart,
                    color: AppColors.primary400, size: 24),
              ),
              const SizedBox(height: 10),
              Text(message,
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4)),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child, required bool isDark}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: child,
    );
  }
}