// Zaman çizelgesinde sağlık ölçümleri: gösterim, birim tercihi, bağlam, gün
// gezinmesi, kilo ve silinenlerin dışarıda kalması, hata yolu. Gerçek (bellek içi)
// veritabanı.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/enums.dart';
import 'package:mobile/data/repositories/daily_log_repository.dart';
import 'package:mobile/data/repositories/measurement_repository.dart';
import 'package:mobile/data/repositories/settings_repository.dart';
import 'package:mobile/domain/reading_catalog.dart';
import 'package:mobile/domain/services/reading_service.dart';
import 'package:mobile/features/timeline/screens/day_timeline_screen.dart';
import 'package:mobile/features/timeline/timeline_day.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../data/test_support.dart';
import '../support/fake_measurement_repository.dart';

/// Saat: 2026-11-10 Salı 12:00.
DateTime _now() => DateTime(2026, 11, 10, 12, 0);

class _BrokenMeasurementRepository extends DriftMeasurementRepository {
  _BrokenMeasurementRepository(super.db);

  @override
  Future<List<Measurement>> listByType(String type, {String? fromDate, String? toDate}) =>
      throw StateError('okunamadı');
}

void main() {
  late AppDatabase db;
  late ReadingService service;

  setUp(() {
    db = createTestDb();
    service = ReadingService(
      measurements: DriftMeasurementRepository(db, clock: _now),
      settings: DriftSettingsRepository(db),
      clock: _now,
    );
  });
  tearDown(() => db.close());

  Future<void> openApp(WidgetTester tester, {List<Override>? extra}) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(_now),
        ...?extra,
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const DayTimelineScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<Measurement> add(
    WidgetTester tester,
    String type,
    double value, {
    double? value2,
    String? unit,
    String? context,
    required DateTime at,
  }) =>
      tester
          .runAsync(() => service.add(
                type: type,
                value: value,
                value2: value2,
                unit: unit,
                context: context,
                measuredAt: at,
              ))
          .then((v) => v!);

  testWidgets('günün ölçümleri saat sırasıyla, tür adı, değer ve birimle görünür', (tester) async {
    final bp = await add(tester, MeasurementTypes.bloodPressure, 120, value2: 80, at: DateTime(2026, 11, 10, 8, 30));
    final pulse = await add(tester, MeasurementTypes.pulse, 72, at: DateTime(2026, 11, 10, 8, 31));
    final glucose = await add(
      tester,
      MeasurementTypes.bloodGlucose,
      105,
      context: ReadingContexts.fasting,
      at: DateTime(2026, 11, 10, 7, 15),
    );

    await openApp(tester);

    expect(find.byKey(const ValueKey('timeline-readings')), findsOneWidget);
    expect(find.text('Sağlık ölçümleri'), findsOneWidget);
    expect(find.text('08:30 Tansiyon 120/80 mmHg'), findsOneWidget);
    expect(find.text('08:31 Nabız 72 bpm'), findsOneWidget);
    expect(find.text('07:15 Kan şekeri 105 mg/dL · Açlık'), findsOneWidget);
    // Saat sırası: şeker, tansiyon, nabız.
    double top(String id) => tester.getTopLeft(find.byKey(ValueKey('timeline-reading-$id'))).dy;
    expect(top(glucose.id), lessThan(top(bp.id)));
    expect(top(bp.id), lessThan(top(pulse.id)));
  });

  testWidgets('şeker seçili birimde görünür (mmol/L)', (tester) async {
    await tester.runAsync(() => service.setPreferredUnit(MeasurementTypes.bloodGlucose, 'mmol/L'));
    await add(tester, MeasurementTypes.bloodGlucose, 5.5, unit: 'mmol/L', at: DateTime(2026, 11, 10, 9));
    await openApp(tester);
    expect(find.text('09:00 Kan şekeri 5,5 mmol/L'), findsOneWidget);
  });

  testWidgets('ölçüm yokken bölüm ve başlık görünmez; kilo ve silinen ölçüm sayılmaz', (tester) async {
    await openApp(tester);
    expect(find.byKey(const ValueKey('timeline-readings')), findsNothing);
    expect(find.text('Sağlık ölçümleri'), findsNothing);

    await tester.runAsync(() => DriftMeasurementRepository(db, clock: _now).add(
          type: MeasurementTypes.weight,
          value: 72,
          unit: 'kg',
          measuredAt: DateTime(2026, 11, 10, 6),
        ));
    final gone = await add(tester, MeasurementTypes.pulse, 70, at: DateTime(2026, 11, 10, 7));
    await tester.runAsync(() => service.delete(gone.id));

    await openApp(tester);
    expect(find.byKey(const ValueKey('timeline-readings')), findsNothing);
  });

  test('yalnız ölçüm olan gün (okuma modelinde) boş sayılmaz', () {
    final m = FakeMeasurementRepository().seed(MeasurementTypes.pulse, 70, _now(), unit: 'bpm');
    expect(const TimelineDay(day: '2026-11-10', dailyLog: null, items: []).isEmpty, isTrue);
    expect(TimelineDay(day: '2026-11-10', dailyLog: null, items: const [], readings: [m]).isEmpty, isFalse);
  });

  testWidgets('önceki güne geçince o günün ölçümleri görünür, bugünküler görünmez', (tester) async {
    await add(tester, MeasurementTypes.pulse, 70, at: DateTime(2026, 11, 10, 7));
    await add(tester, MeasurementTypes.pulse, 65, at: DateTime(2026, 11, 9, 21));

    await openApp(tester);
    expect(find.text('07:00 Nabız 70 bpm'), findsOneWidget);
    expect(find.textContaining('65'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('timeline-prev')));
    await tester.pumpAndSettle();
    expect(find.text('21:00 Nabız 65 bpm'), findsOneWidget);
    expect(find.textContaining('70 bpm'), findsNothing);
  });

  testWidgets('ölçümler okunamazsa çizelge yine açılır, günlük kart görünür', (tester) async {
    await tester.runAsync(() => DriftDailyLogRepository(db).upsert(
          logDate: '2026-11-10',
          sleepHours: 7,
          waterIntake: 2,
          mood: 3,
          energyLevel: 3,
        ));
    final broken = ReadingService(
      measurements: _BrokenMeasurementRepository(db),
      settings: DriftSettingsRepository(db),
      clock: _now,
    );

    await openApp(tester, extra: [readingServiceProvider.overrideWithValue(broken)]);
    expect(find.byKey(const ValueKey('timeline-error')), findsNothing);
    expect(find.byKey(const ValueKey('timeline-daily')), findsOneWidget);
    expect(find.byKey(const ValueKey('timeline-readings')), findsNothing);
  });
}
