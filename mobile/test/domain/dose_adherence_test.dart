import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/seed_loader.dart';
import 'package:mobile/data/repositories/dose_skip_repository.dart';
import 'package:mobile/data/repositories/medication_log_repository.dart';
import 'package:mobile/data/repositories/medication_repository.dart';
import 'package:mobile/domain/services/dose_adherence_service.dart';
import 'package:mobile/domain/services/dose_service.dart';
import 'package:mobile/domain/services/medication_service.dart';
import 'package:mobile/domain/weekdays.dart';

import '../data/test_support.dart';

/// Saat: 2026-11-07 Cumartesi 12:00.
DateTime _now() => DateTime(2026, 11, 7, 12, 0);

void main() {
  late AppDatabase db;
  late MedicationService routines;
  late DoseService doses;
  late DoseAdherenceService service;
  late DriftMedicationLogRepository logs;

  final aspirin = SeedLoader.medicationId('aspirin');
  final parol = SeedLoader.medicationId('parol');

  setUp(() async {
    db = createTestDb();
    await seedLoaderFor(db).seedIfNeeded();
    final meds = DriftMedicationRepository(db, clock: _now);
    logs = DriftMedicationLogRepository(db, clock: _now);
    routines = MedicationService(medications: meds, logs: logs);
    doses = DoseService(
      medications: meds,
      logs: logs,
      skips: DriftDoseSkipRepository(db, clock: _now),
      transactor: db.transaction,
      clock: _now,
    );
    service = DoseAdherenceService(doses: doses, logs: logs, clock: _now);
    await routines.setRoutine(
      medicationId: aspirin,
      times: ['08:00', '20:00'],
      days: weekdayKeys,
    );
  });
  tearDown(() => db.close());

  Future<DoseAdherenceItem> aspirinItem([int days = 7]) async =>
      (await service.doseAdherence(days))
          .items
          .firstWhere((i) => i.medicationId == aspirin);

  Future<void> take(String day, String time, [String? med]) =>
      doses.markTaken(medicationId: med ?? aspirin, time: time, day: day);
  Future<void> skip(String day, String time, [String? med]) =>
      doses.markSkipped(medicationId: med ?? aspirin, time: time, day: day);

  test('sabah atlanıp akşam alınırsa %100 değil, atlananlar paydada kalır',
      () async {
    // Üç gün: her gün sabah atlandı, akşam alındı; bugün sabah alındı.
    for (final d in ['2026-11-04', '2026-11-05', '2026-11-06']) {
      await skip(d, '08:00');
      await take(d, '20:00');
    }
    await take('2026-11-07', '08:00');

    final item = await aspirinItem();

    expect(item.taken, 4);
    expect(item.skipped, 3);
    expect(item.unrecorded, 0);
    expect(item.planned, 7);
    // Gün bazlı eski hesap dört günün hepsini "alındı" sayıp %100 gösterirdi.
    expect(item.rate, 57.1);
  });

  test('alındı, atlandı ve kaydedilmedi ayrı sayılır; bugünün gelmemiş dozu sayılmaz',
      () async {
    await take('2026-11-05', '08:00');
    await skip('2026-11-05', '20:00');
    await take('2026-11-06', '08:00');
    // 2026-11-06 20:00: kaydedilmedi.
    await take('2026-11-07', '08:00');
    // 2026-11-07 20:00: saati henüz gelmedi (şimdi 12:00), sayılmaz.

    final item = await aspirinItem();

    expect(item.taken, 3);
    expect(item.skipped, 1);
    expect(item.unrecorded, 1);
    expect(item.planned, 5);
    expect(item.rate, 60.0);
  });

  test('sayım ilk kayıtlı dozdan başlar; öncesi "kaydedilmedi" sayılmaz',
      () async {
    await take('2026-11-06', '20:00'); // ilk kayıt: 06 Kasım akşamı
    // 06 Kasım 08:00 ve önceki günler sayılmaz.
    // 07 Kasım 08:00 saati geçmiş, kaydedilmedi.

    final item = await aspirinItem(30);

    expect(item.taken, 1);
    expect(item.unrecorded, 1);
    expect(item.planned, 2);
    expect(item.rate, 50.0);
  });

  test('hiç kayıt yoksa oran boş ("henüz veri yok"), kaydedilmedi sayılmaz',
      () async {
    final item = await aspirinItem(30);

    expect(item.hasData, isFalse);
    expect(item.rate, isNull);
    expect(item.planned, 0);
    expect(item.unrecorded, 0);
  });

  test('saati tam şimdi olan doz sayılır (>=), bir dakika sonrası sayılmaz',
      () async {
    await routines.setRoutine(
      medicationId: parol,
      times: ['11:00', '12:00', '12:01'],
      days: weekdayKeys,
    );
    await take('2026-11-07', '11:00', parol); // ilk kayıt

    final item = (await service.doseAdherence(1))
        .items
        .firstWhere((i) => i.medicationId == parol);

    // 11:00 alındı, 12:00 kaydedilmedi (saati geldi), 12:01 gelmedi.
    expect(item.taken, 1);
    expect(item.unrecorded, 1);
    expect(item.planned, 2);
  });

  test('yalnız rutindeki günler planlı sayılır', () async {
    // 2026-11-07 Cumartesi. Rutin yalnız Cuma.
    await routines.setRoutine(
      medicationId: parol,
      times: ['09:00'],
      days: ['friday'],
    );
    await take('2026-11-06', '09:00', parol);

    final item = (await service.doseAdherence(7))
        .items
        .firstWhere((i) => i.medicationId == parol);

    // Pencerede (01-07 Kasım) tek Cuma var: 06 Kasım.
    expect(item.planned, 1);
    expect(item.taken, 1);
    expect(item.rate, 100.0);
  });

  test('pencere dışındaki kayıtlar sayılmaz', () async {
    await take('2026-10-20', '08:00'); // 3 günlük pencerenin çok dışında
    await take('2026-11-06', '08:00');

    final item = await aspirinItem(3); // 05, 06, 07 Kasım

    // İlk kayıt 06 Kasım 08:00; sayılanlar: 06 08:00 alındı, 06 20:00 ve
    // 07 08:00 kaydedilmedi.
    expect(item.taken, 1);
    expect(item.unrecorded, 2);
    expect(item.planned, 3);
  });

  test('plansız alımlar ekstra sayılır, orana girmez; doza bağlı alım ekstra değil',
      () async {
    await take('2026-11-06', '08:00');
    await logs.create(
      medicationId: aspirin,
      takenAt: DateTime(2026, 11, 6, 15, 0),
    );
    await logs.create(
      medicationId: aspirin,
      takenAt: DateTime(2026, 10, 1, 15, 0), // pencere dışı
    );
    // Pencerenin (01-07 Kasım) hemen dışı: sorgunun geniş çekim payına düşer,
    // kesin yerel gün süzmesi atmalı.
    await logs.create(
      medicationId: aspirin,
      takenAt: DateTime(2026, 10, 31, 23, 0),
    );

    final item = await aspirinItem(7);

    expect(item.extraIntakes, 1);
    expect(item.taken, 1);
    expect(item.planned, 3); // 06 08:00 alındı, 06 20:00 ve 07 08:00 kaydedilmedi
  });

  test('rutini kapatılan ilaç listelenmez; rutinsiz ilaç hiç yok', () async {
    await take('2026-11-06', '08:00');
    await routines.clearRoutine(aspirin);

    final result = await service.doseAdherence(7);

    expect(result.items, isEmpty);
  });

  test('ilaçlar Türkçe ada göre sıralı ve ayrı sayılır', () async {
    await routines.setRoutine(
      medicationId: parol,
      times: ['08:00'],
      days: weekdayKeys,
    );
    await take('2026-11-06', '08:00');
    await take('2026-11-06', '08:00', parol);

    final result = await service.doseAdherence(7);

    expect(result.items.map((i) => i.medicationName), ['Aspirin', 'Parol']);
    expect(result.periodDays, 7);
  });
}
