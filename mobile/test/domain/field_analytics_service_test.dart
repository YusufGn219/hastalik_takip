// Ek alanların analizi: dönem sınırı, semptomlu/semptomsuz gün ortalaması,
// güvenilirlik eşiği. Gerçek (bellek içi) Drift veritabanıyla çalışır.

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/enums.dart';
import 'package:mobile/data/repositories/daily_field_repository.dart';
import 'package:mobile/data/repositories/measurement_repository.dart';
import 'package:mobile/data/repositories/symptom_entry_repository.dart';
import 'package:mobile/domain/services/daily_field_service.dart';
import 'package:mobile/domain/services/field_analytics_service.dart';

import '../data/test_support.dart';

void main() {
  late AppDatabase db;
  late DailyFieldService fields;
  late FieldAnalyticsService analytics;
  late DriftSymptomEntryRepository entries;
  late String symptomId;

  // "Bugün" sabit: 2026-11-08 12:00. 7 günlük pencere 2026-11-02 ile başlar.
  DateTime clock() => DateTime(2026, 11, 8, 12);

  setUp(() async {
    db = createTestDb();
    await seedLoaderFor(db).seedIfNeeded();
    symptomId = (await db.select(db.symptoms).get()).first.id;
    final measurements = DriftMeasurementRepository(db);
    entries = DriftSymptomEntryRepository(db);
    fields = DailyFieldService(
      fields: DriftDailyFieldRepository(db),
      measurements: measurements,
      clock: clock,
      transactor: db.transaction,
    );
    analytics = FieldAnalyticsService(
      fields: fields,
      measurements: measurements,
      entries: entries,
      clock: clock,
    );
  });
  tearDown(() => db.close());

  Future<DailyField> custom(String name,
          {String kind = DailyFieldKinds.number}) =>
      fields.create(name: name, kind: kind);

  Future<void> symptomOn(String day, {int hour = 10}) {
    final p = day.split('-').map(int.parse).toList();
    return entries.create(
      symptomId: symptomId,
      severity: 5,
      timestamp: DateTime(p[0], p[1], p[2], hour),
    );
  }

  test('değeri olmayan alan listede çıkmaz; boş durumda liste boştur', () async {
    await custom('Boş alan');
    final r = await analytics.analyze(30);
    expect(r.series, isEmpty);
    expect(r.periodDays, 30);
  });

  test('dönem sınırı: ilk gün dahil, bir önceki gün dışarıda', () async {
    final f = await custom('Kahve');
    await fields.setValue(f.id, '2026-11-01', 9); // pencere dışı
    await fields.setValue(f.id, '2026-11-02', 2); // tam sınır, içeride
    await fields.setValue(f.id, '2026-11-08', 4); // bugün
    final s = (await analytics.analyze(7)).series.single;
    expect(s.dates, ['2026-11-02', '2026-11-08']);
    expect(s.values, [2, 4]);
  });

  test('kapatılmış alanın geçmiş değerleri hâlâ analizde görünür', () async {
    final f = await custom('Şeker');
    await fields.setValue(f.id, '2026-11-05', 3);
    await fields.setActive(f.id, false);
    final r = await analytics.analyze(30);
    expect(r.series.single.field.id, f.id);
    expect(r.series.single.values, [3]);
  });

  test('semptomlu ve semptomsuz günlerin ortalaması ayrı hesaplanır', () async {
    final f = await custom('Kahve');
    // Semptomlu günler: 3, 4, 5 → değerler 6, 8, 10 (ortalama 8).
    for (final (d, v) in [('2026-11-03', 6.0), ('2026-11-04', 8.0), ('2026-11-05', 10.0)]) {
      await fields.setValue(f.id, d, v);
      await symptomOn(d);
    }
    // Semptomsuz günler: 6, 7 → değerler 1, 3 (ortalama 2).
    await fields.setValue(f.id, '2026-11-06', 1);
    await fields.setValue(f.id, '2026-11-07', 3);

    final rel = (await analytics.analyze(30)).series.single.relation;
    expect(rel.withSymptom.days, 3);
    expect(rel.withSymptom.average, 8);
    expect(rel.withoutSymptom.days, 2);
    expect(rel.withoutSymptom.average, 2);
  });

  test('değeri girilmemiş semptomlu gün gruba girmez', () async {
    final f = await custom('Kahve');
    await fields.setValue(f.id, '2026-11-05', 4);
    await symptomOn('2026-11-06'); // o gün alan değeri yok
    final rel = (await analytics.analyze(30)).series.single.relation;
    expect(rel.withSymptom.days, 0);
    expect(rel.withSymptom.average, isNull);
    expect(rel.withoutSymptom.days, 1);
  });

  test('dönemden önceki semptom o günü semptomlu yapmaz', () async {
    final f = await custom('Kahve');
    await fields.setValue(f.id, '2026-11-02', 4);
    // 1 Kasım gece yarısına yakın; pencere dışı. 2 Kasım'da semptom yok.
    await symptomOn('2026-11-01', hour: 23);
    final rel = (await analytics.analyze(7)).series.single.relation;
    expect(rel.withSymptom.days, 0);
    expect(rel.withoutSymptom.days, 1);
  });

  test('güvenilirlik eşiği: her iki grupta da en az 5 gün', () {
    const four = FieldGroup(4, 1);
    const five = FieldGroup(5, 1);
    expect(FieldRelation(five, five).isReliable(5), isTrue);
    expect(FieldRelation(five, four).isReliable(5), isFalse);
    expect(FieldRelation(four, five).isReliable(5), isFalse);
    expect(FieldAnalyticsService.minRelationDays, 5);
  });

  test('evet/hayır alanında ortalama evet oranıdır', () async {
    final f = await custom('İlaç dışı destek', kind: DailyFieldKinds.yesNo);
    await fields.setValue(f.id, '2026-11-04', 1);
    await fields.setValue(f.id, '2026-11-05', 0);
    await fields.setValue(f.id, '2026-11-06', 1);
    await symptomOn('2026-11-04');
    await symptomOn('2026-11-05');
    final rel = (await analytics.analyze(30)).series.single.relation;
    expect(rel.withSymptom.average, 0.5);
    expect(rel.withoutSymptom.average, 1);
  });
}
