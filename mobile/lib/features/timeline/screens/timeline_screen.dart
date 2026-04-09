import 'package:flutter/material.dart';
import '../../timeline/timeline_service.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final TimelineService _timelineService = TimelineService();
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic>? _timelineData;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchTimeline();
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
      setState(() {
        _timelineData = data['data'];
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Veri yüklenemedi';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _previousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
    _fetchTimeline();
  }

  void _nextDay() {
    if (_selectedDate.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
      setState(() {
        _selectedDate = _selectedDate.add(const Duration(days: 1));
      });
      _fetchTimeline();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchTimeline();
    }
  }

  String _formatDisplayDate() {
    const months = [
      '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    return '${_selectedDate.day} ${months[_selectedDate.month]} ${_selectedDate.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sağlık Takibi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: 'Günlük Kayıt',
            onPressed: () => Navigator.pushNamed(context, '/daily-log'),
          ),
          IconButton(
            icon: const Icon(Icons.medical_services),
            tooltip: 'Semptom Ekle',
            onPressed: () => Navigator.pushNamed(context, '/symptoms'),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDateBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildDateBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _previousDay,
          ),
          GestureDetector(
            onTap: _pickDate,
            child: Text(
              _formatDisplayDate(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _selectedDate.isBefore(
                    DateTime.now().subtract(const Duration(days: 1)))
                ? _nextDay
                : null,
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
      return Center(child: Text(_errorMessage!));
    }
    if (_timelineData == null) {
      return const Center(child: Text('Veri yok'));
    }

    return RefreshIndicator(
      onRefresh: _fetchTimeline,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDailyLogCard(),
          const SizedBox(height: 16),
          _buildSymptomEntries(),
        ],
      ),
    );
  }

  Widget _buildDailyLogCard() {
    final dailyLog = _timelineData?['daily_log'];

    if (dailyLog == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: const [
              Icon(Icons.info_outline, color: Colors.grey),
              SizedBox(width: 8),
              Text('Bu gün için günlük kayıt girilmemiş',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.assignment, color: Colors.blue),
                SizedBox(width: 8),
                Text('Günlük Özet',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),
            _buildLogRow('Uyku', '${dailyLog['sleep_hours']} saat'),
            _buildLogRow('Su', '${dailyLog['water_intake']} litre'),
            _buildLogRow('Ruh Hali', '${dailyLog['mood']}/5'),
            _buildLogRow('Enerji', '${dailyLog['energy_level']}/5'),
            if (dailyLog['notes'] != null && dailyLog['notes'].isNotEmpty)
              _buildLogRow('Not', dailyLog['notes']),
          ],
        ),
      ),
    );
  }

  Widget _buildLogRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSymptomEntries() {
    final entries = _timelineData?['symptom_entries'] as List? ?? [];

    if (entries.isEmpty) {
      return const Center(
        child: Text('Bu gün için semptom kaydı yok',
            style: TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      children: entries.map((entry) => _buildSymptomCard(entry)).toList(),
    );
  }

  Widget _buildSymptomCard(Map<String, dynamic> entry) {
    final timestamp = DateTime.parse(entry['timestamp']).toLocal();
    final timeStr =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Text(timeStr,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.sick, color: Colors.orange, size: 18),
                        const SizedBox(width: 6),
                        Text(entry['symptom_name'],
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Şiddet: ${entry['severity']}/10',
                        style: const TextStyle(color: Colors.grey)),
                    if (entry['notes'] != null && entry['notes'].isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(entry['notes']),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}