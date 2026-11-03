// Altın veri karşılaştırması — Sprint 2.
//
// Dart servisinin çıktısı, aynı örnek veriyle (`dataset.json`) yeni kurallara
// göre bağımsız üretilmiş beklenen çıktıyla (`expected_analytics_v2.json`)
// birebir aynı olmalı. v2 dosyası `scripts/golden/generate_golden_v2.py` ile
// üretilir; elle düzenlenmez. Eski davranışın kaydı `expected_analytics.json`
// olarak tarihçe için durur; farklar test/golden/FARKLAR.md'de.

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/enums.dart';
import 'package:mobile/data/repositories/daily_log_repository.dart';
import 'package:mobile/data/repositories/medication_log_repository.dart';
import 'package:mobile/data/repositories/medication_repository.dart';
import 'package:mobile/data/repositories/symptom_entry_repository.dart';
import 'package:mobile/data/repositories/symptom_repository.dart';
import 'package:mobile/domain/services/analytics_service.dart';

import '../data/test_support.dart';

/// Eski sistemde saat dilimi Europe/Istanbul (yıl boyu UTC+3).
const _istanbulOffset = 180;

Map<String, dynamic> _load(String name) =>
    jsonDecode(File('test/golden/$name').readAsStringSync())
        as Map<String, dynamic>;

List<Map<String, dynamic>> _rows(Map<String, dynamic> d, String t) =>
    (d[t] as List).cast<Map<String, dynamic>>();

String _id(String prefix, Object? n) => '$prefix-$n';

Future<void> _loadDataset(AppDatabase db, Map<String, dynamic> d) async {
  final now = DateTime.utc(2026, 1, 1);
  DateTime ts(String s) => DateTime.parse(s);

  await db.batch((b) {
    b.insertAll(db.symptoms, [
      for (final r in _rows(d, 'symptoms'))
        SymptomsCompanion.insert(
          id: _id('sym', r['id']),
          createdAt: now,
          updatedAt: now,
          name: r['name'] as String,
        ),
    ]);
    b.insertAll(db.medications, [
      for (final r in _rows(d, 'medications'))
        MedicationsCompanion.insert(
          id: _id('med', r['id']),
          createdAt: now,
          updatedAt: now,
          name: r['name'] as String,
          type: Value(MedicationType.values.byName(r['type'] as String)),
          isCatalog: Value(r['is_global'] as bool),
          isRecurring: Value(r['is_recurring'] as bool),
          recurringTime: Value(r['recurring_time'] as String?),
          recurringDays: Value(
            r['recurring_days'] == null ? null : jsonEncode(r['recurring_days']),
          ),
        ),
    ]);
    b.insertAll(db.chronicConditions, [
      for (final r in _rows(d, 'chronic_conditions'))
        ChronicConditionsCompanion.insert(
          id: _id('cond', r['id']),
          createdAt: now,
          updatedAt: now,
          name: r['name'] as String,
        ),
    ]);
    b.insertAll(db.conditionMedications, [
      for (final r in _rows(d, 'chronic_conditions'))
        for (final m in (r['medication_ids'] as List))
          ConditionMedicationsCompanion.insert(
            conditionId: _id('cond', r['id']),
            medicationId: _id('med', m),
          ),
    ]);
    b.insertAll(db.episodes, [
      for (final r in _rows(d, 'episodes'))
        EpisodesCompanion.insert(
          id: _id('ep', r['id']),
          createdAt: now,
          updatedAt: now,
          symptomId: _id('sym', r['symptom_id']),
          startTime: ts(r['start_time'] as String),
          startUtcOffsetMinutes: _istanbulOffset,
          endedAt: Value(
            r['ended_at'] == null ? null : ts(r['ended_at'] as String),
          ),
          status: Value(EpisodeStatus.values.byName(r['status'] as String)),
        ),
    ]);
    b.insertAll(db.symptomEntries, [
      for (final r in _rows(d, 'symptom_entries'))
        SymptomEntriesCompanion.insert(
          id: _id('se', r['id']),
          createdAt: now,
          updatedAt: now,
          symptomId: _id('sym', r['symptom_id']),
          episodeId: Value(
            r['episode_id'] == null ? null : _id('ep', r['episode_id']),
          ),
          severity: r['severity'] as int,
          timestamp: ts(r['timestamp'] as String),
          utcOffsetMinutes: _istanbulOffset,
          location: Value(r['location'] as String? ?? ''),
        ),
    ]);
    b.insertAll(db.dailyLogs, [
      for (final r in _rows(d, 'daily_logs'))
        DailyLogsCompanion.insert(
          id: _id('dl', r['id']),
          createdAt: now,
          updatedAt: now,
          logDate: r['date'] as String,
          sleepHours: (r['sleep_hours'] as num).toDouble(),
          waterIntake: (r['water_intake'] as num).toDouble(),
          mood: r['mood'] as int,
          energyLevel: r['energy_level'] as int,
        ),
    ]);
    b.insertAll(db.medicationLogs, [
      for (final r in _rows(d, 'medication_logs'))
        MedicationLogsCompanion.insert(
          id: _id('ml', r['id']),
          createdAt: now,
          updatedAt: now,
          medicationId: _id('med', r['medication_id']),
          takenAt: ts(r['taken_at'] as String),
          utcOffsetMinutes: _istanbulOffset,
          doseAmount: Value((r['dose_amount'] as num?)?.toDouble()),
          doseUnit: Value(DoseUnit.values.byName(r['dose_unit'] as String)),
          episodeId: Value(
            r['episode_id'] == null ? null : _id('ep', r['episode_id']),
          ),
          conditionId: Value(
            r['condition_id'] == null ? null : _id('cond', r['condition_id']),
          ),
        ),
    ]);
  });
}

