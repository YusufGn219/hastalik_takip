import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/enums.dart';
import 'package:mobile/data/repositories/measurement_repository.dart';
import 'package:mobile/domain/errors.dart';
import 'package:mobile/domain/services/body_measurement_service.dart';

import '../data/test_support.dart';

Matcher violation(String code) => throwsA(
      isA<RuleViolation>().having((e) => e.code, 'code', code),
    );

void main() {
  late AppDatabase db;
  late DriftMeasurementRepository repo;
  late BodyMeasurementService service;

  // "Şimdi": yerel 8 Kasım 2026 12:00.
  DateTime now() => DateTime(2026, 11, 8, 12);

  setUp(() {
    db = createTestDb();
    repo = DriftMeasurementRepository(db, clock: now);
    service = BodyMeasurementService(measurements: repo, clock: now);
  });
  tearDown(() => db.close());

  test('hiç ölçüm yokken görünüm boş', () async {
    final o = await service.overview();
    expect(o.height, isNull);
    expect(o.weights, isEmpty);
    expect(o.latestWeight, isNull);
  });

  group('boy', () {
    test('kaydedilir, tek ondalığa yuvarlanır, birimi cm', () async {
      await service.saveHeight(175.04);
      final h = (await service.overview()).height!;
      expect(h.value, 175.0);
      expect(h.unit, 'cm');
      expect(h.type, MeasurementTypes.height);
    });

    test('aynı değer tekrar kaydedilirse yeni kayıt açılmaz', () async {
      await service.saveHeight(175);
      await service.saveHeight(175.0);
      expect(await repo.listByType(MeasurementTypes.height), hasLength(1));
    });

    test('değişince yeni kayıt açılır; güncel boy sonuncusu, geçmiş saklanır', () async {
      await service.saveHeight(170);
      final later = BodyMeasurementService(
        measurements: DriftMeasurementRepository(db, clock: () => DateTime(2026, 11, 9, 9)),
        clock: () => DateTime(2026, 11, 9, 9),
      );
      await later.saveHeight(171.5);
      expect((await later.overview()).height!.value, 171.5);
      expect(await repo.listByType(MeasurementTypes.height), hasLength(2));
    });

    test('sınırlar kabul edilir, dışı reddedilir ve hiçbir şey yazılmaz', () async {
      await service.saveHeight(50);
      await service.saveHeight(250);
      expect(await repo.listByType(MeasurementTypes.height), hasLength(2));

      for (final bad in <double>[49.9, 250.1, 0, -170, double.nan, double.infinity]) {
        await expectLater(service.saveHeight(bad), violation(RuleCodes.heightOutOfRange), reason: '$bad');
      }
      expect(await repo.listByType(MeasurementTypes.height), hasLength(2));
    });
  });

  group('kilo', () {
    test('bugün: şimdiki anla, kg birimiyle, tek ondalığa yuvarlanarak yazılır', () async {
      final m = await service.addWeight(kg: 72.46);
      expect(m.value, 72.5);
      expect(m.unit, 'kg');
      expect(m.type, MeasurementTypes.weight);
      expect(m.logDate, '2026-11-08');
      expect(m.measuredAt.toLocal(), now());
    });

    test('geçmiş gün: o günün kaydı olur (yerel öğlen)', () async {
      final m = await service.addWeight(kg: 70, day: '2026-10-01');
      expect(m.logDate, '2026-10-01');
      expect(m.measuredAt.toLocal(), DateTime(2026, 10, 1, 12));
    });

    test('sınırlar kabul edilir, dışı reddedilir', () async {
      await service.addWeight(kg: 2);
      await service.addWeight(kg: 500);
      for (final bad in <double>[1.9, 500.1, 0, -5, double.nan, double.infinity]) {
        await expectLater(service.addWeight(kg: bad), violation(RuleCodes.weightOutOfRange), reason: '$bad');
      }
      expect(await repo.listByType(MeasurementTypes.weight), hasLength(2));
    });

    test('gelecek gün ve geçersiz gün reddedilir, hiçbir şey yazılmaz', () async {
      await expectLater(service.addWeight(kg: 70, day: '2026-11-09'),
          violation(RuleCodes.measurementDayInFuture));
      for (final bad in ['2025-02-30', '8.11.2026', '2026-1-5', '1899-12-31', '']) {
        await expectLater(service.addWeight(kg: 70, day: bad),
            violation(RuleCodes.measurementDayInvalid), reason: bad);
      }
      expect(await repo.listByType(MeasurementTypes.weight), isEmpty);
    });

    test('bugün tarihi verilirse de kabul edilir', () async {
      final m = await service.addWeight(kg: 70, day: '2026-11-08');
      expect(m.logDate, '2026-11-08');
    });

    test('görünümde en yeni önce; aynı günde birden çok kayıt tutulur', () async {
      await service.addWeight(kg: 71, day: '2026-10-01');
      await service.addWeight(kg: 72, day: '2026-10-15');
      await service.addWeight(kg: 73, day: '2026-10-15');
      final weights = (await service.overview()).weights;
      expect(weights.map((m) => m.logDate), ['2026-10-15', '2026-10-15', '2026-10-01']);
      expect(weights.last.value, 71);
      expect((await service.overview()).latestWeight!.logDate, '2026-10-15');
    });

    test('silinen kayıt görünümden çıkar, diğerleri kalır; boyu etkilemez', () async {
      await service.saveHeight(175);
      final a = await service.addWeight(kg: 71, day: '2026-10-01');
      await service.addWeight(kg: 72, day: '2026-10-02');
      await service.deleteWeight(a.id);
      final o = await service.overview();
      expect(o.weights.map((m) => m.value), [72]);
      expect(o.height!.value, 175);
    });
  });

  group('boyu temizle', () {
    test('tüm boy kayıtları silinir; kilolar kalır', () async {
      await service.saveHeight(170);
      final later = BodyMeasurementService(
        measurements: DriftMeasurementRepository(db, clock: () => DateTime(2026, 11, 9, 9)),
        clock: () => DateTime(2026, 11, 9, 9),
      );
      await later.saveHeight(171.5);
      await service.addWeight(kg: 70);

      await service.clearHeight();
      final o = await service.overview();
      expect(o.height, isNull);
      expect(await repo.listByType(MeasurementTypes.height), isEmpty);
      expect(o.weights, hasLength(1));
    });

    test('boy yokken temizlemek hata vermez', () async {
      await service.clearHeight();
      expect((await service.overview()).height, isNull);
    });

    test('temizledikten sonra yeniden boy kaydedilebilir', () async {
      await service.saveHeight(170);
      await service.clearHeight();
      await service.saveHeight(170);
      expect((await service.overview()).height!.value, 170);
    });
  });

  test('boy ve kilo birbirinin geçmişine karışmaz', () async {
    await service.saveHeight(180);
    await service.addWeight(kg: 80);
    expect(await repo.listByType(MeasurementTypes.height), hasLength(1));
    expect(await repo.listByType(MeasurementTypes.weight), hasLength(1));
  });
}
