import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/database/app_database.dart';

import 'test_support.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDb());
  tearDown(() => db.close());

  test('şema sürümü 3 ve 19 tablo oluşur', () async {
    expect(db.schemaVersion, 3);
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    final names = rows.map((r) => r.read<String>('name')).toSet();
    expect(names, {
      'profiles',
      'app_settings',
      'symptoms',
      'episodes',
      'symptom_entries',
      'episode_location_entries',
      'medication_categories',
      'medications',
      'chronic_conditions',
      'condition_medications',
      'medication_logs',
      'dose_skips',
      'daily_logs',
      'measurements',
      'tags',
      'tag_entries',
      'cycle_periods',
      'cycle_flows',
      'cycle_statuses',
    });
  });

  test('yabancı anahtar kısıtı açık: olmayan semptoma atak eklenemez', () async {
    final now = utc(2026, 11, 1);
    expect(
      () => db.into(db.episodes).insert(
            EpisodesCompanion.insert(
              id: 'e1',
              createdAt: now,
              updatedAt: now,
              symptomId: 'yok',
              startTime: now,
              startUtcOffsetMinutes: 0,
            ),
          ),
      throwsA(isA<Exception>()),
    );
  });

  test('tekillik silme işaretini sayar: silinen günün yerine yenisi açılır',
      () async {
    final now = utc(2026, 11, 1);
    Future<void> insert(String id) => db.into(db.dailyLogs).insert(
          DailyLogsCompanion.insert(
            id: id,
            createdAt: now,
            updatedAt: now,
            logDate: '2026-11-01',
            sleepHours: 7,
            waterIntake: 2,
            mood: 3,
            energyLevel: 3,
          ),
        );

    await insert('a');
    // Aynı gün ikinci kayıt reddedilir.
    await expectLater(insert('b'), throwsA(isA<Exception>()));

    // İlki silinince aynı güne yeni kayıt eklenebilir.
    await (db.update(db.dailyLogs)..where((t) => t.id.equals('a')))
        .write(DailyLogsCompanion(deletedAt: Value(now)));
    await insert('b');
    expect((await db.select(db.dailyLogs).get()).length, 2);
  });

  test('bildirim numarası tekil', () async {
    final now = utc(2026, 11, 1);
    Future<void> insert(String id, int n) => db.into(db.medications).insert(
          MedicationsCompanion.insert(
            id: id,
            createdAt: now,
            updatedAt: now,
            name: id,
            notificationId: Value(n),
          ),
        );
    await insert('m1', 1);
    await expectLater(insert('m2', 1), throwsA(isA<Exception>()));
    await insert('m3', 2);
  });
}
