// Ek günlük alanları servisi: hazır alanlar, kendi alanları, değerler.
// Gerçek (bellek içi) Drift veritabanıyla çalışır.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/enums.dart';
import 'package:mobile/data/repositories/daily_field_repository.dart';
import 'package:mobile/data/repositories/measurement_repository.dart';
import 'package:mobile/domain/errors.dart';
import 'package:mobile/domain/services/daily_field_service.dart';

import '../data/test_support.dart';

/// Yazma anında hata verebilen ölçüm deposu (geri alma testi için).
class _FailingAddRepository extends DriftMeasurementRepository {
  _FailingAddRepository(super.db);
  bool failAdd = false;

  @override
  Future<Measurement> add({
    required String type,
    required double value,
    required DateTime measuredAt,
    String unit = '',
    String? notes,
  }) {
    if (failAdd) throw StateError('yazılamadı');
    return super.add(type: type, value: value, measuredAt: measuredAt, unit: unit, notes: notes);
  }
}

Matcher _violation(String code) =>
    throwsA(isA<RuleViolation>().having((e) => e.code, 'code', code));

void main() {
  late AppDatabase db;
  late _FailingAddRepository measurements;
  late DailyFieldService service;

  // "Bugün" sabit: 2026-11-08 12:00.
  setUp(() {
    db = createTestDb();
    measurements = _FailingAddRepository(db);
    service = DailyFieldService(
      fields: DriftDailyFieldRepository(db),
      measurements: measurements,
      clock: () => DateTime(2026, 11, 8, 12),
      transactor: db.transaction,
    );
  });
  tearDown(() => db.close());

  Future<List<Measurement>> liveRows(String type) => (db.select(db.measurements)
        ..where((t) => t.deletedAt.isNull() & t.type.equals(type))
        ..orderBy([(t) => OrderingTerm.asc(t.measuredAt)]))
      .get();

  Future<DailyField> custom(String name,
          {String kind = DailyFieldKinds.number, String unit = '', double? min, double? max}) =>
      service.create(name: name, kind: kind, unit: unit, min: min, max: max);

  group('hazır alanlar', () {
    test('kafein, spor, ağrı düzeyi ve adım sayısı kapalı olarak eklenir; tekrar çağırmak çoğaltmaz', () async {
      await service.ensurePresets();
      await service.ensurePresets();
      final all = await service.list();
      expect(all.map((f) => f.builtinKey), [
        MeasurementTypes.caffeine,
        MeasurementTypes.exercise,
        MeasurementTypes.pain,
        MeasurementTypes.steps,
      ]);
      final steps = all.last;
      expect(steps.name, 'Adım sayısı');
      expect(steps.unit, 'adım');
      expect(steps.maxValue, 100000);
      expect(all.every((f) => !f.isActive), isTrue);
      expect(all.first.unit, 'bardak');
      expect(all.first.maxValue, 20);
      expect(await service.listActive(), isEmpty);
    });

    test('kullanıcının aynı adlı alanı varsa hazır alan çakışmaz', () async {
      await custom('KAFEİN');
      await service.ensurePresets();
      final names = (await service.list()).map((f) => f.name).toList();
      expect(names, contains('KAFEİN'));
      expect(names, contains('Kafein (hazır)'));
    });

    test('hazır alan açılınca değer yazılır ve türü hazır anahtardır', () async {
      await service.ensurePresets();
      final caffeine = (await service.list()).firstWhere((f) => f.builtinKey == 'caffeine');
      await service.setActive(caffeine.id, true);
      await service.setValue(caffeine.id, '2026-11-08', 3);
      expect((await liveRows(MeasurementTypes.caffeine)).single.value, 3);
    });

    test('hazır alanın adı ve sınırı değiştirilemez', () async {
      await service.ensurePresets();
      final f = (await service.list()).first;
      expect(() => service.update(f.id, name: 'Başka'), _violation(RuleCodes.dailyFieldBuiltin));
    });
  });

  group('kendi alanı ekleme', () {
    test('ad kırpılır, alan açık başlar, sıra artar', () async {
      final a = await custom('  Yürüyüş ', unit: ' km ', min: 0, max: 50);
      final b = await custom('Çay');
      expect(a.name, 'Yürüyüş');
      expect(a.unit, 'km');
      expect(a.isActive, isTrue);
      expect(b.sortOrder, a.sortOrder + 1);
      expect((await service.listActive()).map((f) => f.name), ['Yürüyüş', 'Çay']);
    });

    test('sayı alanında sınır verilmezse 0-1000 olur', () async {
      final f = await custom('Adım');
      expect(f.minValue, 0);
      expect(f.maxValue, 1000);
    });

    test('ölçek 1-5, evet/hayır 0-1 olur; birim yok sayılır', () async {
      final s = await custom('Stres', kind: DailyFieldKinds.scale, unit: 'x', min: 3, max: 9);
      final y = await custom('Spor yaptım', kind: DailyFieldKinds.yesNo, unit: 'x');
      expect((s.minValue, s.maxValue, s.unit), (1.0, 5.0, ''));
      expect((y.minValue, y.maxValue, y.unit), (0.0, 1.0, ''));
    });

    test('boş, çok uzun ve aynı (Türkçe büyük/küçük harf farkıyla) ad reddedilir', () async {
      expect(() => custom('   '), _violation(RuleCodes.dailyFieldNameEmpty));
      expect(() => custom('a' * 41), _violation(RuleCodes.dailyFieldNameTooLong));
      await custom('Çay');
      expect(() => custom('çay'), _violation(RuleCodes.dailyFieldNameExists));
      await custom('Işık');
      expect(() => custom('IŞIK'), _violation(RuleCodes.dailyFieldNameExists));
    });

    test('geçersiz tür, uzun birim ve bozuk sınır reddedilir', () async {
      expect(() => custom('X', kind: 'metin'), _violation(RuleCodes.dailyFieldKindInvalid));
      expect(() => custom('X', unit: 'a' * 13), _violation(RuleCodes.dailyFieldUnitTooLong));
      expect(() => custom('X', min: 5, max: 5), _violation(RuleCodes.dailyFieldRangeInvalid));
      expect(() => custom('X', min: 9, max: 2), _violation(RuleCodes.dailyFieldRangeInvalid));
      expect(() => custom('X', max: double.nan), _violation(RuleCodes.dailyFieldRangeInvalid));
      expect(() => custom('X', max: 2000000), _violation(RuleCodes.dailyFieldRangeInvalid));
      expect(await service.list(), isEmpty);
    });

    test('en çok 30 kendi alanı eklenebilir; hazır alanlar sayılmaz', () async {
      await service.ensurePresets();
      for (var i = 0; i < DailyFieldService.maxCustomFields; i++) {
        await custom('Alan $i');
      }
      expect(() => custom('Fazla'), _violation(RuleCodes.dailyFieldTooMany));
    });
  });

  group('alan düzenleme ve kapatma', () {
    test('kendi alanının adı, birimi ve sınırı değişir; tür değişmez; kendi adı yeniden verilebilir', () async {
      final f = await custom('Adım', unit: 'adet', min: 0, max: 20000);
      final u = await service.update(f.id, name: 'Adım', unit: 'bin', min: 0, max: 50);
      expect(u.unit, 'bin');
      expect(u.maxValue, 50);
      expect(u.kind, DailyFieldKinds.number);
      final renamed = await service.update(f.id, name: ' Yürüyüş ');
      expect(renamed.name, 'Yürüyüş');
    });

    test('başka alanın adına değiştirmek ve bulunmayan alan reddedilir', () async {
      await custom('Çay');
      final f = await custom('Kahve');
      expect(() => service.update(f.id, name: 'çay'), _violation(RuleCodes.dailyFieldNameExists));
      expect(() => service.update('yok', name: 'X'), _violation(RuleCodes.dailyFieldNotFound));
      expect(() => service.setActive('yok', true), _violation(RuleCodes.dailyFieldNotFound));
    });

    test('kapatmak değerleri silmez; kapalı alana yazılmaz; yeniden açınca değer yerinde', () async {
      final f = await custom('Çay', max: 20);
      await service.setValue(f.id, '2026-11-08', 4);
      await service.setActive(f.id, false);

      expect(await service.listActive(), isEmpty);
      final day = await service.valuesForDay('2026-11-08');
      expect(day.single.field.isActive, isFalse);
      expect(day.single.value, 4);
      expect(() => service.setValue(f.id, '2026-11-08', 5), _violation(RuleCodes.dailyFieldInactive));

      await service.setActive(f.id, true);
      expect((await service.valuesForDay('2026-11-08')).single.value, 4);
    });
  });

  group('değer yazma', () {
    test('kendi alanının türü field: önekli kimliktir; birim ölçüme yazılır', () async {
      final f = await custom('Yürüyüş', unit: 'km', max: 50);
      await service.setValue(f.id, '2026-11-08', 3.5);
      final rows = await liveRows('${MeasurementTypes.customFieldPrefix}${f.id}');
      expect(rows.single.value, 3.5);
      expect(rows.single.unit, 'km');
      expect(rows.single.logDate, '2026-11-08');
    });

    test('aynı güne ikinci yazış öncekinin yerine geçer; başka gün etkilenmez', () async {
      final f = await custom('Çay', max: 20);
      await service.setValue(f.id, '2026-11-07', 2);
      await service.setValue(f.id, '2026-11-08', 3);
      await service.setValue(f.id, '2026-11-08', 5);
      final rows = await liveRows('${MeasurementTypes.customFieldPrefix}${f.id}');
      expect(rows.map((r) => (r.logDate, r.value)), [('2026-11-07', 2.0), ('2026-11-08', 5.0)]);
      expect((await service.valuesForDay('2026-11-08')).single.value, 5);
      expect((await service.valuesForDay('2026-11-07')).single.value, 2);
    });

    test('bugün için şimdiki an, geçmiş gün için yerel öğlen kullanılır', () async {
      final f = await custom('Çay', max: 20);
      await service.setValue(f.id, '2026-11-08', 1);
      await service.setValue(f.id, '2026-11-02', 1);
      final rows = await liveRows('${MeasurementTypes.customFieldPrefix}${f.id}');
      expect(rows.first.measuredAt, DateTime(2026, 11, 2, 12));
      expect(rows.last.measuredAt, DateTime(2026, 11, 8, 12));
    });

    test('sayı değeri tek ondalığa yuvarlanır; sınır dışı ve bozuk değer reddedilir', () async {
      final f = await custom('Çay', min: 0, max: 20);
      await service.setValue(f.id, '2026-11-08', 2.46);
      expect((await service.valuesForDay('2026-11-08')).single.value, 2.5);
      expect(() => service.setValue(f.id, '2026-11-08', -1), _violation(RuleCodes.dailyFieldValueInvalid));
      expect(() => service.setValue(f.id, '2026-11-08', 20.1), _violation(RuleCodes.dailyFieldValueInvalid));
      expect(() => service.setValue(f.id, '2026-11-08', double.nan), _violation(RuleCodes.dailyFieldValueInvalid));
      expect(() => service.setValue(f.id, '2026-11-08', double.infinity), _violation(RuleCodes.dailyFieldValueInvalid));
      // Reddedilen yazış öncekini bozmadı.
      expect((await service.valuesForDay('2026-11-08')).single.value, 2.5);
    });

    test('ölçek yalnız 1-5 tam sayı; evet/hayır yalnız 0 ya da 1', () async {
      final s = await custom('Stres', kind: DailyFieldKinds.scale);
      final y = await custom('Spor yaptım', kind: DailyFieldKinds.yesNo);
      await service.setValue(s.id, '2026-11-08', 4);
      await service.setValue(y.id, '2026-11-08', 1);
      for (final bad in [0.0, 6.0, 2.5]) {
        expect(() => service.setValue(s.id, '2026-11-08', bad), _violation(RuleCodes.dailyFieldValueInvalid));
      }
      for (final bad in [2.0, 0.5, -1.0]) {
        expect(() => service.setValue(y.id, '2026-11-08', bad), _violation(RuleCodes.dailyFieldValueInvalid));
      }
    });

    test('geçersiz ve gelecek gün reddedilir; bulunmayan alan reddedilir', () async {
      final f = await custom('Çay', max: 20);
      expect(() => service.setValue(f.id, '2026-11-09', 1), _violation(RuleCodes.measurementDayInFuture));
      expect(() => service.setValue(f.id, '2026-02-30', 1), _violation(RuleCodes.measurementDayInvalid));
      expect(() => service.setValue(f.id, '1899-01-01', 1), _violation(RuleCodes.measurementDayInvalid));
      expect(() => service.setValue(f.id, 'dün', 1), _violation(RuleCodes.measurementDayInvalid));
      expect(() => service.setValue('yok', '2026-11-08', 1), _violation(RuleCodes.dailyFieldNotFound));
      expect(await liveRows('${MeasurementTypes.customFieldPrefix}${f.id}'), isEmpty);
    });

    test('yazma yarıda kalırsa eski değer geri gelir (tek işlem)', () async {
      final f = await custom('Çay', max: 20);
      await service.setValue(f.id, '2026-11-08', 3);
      measurements.failAdd = true;
      await expectLater(() => service.setValue(f.id, '2026-11-08', 9), throwsStateError);
      measurements.failAdd = false;
      expect((await service.valuesForDay('2026-11-08')).single.value, 3);
    });

    test('değer silinir; alan ve başka günler kalır', () async {
      final f = await custom('Çay', max: 20);
      await service.setValue(f.id, '2026-11-07', 2);
      await service.setValue(f.id, '2026-11-08', 3);
      await service.clearValue(f.id, '2026-11-08');
      expect((await service.valuesForDay('2026-11-08')).single.value, isNull);
      expect((await service.valuesForDay('2026-11-07')).single.value, 2);
      expect(await service.list(), hasLength(1));
    });

    test('dört çekirdek günlük alanı ve günlük kayıt tablosu etkilenmez', () async {
      final f = await custom('Çay', max: 20);
      await service.setValue(f.id, '2026-11-08', 3);
      expect(await db.select(db.dailyLogs).get(), isEmpty);
    });
  });
}
