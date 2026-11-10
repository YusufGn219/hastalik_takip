import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/enums.dart';
import 'package:mobile/data/repositories/measurement_repository.dart';
import 'package:mobile/data/repositories/settings_repository.dart';
import 'package:mobile/domain/errors.dart';
import 'package:mobile/domain/reading_catalog.dart';
import 'package:mobile/domain/services/reading_service.dart';

import '../data/test_support.dart';

Matcher _violation(String code) =>
    throwsA(isA<RuleViolation>().having((e) => e.code, 'code', code));

void main() {
  late AppDatabase db;
  late DriftMeasurementRepository measurements;
  late DriftSettingsRepository settings;
  late ReadingService service;

  // Sabit "şimdi": 2026-11-10 12:00 yerel.
  final now = DateTime(2026, 11, 10, 12);

  setUp(() {
    db = createTestDb();
    measurements = DriftMeasurementRepository(db, clock: () => now, newId: sequentialIds('m'));
    settings = DriftSettingsRepository(db);
    service = ReadingService(measurements: measurements, settings: settings, clock: () => now);
  });
  tearDown(() => db.close());

  const bp = MeasurementTypes.bloodPressure;
  const pulse = MeasurementTypes.pulse;
  const glucose = MeasurementTypes.bloodGlucose;

  group('tansiyon', () {
    test('iki sayılı ölçüm temel birimde yazılır, şimdi varsayılan an olur', () async {
      final m = await service.add(type: bp, value: 120, value2: 80);
      expect((m.type, m.value, m.value2, m.unit), (bp, 120.0, 80.0, 'mmHg'));
      expect(m.context, isNull);
      expect(m.measuredAt, now);
      expect(m.logDate, '2026-11-10');
    });

    test('sınırlar dahil kabul edilir', () async {
      await service.add(type: bp, value: 260, value2: 150);
      await service.add(type: bp, value: 60, value2: 30);
    });

    test('aralık dışı değerler reddedilir', () async {
      expect(() => service.add(type: bp, value: 59, value2: 40), _violation(RuleCodes.readingValueOutOfRange));
      expect(() => service.add(type: bp, value: 261, value2: 80), _violation(RuleCodes.readingValueOutOfRange));
      expect(() => service.add(type: bp, value: 120, value2: 29), _violation(RuleCodes.readingSecondValueOutOfRange));
      expect(() => service.add(type: bp, value: 200, value2: 151), _violation(RuleCodes.readingSecondValueOutOfRange));
      expect(() => service.add(type: bp, value: double.nan, value2: 80), _violation(RuleCodes.readingValueOutOfRange));
      expect(() => service.add(type: bp, value: 120, value2: double.infinity),
          _violation(RuleCodes.readingSecondValueOutOfRange));
    });

    test('ikinci değer zorunlu; büyük değer küçükten yüksek olmalı', () async {
      expect(() => service.add(type: bp, value: 120), _violation(RuleCodes.readingSecondValueRequired));
      expect(() => service.add(type: bp, value: 80, value2: 80), _violation(RuleCodes.readingFirstNotAboveSecond));
      expect(() => service.add(type: bp, value: 70, value2: 90), _violation(RuleCodes.readingFirstNotAboveSecond));
      expect((await measurements.listByType(bp)), isEmpty);
    });

    test('bağlam kabul edilmez (tansiyonda bağlam yok)', () async {
      expect(() => service.add(type: bp, value: 120, value2: 80, context: 'fasting'),
          _violation(RuleCodes.readingContextInvalid));
    });
  });

  group('nabız', () {
    test('tek değerli; ikinci değer reddedilir; aralık 20–250', () async {
      final m = await service.add(type: pulse, value: 72);
      expect((m.value, m.value2, m.unit), (72.0, null, 'bpm'));
      expect(() => service.add(type: pulse, value: 72, value2: 1), _violation(RuleCodes.readingSecondValueNotAllowed));
      expect(() => service.add(type: pulse, value: 19), _violation(RuleCodes.readingValueOutOfRange));
      expect(() => service.add(type: pulse, value: 251), _violation(RuleCodes.readingValueOutOfRange));
      await service.add(type: pulse, value: 20);
      await service.add(type: pulse, value: 250);
    });
  });

  group('kan şekeri ve birim', () {
    test('mg/dL girişi olduğu gibi saklanır, bağlamla', () async {
      final m = await service.add(type: glucose, value: 105, unit: 'mg/dL', context: ReadingContexts.fasting);
      expect((m.value, m.unit, m.context), (105.0, 'mg/dL', 'fasting'));
    });

    test('mmol/L girişi mg/dL olarak yuvarlanmadan saklanır', () async {
      final m = await service.add(type: glucose, value: 5.5, unit: 'mmol/L');
      expect(m.value, closeTo(99.088, 1e-9));
      expect(m.unit, 'mg/dL');
      // Ekranda aynı mmol/L değerine geri çevrilir.
      expect(ReadingCatalog.bloodGlucose.fromBase(m.value, 'mmol/L'), closeTo(5.5, 1e-12));
    });

    test('girilen sayı birimin ondalığına yuvarlanır, sonra dönüştürülür', () async {
      final m = await service.add(type: glucose, value: 5.55, unit: 'mmol/L');
      expect(m.value, closeTo(5.6 * 18.016, 1e-9));
      final n = await service.add(type: glucose, value: 99.6, unit: 'mg/dL');
      expect(n.value, 100.0);
    });

    test('aralık temel birimde denetlenir (mmol/L girişinde de)', () async {
      expect(() => service.add(type: glucose, value: 1.0, unit: 'mmol/L'),
          _violation(RuleCodes.readingValueOutOfRange));
      await service.add(type: glucose, value: 1.2, unit: 'mmol/L');
      await service.add(type: glucose, value: 33.0, unit: 'mmol/L');
      expect(() => service.add(type: glucose, value: 34.0, unit: 'mmol/L'),
          _violation(RuleCodes.readingValueOutOfRange));
      expect(() => service.add(type: glucose, value: 19, unit: 'mg/dL'), _violation(RuleCodes.readingValueOutOfRange));
      expect(() => service.add(type: glucose, value: 601, unit: 'mg/dL'), _violation(RuleCodes.readingValueOutOfRange));
    });

    test('bilinmeyen birim, bilinmeyen bağlam, bilinmeyen tür', () async {
      expect(() => service.add(type: glucose, value: 100, unit: 'mg'), _violation(RuleCodes.readingUnitInvalid));
      expect(() => service.add(type: bp, value: 120, value2: 80, unit: 'kPa'), _violation(RuleCodes.readingUnitInvalid));
      expect(() => service.add(type: glucose, value: 100, context: 'brunch'), _violation(RuleCodes.readingContextInvalid));
      expect(() => service.add(type: MeasurementTypes.weight, value: 70), _violation(RuleCodes.readingTypeUnknown));
    });

    test('boş bağlam yazısı boş sayılır; boş birim temel birim sayılır', () async {
      final m = await service.add(type: glucose, value: 100, unit: '', context: '');
      expect((m.context, m.unit, m.value), (null, 'mg/dL', 100.0));
    });
  });

  group('an ve not', () {
    test('geçmiş an kabul edilir; gün anın yerel gününden türetilir', () async {
      final m = await service.add(type: pulse, value: 70, measuredAt: DateTime(2026, 11, 3, 23, 50));
      expect(m.logDate, '2026-11-03');
      expect(m.measuredAt, DateTime(2026, 11, 3, 23, 50));
    });

    test('gelecek an reddedilir; 5 dakikalık tolerans içinde kabul edilir', () async {
      expect(() => service.add(type: pulse, value: 70, measuredAt: now.add(const Duration(minutes: 6))),
          _violation(RuleCodes.measurementDayInFuture));
      await service.add(type: pulse, value: 70, measuredAt: now.add(const Duration(minutes: 5)));
      expect(() => service.add(type: pulse, value: 70, measuredAt: DateTime(2026, 11, 11, 8)),
          _violation(RuleCodes.measurementDayInFuture));
    });

    test('1900 öncesi tarih geçersiz', () async {
      expect(() => service.add(type: pulse, value: 70, measuredAt: DateTime(1899, 12, 31)),
          _violation(RuleCodes.measurementDayInvalid));
    });

    test('not kırpılır; boş not boş sayılır; 500 karakter sınırı', () async {
      final a = await service.add(type: pulse, value: 70, notes: '  sabah  ');
      expect(a.notes, 'sabah');
      final b = await service.add(type: pulse, value: 70, notes: '   ');
      expect(b.notes, isNull);
      await service.add(type: pulse, value: 70, notes: 'a' * 500);
      expect(() => service.add(type: pulse, value: 70, notes: 'a' * 501), _violation(RuleCodes.readingNoteTooLong));
    });
  });

  group('listeleme', () {
    test('aynı gün birden fazla ölçüm; list en yeni önce, gün süzgeci dahil', () async {
      await service.add(type: bp, value: 118, value2: 76, measuredAt: DateTime(2026, 11, 9, 8));
      await service.add(type: bp, value: 126, value2: 82, measuredAt: DateTime(2026, 11, 10, 8));
      await service.add(type: bp, value: 130, value2: 84, measuredAt: DateTime(2026, 11, 10, 11));
      expect((await service.list(bp)).map((m) => m.value), [130.0, 126.0, 118.0]);
      expect((await service.list(bp, fromDay: '2026-11-10')).map((m) => m.value), [130.0, 126.0]);
      expect((await service.list(bp, toDay: '2026-11-09')).map((m) => m.value), [118.0]);
      expect(() => service.list('weight'), _violation(RuleCodes.readingTypeUnknown));
    });

    test('listForDay tüm sağlık türlerini saat sırasıyla verir, kilo ve silinenleri almaz', () async {
      await service.add(type: glucose, value: 100, context: 'fasting', measuredAt: DateTime(2026, 11, 10, 7));
      await service.add(type: pulse, value: 70, measuredAt: DateTime(2026, 11, 10, 9));
      final gone = await service.add(type: bp, value: 120, value2: 80, measuredAt: DateTime(2026, 11, 10, 8));
      await service.add(type: bp, value: 125, value2: 82, measuredAt: DateTime(2026, 11, 10, 10));
      await service.add(type: pulse, value: 65, measuredAt: DateTime(2026, 11, 9, 9));
      await measurements.add(type: MeasurementTypes.weight, value: 72, unit: 'kg', measuredAt: DateTime(2026, 11, 10, 6));
      await service.delete(gone.id);

      final day = await service.listForDay('2026-11-10');
      expect(day.map((m) => m.type), [glucose, pulse, bp]);
      expect(day.map((m) => m.measuredAt.hour), [7, 9, 10]);
    });

    test('latest türün en son ölçümünü verir', () async {
      expect(await service.latest(pulse), isNull);
      await service.add(type: pulse, value: 60, measuredAt: DateTime(2026, 11, 9, 9));
      await service.add(type: pulse, value: 80, measuredAt: DateTime(2026, 11, 10, 9));
      expect((await service.latest(pulse))!.value, 80.0);
    });
  });

  group('düzenleme', () {
    test('değerleri, anı, günü ve notu değiştirir; tür ve kimlik aynı kalır', () async {
      final m = await service.add(type: glucose, value: 100, context: 'fasting', notes: 'ilk', measuredAt: DateTime(2026, 11, 10, 7));
      final u = await service.update(
        m.id,
        value: 7.0,
        unit: 'mmol/L',
        context: ReadingContexts.afterMeal,
        notes: 'tok',
        measuredAt: DateTime(2026, 11, 9, 14),
      );
      expect(u.id, m.id);
      expect(u.type, glucose);
      expect(u.value, closeTo(7.0 * 18.016, 1e-9));
      expect(u.unit, 'mg/dL');
      expect((u.context, u.notes, u.logDate), ('after_meal', 'tok', '2026-11-09'));
      expect(u.measuredAt, DateTime(2026, 11, 9, 14));
      expect(u.updatedAt, now);
      expect((await measurements.listByType(glucose)), hasLength(1));
    });

    test('verilmeyen bağlam, ikinci değer ve not boşalır; an verilmezse eski an kalır', () async {
      final g = await service.add(type: glucose, value: 100, context: 'fasting', notes: 'x', measuredAt: DateTime(2026, 11, 10, 7));
      final ug = await service.update(g.id, value: 110);
      expect((ug.context, ug.notes, ug.measuredAt), (null, null, DateTime(2026, 11, 10, 7)));

      final p = await service.add(type: bp, value: 120, value2: 80);
      final up = await service.update(p.id, value: 130, value2: 85);
      expect((up.value, up.value2), (130.0, 85.0));
    });

    test('doğrulama düzenlemede de çalışır ve kayıt değişmez', () async {
      final m = await service.add(type: bp, value: 120, value2: 80);
      expect(() => service.update(m.id, value: 120), _violation(RuleCodes.readingSecondValueRequired));
      expect(() => service.update(m.id, value: 70, value2: 80), _violation(RuleCodes.readingFirstNotAboveSecond));
      expect(() => service.update(m.id, value: 300, value2: 80), _violation(RuleCodes.readingValueOutOfRange));
      expect(() => service.update(m.id, value: 120, value2: 80, measuredAt: now.add(const Duration(days: 1))),
          _violation(RuleCodes.measurementDayInFuture));
      final still = (await measurements.findById(m.id))!;
      expect((still.value, still.value2), (120.0, 80.0));
    });

    test('olmayan, silinmiş ya da başka türden kayıt bulunamaz', () async {
      expect(() => service.update('yok', value: 70), _violation(RuleCodes.readingNotFound));
      final m = await service.add(type: pulse, value: 70);
      await service.delete(m.id);
      expect(() => service.update(m.id, value: 71), _violation(RuleCodes.readingNotFound));
      final w = await measurements.add(type: MeasurementTypes.weight, value: 72, unit: 'kg', measuredAt: now);
      expect(() => service.update(w.id, value: 73), _violation(RuleCodes.readingNotFound));
      expect((await measurements.findById(w.id))!.value, 72.0);
    });
  });

  group('silme', () {
    test('ölçümü siler; ikinci kez ve kilo silinemez', () async {
      final m = await service.add(type: pulse, value: 70);
      await service.delete(m.id);
      expect(await service.list(pulse), isEmpty);
      expect(() => service.delete(m.id), _violation(RuleCodes.readingNotFound));
      final w = await measurements.add(type: MeasurementTypes.weight, value: 72, unit: 'kg', measuredAt: now);
      expect(() => service.delete(w.id), _violation(RuleCodes.readingNotFound));
      expect(await measurements.findById(w.id), isNotNull);
    });
  });

  group('gösterim birimi tercihi', () {
    test('varsayılan temel birim; ayarlanınca kalıcı olur; türler ayrı', () async {
      expect(await service.preferredUnit(glucose), 'mg/dL');
      await service.setPreferredUnit(glucose, 'mmol/L');
      expect(await service.preferredUnit(glucose), 'mmol/L');
      // Yeni servis örneği (yeniden açılış) aynı tercihi okur.
      final again = ReadingService(measurements: measurements, settings: settings, clock: () => now);
      expect(await again.preferredUnit(glucose), 'mmol/L');
      expect(await again.preferredUnit(bp), 'mmHg');
    });

    test('geçersiz birim ve tür reddedilir; bozuk kayıtlı değer temel birime döner', () async {
      expect(() => service.setPreferredUnit(glucose, 'mg'), _violation(RuleCodes.readingUnitInvalid));
      expect(() => service.setPreferredUnit(bp, 'mmol/L'), _violation(RuleCodes.readingUnitInvalid));
      expect(() => service.setPreferredUnit('weight', 'kg'), _violation(RuleCodes.readingTypeUnknown));
      expect(() => service.preferredUnit('weight'), _violation(RuleCodes.readingTypeUnknown));
      await settings.set('${ReadingService.unitSettingPrefix}$glucose', 'bozuk');
      expect(await service.preferredUnit(glucose), 'mg/dL');
    });
  });
}
