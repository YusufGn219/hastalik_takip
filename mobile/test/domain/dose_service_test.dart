import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/enums.dart';
import 'package:mobile/data/repositories/dose_skip_repository.dart';
import 'package:mobile/data/repositories/medication_log_repository.dart';
import 'package:mobile/data/repositories/medication_repository.dart';
import 'package:mobile/domain/errors.dart';
import 'package:mobile/domain/services/dose_service.dart';
import 'package:mobile/domain/services/medication_service.dart';

import '../data/test_support.dart';

Matcher violation(String code) => throwsA(
      isA<RuleViolation>().having((e) => e.code, 'code', code),
    );

/// 2026-11-06 Cuma 10:30.
DateTime _now() => DateTime(2026, 11, 6, 10, 30);

/// Alım yazarken hata veren depo (işlemin geri alındığını denemek için).
class _FailingLogs extends DriftMedicationLogRepository {
  _FailingLogs(super.db);

  @override
  Future<MedicationLog> create({
    required String medicationId,
    required DateTime takenAt,
    double? doseAmount,
    DoseUnit doseUnit = DoseUnit.tablet,
    String? episodeId,
    String? conditionId,
    String notes = '',
    String? scheduledTime,
    String? scheduledDay,
  }) =>
      throw StateError('yazılamadı');
}

