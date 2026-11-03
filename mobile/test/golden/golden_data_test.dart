// Altın veri (golden data) bütünlük testi — Sprint 0.
//
// Dart'taki iş mantığı henüz yok; bu test yalnızca altın veri dosyalarının
// okunabildiğini ve içeriğinin beklenen biçimde olduğunu doğrular. Sprint 2'de
// aynı dosyalar Dart analitiğinin çıktısıyla birebir karşılaştırılacak.
//
// Dosyalar `scripts/golden/generate_golden.py` ile üretilir; elle düzenlenmez.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _load(String name) {
  final file = File('test/golden/$name');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  late Map<String, dynamic> dataset;
  late Map<String, dynamic> expected;

  setUpAll(() {
    dataset = _load('dataset.json');
    expected = _load('expected_analytics.json');
  });

  test('dataset.json: sabit "şimdi" ve tablolar var', () {
    final meta = dataset['meta'] as Map<String, dynamic>;
    expect(DateTime.parse(meta['frozen_now'] as String).isUtc, isTrue);
    expect(meta['periods'], [7, 30, 90]);

    for (final table in [
      'symptoms',
      'medications',
      'chronic_conditions',
      'episodes',
      'symptom_entries',
      'daily_logs',
      'medication_logs',
    ]) {
      expect((dataset[table] as List), isNotEmpty, reason: '$table boş');
    }
  });

  test('dataset.json: yabancı anahtarlar tutarlı', () {
    List<Map<String, dynamic>> rows(String t) =>
        (dataset[t] as List).cast<Map<String, dynamic>>();

    final symptomIds = rows('symptoms').map((r) => r['id']).toSet();
    final medicationIds = rows('medications').map((r) => r['id']).toSet();
    final episodeIds = rows('episodes').map((r) => r['id']).toSet();

    for (final e in rows('symptom_entries')) {
      expect(symptomIds, contains(e['symptom_id']));
      if (e['episode_id'] != null) {
        expect(episodeIds, contains(e['episode_id']));
      }
    }
    for (final m in rows('medication_logs')) {
      expect(medicationIds, contains(m['medication_id']));
      if (m['episode_id'] != null) {
        expect(episodeIds, contains(m['episode_id']));
      }
    }
  });

  test('expected_analytics.json: her dönem için dört çıktı var', () {
    expect(expected.keys.toSet(), {'7', '30', '90'});
    for (final entry in expected.entries) {
      final period = entry.value as Map<String, dynamic>;
      expect(period.keys.toSet(), {
        'symptom_analytics',
        'daily_trends',
        'medication_effect',
        'medication_adherence',
      });
      for (final part in period.values) {
        expect((part as Map<String, dynamic>)['period_days'], int.parse(entry.key));
      }
    }
  });
}
