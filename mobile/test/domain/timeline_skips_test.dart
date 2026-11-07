import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/seed_loader.dart';
import 'package:mobile/data/repositories/daily_log_repository.dart';
import 'package:mobile/data/repositories/dose_skip_repository.dart';
import 'package:mobile/data/repositories/medication_log_repository.dart';
import 'package:mobile/data/repositories/medication_repository.dart';
import 'package:mobile/data/repositories/symptom_entry_repository.dart';
import 'package:mobile/domain/services/medication_service.dart';
import 'package:mobile/domain/services/timeline_service.dart';

import '../data/test_support.dart';

/// Zaman çizelgesi, atlanan dozları da verir (alım kaydı sanılmadan).
void main() {
  late AppDatabase db;
  late DriftDoseSkipRepository skips;
  late DriftMedicationLogRepository logs;
  late TimelineService withSkips;
  late TimelineService withoutSkips;
  late String parol;

  setUp(() async {
    db = createTestDb();
    await seedLoaderFor(db).seedIfNeeded();
    parol = SeedLoader.medicationId('parol');
    skips = DriftDoseSkipRepository(db);
    logs = DriftMedicationLogRepository(db);
    final medications = MedicationService(
      medications: DriftMedicationRepository(db),
      logs: logs,
    );
    withSkips = TimelineService(
      dailyLogs: DriftDailyLogRepository(db),
      entries: DriftSymptomEntryRepository(db),
      medications: medications,
      doseSkips: skips,
    );
    withoutSkips = TimelineService(
      dailyLogs: DriftDailyLogRepository(db),
      entries: DriftSymptomEntryRepository(db),
      medications: medications,
    );
  });
  tearDown(() => db.close());

  test('günün atlanan dozu verilir ve alım listesine karışmaz', () async {
    await skips.create(
      medicationId: parol,
      scheduledDay: '2026-11-07',
      scheduledTime: '08:00',
      skippedAt: DateTime(2026, 11, 7, 8, 40),
    );

    final t = await withSkips.forDay('2026-11-07');

    expect(t.doseSkips, hasLength(1));
    expect(t.doseSkips.single.scheduledTime, '08:00');
    expect(t.medicationLogs, isEmpty); // "atladım" alım sayılmaz
  });

  test('başka günün ve silinmiş atlama gelmez', () async {
    await skips.create(
      medicationId: parol,
      scheduledDay: '2026-11-06',
      scheduledTime: '08:00',
      skippedAt: DateTime(2026, 11, 6, 8, 40),
    );
    final deleted = await skips.create(
      medicationId: parol,
      scheduledDay: '2026-11-07',
      scheduledTime: '20:00',
      skippedAt: DateTime(2026, 11, 7, 20, 10),
    );
    await skips.softDelete(deleted.id);

    expect((await withSkips.forDay('2026-11-07')).doseSkips, isEmpty);
    expect((await withSkips.forDay('2026-11-06')).doseSkips, hasLength(1));
  });

  test('atlama deposu verilmezse eski davranış: boş liste, alımlar yerinde',
      () async {
    await skips.create(
      medicationId: parol,
      scheduledDay: '2026-11-07',
      scheduledTime: '08:00',
      skippedAt: DateTime(2026, 11, 7, 8, 40),
    );
    await logs.create(
      medicationId: parol,
      takenAt: DateTime(2026, 11, 7, 20, 5),
      scheduledTime: '20:00',
      scheduledDay: '2026-11-07',
    );

    final t = await withoutSkips.forDay('2026-11-07');

    expect(t.doseSkips, isEmpty);
    expect(t.medicationLogs, hasLength(1));
  });
}