void main() {
  late AppDatabase db;
  late AnalyticsService service;
  late Map<String, dynamic> expected;

  setUp(() async {
    final dataset = _load('dataset.json');
    expected = _load('expected_analytics_v2.json');
    db = createTestDb();
    await _loadDataset(db, dataset);
    final frozenNow = DateTime.parse(
      (dataset['meta'] as Map<String, dynamic>)['frozen_now'] as String,
    );
    service = AnalyticsService(
      entries: DriftSymptomEntryRepository(db),
      symptoms: DriftSymptomRepository(db),
      medicationLogs: DriftMedicationLogRepository(db),
      medications: DriftMedicationRepository(db),
      dailyLogs: DriftDailyLogRepository(db),
      clock: () => frozenNow,
      currentOffsetMinutes: () => _istanbulOffset,
    );
  });
  tearDown(() => db.close());

  /// Dart çıktısını JSON'a çevirip geri okur: tür farkları (int/double) ve
  /// alan adları, beklenen dosyayla aynı koşulda karşılaştırılır.
  Object? roundTrip(Map<String, dynamic> m) => jsonDecode(jsonEncode(m));

  for (final days in [7, 30, 90]) {
    group('$days gün', () {
      Map<String, dynamic> exp(String part) =>
          (expected['$days'] as Map<String, dynamic>)[part]
              as Map<String, dynamic>;

      test('semptom sıklığı ve şiddet eğilimi', () async {
        expect(
          roundTrip((await service.symptomAnalytics(days)).toJson()),
          exp('symptom_analytics'),
        );
      });

      test('günlük eğilimler ve ortalamalar', () async {
        expect(
          roundTrip((await service.dailyTrends(days)).toJson()),
          exp('daily_trends'),
        );
      });

      test('ilaç etkisi', () async {
        expect(
          roundTrip((await service.medicationEffect(days)).toJson()),
          exp('medication_effect'),
        );
      });

      test('ilaç uyumu', () async {
        expect(
          roundTrip((await service.medicationAdherence(days)).toJson()),
          exp('medication_adherence'),
        );
      });
    });
  }
}