void main() {
  late AppDatabase db;
  late DriftMedicationRepository meds;
  late DriftMedicationLogRepository logs;
  late DriftDoseSkipRepository skips;
  late MedicationService routines;
  late DoseService service;

  DoseService build([MedicationLogRepository? l]) => DoseService(
        medications: meds,
        logs: l ?? logs,
        skips: skips,
        transactor: db.transaction,
        clock: _now,
      );

  setUp(() {
    db = createTestDb();
    meds = DriftMedicationRepository(db);
    logs = DriftMedicationLogRepository(db);
    skips = DriftDoseSkipRepository(db);
    routines = MedicationService(medications: meds, logs: logs);
    service = build();
  });
  tearDown(() => db.close());

  /// Parol: her Cuma 08:00 ve 20:00.
  Future<Medication> parol({List<String>? days}) async {
    final m = await meds.create(name: 'Parol');
    await routines.setRoutine(
      medicationId: m.id,
      times: ['20:00', '08:00'],
      days: days ?? ['friday'],
    );
    return m;
  }

  List<DoseState> states(List<Dose> d) => d.map((x) => x.state).toList();

  group('günün dozları', () {
    test('rutinin o güne düşen dozları saate göre sıralı, hepsi "kaydedilmedi"',
        () async {
      final m = await parol();
      final aspirin = await meds.create(name: 'Aspirin');
      await routines.setRoutine(
          medicationId: aspirin.id, times: ['08:00'], days: ['friday']);
      final pazartesi = await meds.create(name: 'Pazartesi');
      await routines.setRoutine(
          medicationId: pazartesi.id, times: ['09:00'], days: ['monday']);
      await meds.create(name: 'Rutinsiz');

      final list = await service.dosesForDay('2026-11-06');

      expect(list.map((d) => '${d.time} ${d.medication.name}'),
          ['08:00 Aspirin', '08:00 Parol', '20:00 Parol']);
      expect(states(list), everyElement(DoseState.pending));
      expect(list.every((d) => d.log == null), isTrue);
      expect(list[1].medication.id, m.id);
    });

    test('günsüz ve eski saat yazımlı rutin her gün sayılır', () async {
      await meds.create(
        name: 'Eski',
        isRecurring: true,
        recurringTime: '08:30:00',
        recurringDays: null,
      );
      final list = await service.dosesForDay('2026-11-08'); // Pazar
      expect(list.map((d) => d.time), ['08:30']);
    });

    test('silinmiş ilaç ve rutini kapatılmış ilaç görünmez', () async {
      final a = await parol();
      final b = await meds.create(name: 'Bee');
      await routines.setRoutine(
          medicationId: b.id, times: ['09:00'], days: ['friday']);
      await meds.softDelete(a.id);
      await routines.clearRoutine(b.id);
      expect(await service.dosesForDay('2026-11-06'), isEmpty);
    });

    test('bugün', () {
      expect(service.today(), '2026-11-06');
    });
  });

  group('"Aldım"', () {
    test('yalnız o dozu "alındı" yapar; diğer doz "kaydedilmedi" kalır',
        () async {
      final m = await parol();

      final log = await service.markTaken(medicationId: m.id, time: '20:00');

      expect(log.scheduledTime, '20:00');
      expect(log.scheduledDay, '2026-11-06');
      expect(log.takenAt.toLocal(), _now());
      final list = await service.dosesForDay('2026-11-06');
      // Akşam dozu alındı; sabah dozu alınmış SAYILMAZ.
      expect(states(list), [DoseState.pending, DoseState.taken]);
      expect(list[0].time, '08:00');
      expect(list[1].log!.id, log.id);
    });

    test('sabah alındı, akşam kaydedilmedi', () async {
      final m = await parol();
      await service.markTaken(medicationId: m.id, time: '08:00');
      final list = await service.dosesForDay('2026-11-06');
      expect(states(list), [DoseState.taken, DoseState.pending]);
    });

    test('aynı doza ikinci "Aldım" reddedilir, tek kayıt kalır', () async {
      final m = await parol();
      await service.markTaken(medicationId: m.id, time: '08:00');
      await expectLater(
        service.markTaken(medicationId: m.id, time: '08:00'),
        violation(RuleCodes.doseAlreadyTaken),
      );
      expect(await logs.listScheduledForDay('2026-11-06'), hasLength(1));
    });

    test('atlanmış doz sonradan alınabilir: atlama silinir, tek sonuç kalır',
        () async {
      final m = await parol();
      await service.markSkipped(medicationId: m.id, time: '08:00');

      await service.markTaken(medicationId: m.id, time: '08:00');

      expect(await skips.listForDay('2026-11-06'), isEmpty);
      expect(await logs.listScheduledForDay('2026-11-06'), hasLength(1));
      expect(states(await service.dosesForDay('2026-11-06')),
          [DoseState.taken, DoseState.pending]);
    });

    test('atlamayı silme ve alımı yazma tek işlemdir: alım yazılamazsa atlama kalır',
        () async {
      final m = await parol();
      await service.markSkipped(medicationId: m.id, time: '08:00');

      await expectLater(
        build(_FailingLogs(db)).markTaken(medicationId: m.id, time: '08:00'),
        throwsStateError,
      );

      expect(await skips.listForDay('2026-11-06'), hasLength(1)); // geri alındı
      expect(await logs.listScheduledForDay('2026-11-06'), isEmpty);
      expect(states(await service.dosesForDay('2026-11-06')),
          [DoseState.skipped, DoseState.pending]);
    });
  });

  group('"Atladım"', () {
    test('doz "atlandı" olur; alım kaydı tablosuna hiçbir şey yazılmaz',
        () async {
      final m = await parol();

      final skip = await service.markSkipped(medicationId: m.id, time: '08:00');

      expect(skip.scheduledDay, '2026-11-06');
      expect(skip.scheduledTime, '08:00');
      expect(skip.skippedAt.toLocal(), _now());
      expect(states(await service.dosesForDay('2026-11-06')),
          [DoseState.skipped, DoseState.pending]);
      // Alım kaydı okuyan yerler atlanan dozu görmez.
      expect(await logs.listSince(DateTime(2000)), isEmpty);
      expect(await routines.logsForDay('2026-11-06'), isEmpty);
    });

    test('alınmış doz atlandı yapılamaz', () async {
      final m = await parol();
      await service.markTaken(medicationId: m.id, time: '08:00');
      await expectLater(
        service.markSkipped(medicationId: m.id, time: '08:00'),
        violation(RuleCodes.doseAlreadyTaken),
      );
      expect(await skips.listForDay('2026-11-06'), isEmpty);
    });

    test('aynı doza ikinci "Atladım" reddedilir', () async {
      final m = await parol();
      await service.markSkipped(medicationId: m.id, time: '08:00');
      await expectLater(
        service.markSkipped(medicationId: m.id, time: '08:00'),
        violation(RuleCodes.doseAlreadySkipped),
      );
      expect(await skips.listForDay('2026-11-06'), hasLength(1));
    });
  });

  group('planlı olmayan doz reddedilir', () {
    test('rutinde olmayan saat', () async {
      final m = await parol();
      await expectLater(
        service.markTaken(medicationId: m.id, time: '09:00'),
        violation(RuleCodes.doseNotScheduled),
      );
      await expectLater(
        service.markSkipped(medicationId: m.id, time: '09:00'),
        violation(RuleCodes.doseNotScheduled),
      );
      expect(await logs.listSince(DateTime(2000)), isEmpty);
      expect(await skips.listForDay('2026-11-06'), isEmpty);
    });

    test('rutinde olmayan gün (geçmiş Pazartesi)', () async {
      final m = await parol(); // yalnız Cuma
      await expectLater(
        service.markTaken(medicationId: m.id, time: '08:00', day: '2026-11-02'),
        violation(RuleCodes.doseNotScheduled),
      );
    });

    test('gelecek gün', () async {
      final m = await parol(days: ['friday', 'saturday']);
      await expectLater(
        service.markTaken(medicationId: m.id, time: '08:00', day: '2026-11-07'),
        violation(RuleCodes.doseNotScheduled),
      );
      await expectLater(
        service.markSkipped(medicationId: m.id, time: '08:00', day: '2026-11-07'),
        violation(RuleCodes.doseNotScheduled),
      );
    });

    test('rutini olmayan, kapatılmış, silinmiş ya da olmayan ilaç', () async {
      final plain = await meds.create(name: 'Rutinsiz');
      await expectLater(
        service.markTaken(medicationId: plain.id, time: '08:00'),
        violation(RuleCodes.doseNotScheduled),
      );

      final closed = await parol();
      await routines.clearRoutine(closed.id);
      await expectLater(
        service.markTaken(medicationId: closed.id, time: '08:00'),
        violation(RuleCodes.doseNotScheduled),
      );

      final deleted = await meds.create(name: 'Silinen');
      await routines.setRoutine(
          medicationId: deleted.id, times: ['08:00'], days: ['friday']);
      await meds.softDelete(deleted.id);
      await expectLater(
        service.markTaken(medicationId: deleted.id, time: '08:00'),
        violation(RuleCodes.medicationNotFound),
      );
      await expectLater(
        service.markSkipped(medicationId: 'yok', time: '08:00'),
        violation(RuleCodes.medicationNotFound),
      );
    });
  });

  group('günler birbirinden bağımsız', () {
    test('geçmiş gün dozu kaydedilebilir; bugünün dozunu etkilemez', () async {
      final m = await parol(days: ['thursday', 'friday']);

      final log = await service.markTaken(
          medicationId: m.id, time: '08:00', day: '2026-11-05');

      expect(log.scheduledDay, '2026-11-05'); // dozun günü; alım "şimdi"
      expect(states(await service.dosesForDay('2026-11-05')),
          [DoseState.taken, DoseState.pending]);
      expect(states(await service.dosesForDay('2026-11-06')),
          [DoseState.pending, DoseState.pending]);
    });
  });

  group('rutin saat listesi (MedicationService)', () {
    test('birden fazla saat sıralı ve tekil saklanır', () async {
      final m = await meds.create(name: 'Zeta');
      await routines.setRoutine(
        medicationId: m.id,
        times: ['20:00', '08:00', '20:00', '14:00'],
        days: ['monday'],
      );
      expect((await meds.getById(m.id))!.recurringTime, '08:00,14:00,20:00');
      expect((await routines.routines()).single.times,
          ['08:00', '14:00', '20:00']);
    });

    test('boş liste, geçersiz saat ve 10\'dan fazla doz reddedilir', () async {
      final m = await meds.create(name: 'Zeta');
      await expectLater(
        routines.setRoutine(medicationId: m.id, times: [], days: ['monday']),
        violation(RuleCodes.routineTimesEmpty),
      );
      await expectLater(
        routines.setRoutine(
            medicationId: m.id, times: ['08:00', '25:00'], days: ['monday']),
        violation(RuleCodes.routineTimeInvalid),
      );
      final eleven = [for (var i = 0; i < 11; i++) '${i.toString().padLeft(2, '0')}:00'];
      await expectLater(
        routines.setRoutine(medicationId: m.id, times: eleven, days: ['monday']),
        violation(RuleCodes.routineTooManyTimes),
      );
      await routines.setRoutine(
          medicationId: m.id, times: eleven.take(10).toList(), days: ['monday']);
      expect((await meds.getById(m.id))!.recurringTime!.split(','), hasLength(10));
    });

    test('rutin listesi ilk doz saatine göre sıralanır', () async {
      final a = await meds.create(name: 'A');
      final b = await meds.create(name: 'B');
      await routines.setRoutine(
          medicationId: a.id, times: ['09:00', '07:00'], days: ['monday']);
      await routines.setRoutine(
          medicationId: b.id, times: ['08:00'], days: ['monday']);
      expect((await routines.routines()).map((r) => r.medication.name),
          ['A', 'B']); // A'nın ilk saati 07:00
    });
  });
}
