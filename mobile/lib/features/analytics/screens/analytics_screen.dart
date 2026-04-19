// mobile/lib/features/analytics/screens/analytics_screen.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../analytics_service.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analizler'),
        bottom: TabBar(
          controller: _tabController,
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
          _buildDaysSelector(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSymptomsTab(),
                _buildDailyTab(),
                _buildMedEffectTab(),
                _buildAdherenceTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [7, 30, 90].map((days) {
          final selected = _selectedDays == days;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text('$days Gün'),
              selected: selected,
              onSelected: (_) => _onDaysChanged(days),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- SEMPTOMLAR ---
  Widget _buildSymptomsTab() {
    if (_symptomData == null) return const Center(child: CircularProgressIndicator());

    final frequency = List<Map<String, dynamic>>.from(
        _symptomData!['symptom_frequency'] ?? []);
    final trend = List<Map<String, dynamic>>.from(
        _symptomData!['severity_trend'] ?? []);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('Semptom Sıklığı'),
        if (frequency.isEmpty)
          _emptyCard('Bu dönemde semptom kaydı yok')
        else
          _buildFrequencyBars(frequency),
        const SizedBox(height: 24),
        _sectionTitle('Günlük Ortalama Şiddet'),
        if (trend.isEmpty)
          _emptyCard('Yeterli veri yok')
        else
          _buildSeverityTrendChart(trend),
      ],
    );
  }

  Widget _buildFrequencyBars(List<Map<String, dynamic>> data) {
    final maxCount = data
        .map((e) => parseInt(e['count']))
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: data.map((item) {
            final count = parseInt(item['count']);
            final avgSev = item['avg_severity'];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(item['symptom_name'],
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text('$count kez · Ort: $avgSev',
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: count / maxCount,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                    backgroundColor: Colors.grey.shade200,
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSeverityTrendChart(List<Map<String, dynamic>> trend) {
    final spots = trend.asMap().entries.map((e) {
      return FlSpot(
          e.key.toDouble(), parseDouble(e.value['avg_severity']));
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: true),
              minY: 0,
              maxY: 10,
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= trend.length) return const SizedBox();
                      final parts = (trend[idx]['date'] as String).split('-');
                      return Text('${parts[2]}/${parts[1]}',
                          style: const TextStyle(fontSize: 10));
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(fontSize: 10)),
                  ),
                ),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Colors.red.shade400,
                  barWidth: 2,
                  dotData: const FlDotData(show: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- GÜNLÜK ---
  Widget _buildDailyTab() {
    if (_dailyData == null) return const Center(child: CircularProgressIndicator());

    final trends = List<Map<String, dynamic>>.from(_dailyData!['trends'] ?? []);
    final averages = (_dailyData!['averages'] as Map<String, dynamic>?) ?? {};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('Ortalamalar (Son $_selectedDays Gün)'),
        _buildAveragesCard(averages),
        const SizedBox(height: 24),
        _sectionTitle('Mood & Enerji Trendi'),
        if (trends.isEmpty)
          _emptyCard('Bu dönemde günlük kayıt yok')
        else
          _buildDailyTrendChart(trends),
      ],
    );
  }

  Widget _buildAveragesCard(Map<String, dynamic> avgs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _avgRow('😴 Uyku', '${avgs['sleep_hours'] ?? '-'} saat'),
            _avgRow('💧 Su', '${avgs['water_intake'] ?? '-'} litre'),
            _avgRow('😊 Mood', '${avgs['mood'] ?? '-'} / 5'),
            _avgRow('⚡ Enerji', '${avgs['energy_level'] ?? '-'} / 5'),
          ],
        ),
      ),
    );
  }

  Widget _avgRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildDailyTrendChart(List<Map<String, dynamic>> trends) {
    final moodSpots = <FlSpot>[];
    final energySpots = <FlSpot>[];

    for (int i = 0; i < trends.length; i++) {
      final mood = trends[i]['mood'];
      final energy = trends[i]['energy_level'];
      if (mood != null) moodSpots.add(FlSpot(i.toDouble(), parseDouble(mood)));
      if (energy != null) energySpots.add(FlSpot(i.toDouble(), parseDouble(energy)));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _legend(Colors.blue, 'Mood'),
              const SizedBox(width: 16),
              _legend(Colors.orange, 'Enerji'),
            ]),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  minY: 0,
                  maxY: 5,
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= trends.length) return const SizedBox();
                          final parts = (trends[idx]['date'] as String).split('-');
                          return Text('${parts[2]}/${parts[1]}',
                              style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) => Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10)),
                      ),
                    ),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: moodSpots,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 2,
                      dotData: const FlDotData(show: true),
                    ),
                    LineChartBarData(
                      spots: energySpots,
                      isCurved: true,
                      color: Colors.orange,
                      barWidth: 2,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(children: [
      Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12)),
    ]);
  }

  // --- İLAÇ ETKİSİ ---
  Widget _buildMedEffectTab() {
    if (_medicationEffectData == null)
      return const Center(child: CircularProgressIndicator());

    final effects = List<Map<String, dynamic>>.from(
        _medicationEffectData!['effects'] ?? []);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('İlaç Öncesi / Sonrası Şiddet'),
        if (effects.isEmpty)
          _emptyCard('Bu dönemde ilaç-semptom eşleşmesi yok')
        else
          ...effects.map((e) => _buildMedEffectCard(e)),
      ],
    );
  }

  Widget _buildMedEffectCard(Map<String, dynamic> effect) {
    final before = parseDouble(effect['avg_severity_before']);
    final after = parseDouble(effect['avg_severity_after']);
    final relief = effect['avg_relief_minutes'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(effect['medication_name'],
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            Text('${effect['usage_count']} kez kullanıldı',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            _effectBar('Önce', before, Colors.red.shade300),
            const SizedBox(height: 6),
            _effectBar('Sonra', after, Colors.green.shade400),
            if (relief != null) ...[
              const SizedBox(height: 8),
              Text('Ortalama etki süresi: $relief dakika',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ]
          ],
        ),
      ),
    );
  }

  Widget _effectBar(String label, double value, Color color) {
    return Row(
      children: [
        SizedBox(
            width: 48,
            child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(
          child: LinearProgressIndicator(
            value: value / 10,
            minHeight: 10,
            borderRadius: BorderRadius.circular(5),
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(width: 8),
        Text(value.toString(),
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // --- UYUM ---
  Widget _buildAdherenceTab() {
    if (_adherenceData == null)
      return const Center(child: CircularProgressIndicator());

    final adherence = List<Map<String, dynamic>>.from(
        _adherenceData!['adherence'] ?? []);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('Rutin İlaç Uyumu'),
        if (adherence.isEmpty)
          _emptyCard('Rutin ilaç tanımlanmamış veya bu dönemde veri yok')
        else
          ...adherence.map((e) => _buildAdherenceCard(e)),
      ],
    );
  }

  Widget _buildAdherenceCard(Map<String, dynamic> item) {
    final rate = parseDouble(item['adherence_rate']);
    final color = rate >= 80
        ? Colors.green
        : rate >= 50
            ? Colors.orange
            : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item['medication_name'],
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                Text('${rate.toInt()}%',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: rate / 100,
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
            const SizedBox(height: 6),
            Text(
              '${item['taken_days']} / ${item['expected_days']} gün · ${item['missed_days']} gün atlandı',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // --- YARDIMCI ---
  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  Widget _emptyCard(String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(message,
              style: const TextStyle(color: Colors.grey)),
        ),
      ),
    );
  }
}