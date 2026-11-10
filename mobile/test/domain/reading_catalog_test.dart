import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/database/enums.dart';
import 'package:mobile/domain/reading_catalog.dart';

void main() {
  group('katalog yapısı', () {
    test('üç tür tanımlı, türler tekil ve MeasurementTypes anahtarlarıyla eşleşir', () {
      final types = ReadingCatalog.all.map((k) => k.type).toList();
      expect(types, [
        MeasurementTypes.bloodPressure,
        MeasurementTypes.pulse,
        MeasurementTypes.bloodGlucose,
      ]);
      expect(types.toSet(), hasLength(types.length));
      expect(ReadingCatalog.of(MeasurementTypes.pulse), same(ReadingCatalog.pulse));
      expect(ReadingCatalog.of('weight'), isNull);
    });

    test('her türün ilk birimi temel birimdir (çarpan 1) ve aralıklar tutarlıdır', () {
      for (final kind in ReadingCatalog.all) {
        expect(kind.baseUnit.factorToBase, 1, reason: kind.type);
        expect(kind.min, lessThan(kind.max), reason: kind.type);
        expect(kind.units.map((u) => u.code).toSet(), hasLength(kind.units.length));
        if (kind.hasSecond) {
          expect(kind.min2, isNotNull);
          expect(kind.max2, isNotNull);
          expect(kind.min2!, lessThan(kind.max2!));
        } else {
          expect(kind.min2, isNull);
          expect(kind.max2, isNull);
        }
      }
    });

    test('belirlenen aralıklar ve bağlamlar', () {
      const bp = ReadingCatalog.bloodPressure;
      expect((bp.min, bp.max, bp.min2, bp.max2), (60, 260, 30, 150));
      expect(bp.baseUnit.code, 'mmHg');
      expect(bp.contexts, isEmpty);

      const glucose = ReadingCatalog.bloodGlucose;
      expect((glucose.min, glucose.max), (20, 600));
      expect(glucose.units.map((u) => u.code), ['mg/dL', 'mmol/L']);
      expect(glucose.contexts, [
        ReadingContexts.fasting,
        ReadingContexts.afterMeal,
        ReadingContexts.beforeSleep,
        ReadingContexts.other,
      ]);
      expect(glucose.hasSecond, isFalse);

      const pulse = ReadingCatalog.pulse;
      expect((pulse.min, pulse.max, pulse.baseUnit.code), (20, 250, 'bpm'));
    });
  });

  group('şeker birim dönüşümü', () {
    const glucose = ReadingCatalog.bloodGlucose;

    test('mmol/L girişi mg/dL olarak, yuvarlanmadan saklanacak değere çevrilir', () {
      expect(glucose.toBase(5.5, 'mmol/L'), closeTo(99.088, 1e-9));
      expect(glucose.toBase(100, 'mg/dL'), 100);
      expect(glucose.toBase(1, 'mmol/L'), 18.016);
    });

    test('gidiş-dönüşte değer kaymaz', () {
      for (final mmol in [3.0, 4.4, 5.5, 7.8, 11.1, 33.3]) {
        final back = glucose.fromBase(glucose.toBase(mmol, 'mmol/L'), 'mmol/L');
        expect(back, closeTo(mmol, 1e-12));
      }
      expect(glucose.fromBase(99.088, 'mmol/L'), closeTo(5.5, 1e-9));
      expect(glucose.fromBase(120, 'mg/dL'), 120);
    });

    test('ondalık basamak: mg/dL 0, mmol/L 1', () {
      expect(glucose.unitOf('mg/dL').decimals, 0);
      expect(glucose.unitOf('mmol/L').decimals, 1);
    });

    test('bilinmeyen birim hata verir; hasUnit denetler', () {
      expect(glucose.hasUnit('mmol/L'), isTrue);
      expect(glucose.hasUnit('mg'), isFalse);
      expect(() => glucose.toBase(5, 'mg'), throwsArgumentError);
    });

    test('birim değişse de aralık temel birimde denetlenir', () {
      // 20 mg/dL ≈ 1,11 mmol/L; 600 mg/dL ≈ 33,3 mmol/L
      expect(glucose.toBase(1.2, 'mmol/L'), greaterThanOrEqualTo(glucose.min));
      expect(glucose.toBase(1.0, 'mmol/L'), lessThan(glucose.min));
      expect(glucose.toBase(33.0, 'mmol/L'), lessThanOrEqualTo(glucose.max));
      expect(glucose.toBase(34.0, 'mmol/L'), greaterThan(glucose.max));
    });
  });
}
