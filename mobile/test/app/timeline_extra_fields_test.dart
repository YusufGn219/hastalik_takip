// Zaman çizelgesinde ek günlük alanlarının değerleri: gösterim, kapalı alan,
// gün gezinmesi, hata yolu. Gerçek (bellek içi) veritabanı.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/enums.dart';
import 'package:mobile/data/repositories/daily_field_repository.dart';
import 'package:mobile/data/repositories/daily_log_repository.dart';
import 'package:mobile/data/repositories/measurement_repository.dart';
import 'package:mobile/domain/services/daily_field_service.dart';
import 'package:mobile/features/timeline/screens/day_timeline_screen.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../data/test_support.dart';

/// Saat: 2026-11-07 Cumartesi 12:00.
DateTime _now() => DateTime(2026, 11, 7, 12, 0);
const _today = '2026-11-07';
const _yesterday = '2026-11-06';

class _BrokenFieldRepository extends DriftDailyFieldRepository {
  _BrokenFieldRepository(super.db);

  @override
  Future<List<DailyField>> listAll() => throw StateError('okunamadı');
}

void main() {
  late AppDatabase db;
  late DailyFieldService service;

  setUp(() {
    db = createTestDb();
    service = DailyFieldService(
      fields: DriftDailyFieldRepository(db),
      measurements: DriftMeasurementRepository(db),
      clock: _now,
      transactor: db.transaction,
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

  Future<DailyField> field(
    WidgetTester tester,
    String name, {
    String kind = DailyFieldKinds.number,
    String unit = '',
    double? max,
  }) =>
      tester
          .runAsync(() => service.create(name: name, kind: kind, unit: unit, max: max))
          .then((v) => v!);

  Future<void> value(WidgetTester tester, DailyField f, String day, double v) =>
      tester.runAsync(() => service.setValue(f.id, day, v));

  group('ek alan değerleri', () {
    testWidgets('sayı birimiyle, ölçek "n/5", evet/hayır "Evet"/"Hayır" olarak görünür', (tester) async {
      final tea = await field(tester, 'Çay', unit: 'bardak', max: 20);
      final stress = await field(tester, 'Stres', kind: DailyFieldKinds.scale);
      final sport = await field(tester, 'Spor yaptım', kind: DailyFieldKinds.yesNo);
      final walk = await field(tester, 'Yürüyüş', max: 50);
      await value(tester, tea, _today, 2.5);
      await value(tester, stress, _today, 4);
      await value(tester, sport, _today, 0);
      await value(tester, walk, _today, 3);

      await openApp(tester);

      expect(find.byKey(const ValueKey('timeline-extras')), findsOneWidget);
      expect(find.text('Ek alanlar'), findsOneWidget);
      expect(find.text('Çay: 2,5 bardak'), findsOneWidget);
      expect(find.text('Stres: 4/5'), findsOneWidget);
      expect(find.text('Spor yaptım: Hayır'), findsOneWidget);
      expect(find.text('Yürüyüş: 3'), findsOneWidget); // birimsiz
    });

    testWidgets('değeri olmayan alan görünmez; hiç değer yoksa kart ve başlık da yoktur', (tester) async {
      final tea = await field(tester, 'Çay', max: 20);
      await field(tester, 'Kahve', max: 20);
      await value(tester, tea, _today, 1);

      await openApp(tester);
      expect(find.text('Çay: 1'), findsOneWidget);
      expect(find.textContaining('Kahve'), findsNothing);
    });

    testWidgets('hiç değer yokken "Ek alanlar" bölümü görünmez', (tester) async {
      await field(tester, 'Çay', max: 20);
      await openApp(tester);
      expect(find.byKey(const ValueKey('timeline-extras')), findsNothing);
      expect(find.text('Ek alanlar'), findsNothing);
    });

    testWidgets('kapatılmış alanın girilmiş değeri yine görünür', (tester) async {
      final tea = await field(tester, 'Çay', max: 20);
      await value(tester, tea, _today, 3);
      await tester.runAsync(() => service.setActive(tea.id, false));

      await openApp(tester);
      expect(find.text('Çay: 3'), findsOneWidget);
    });

    testWidgets('günlük kayıt yokken de ek alan değeri gösterilir', (tester) async {
      final tea = await field(tester, 'Çay', max: 20);
      await value(tester, tea, _today, 3);

      await openApp(tester);
      expect(find.byKey(const ValueKey('timeline-daily-empty')), findsOneWidget);
      expect(find.text('Çay: 3'), findsOneWidget);
    });

    testWidgets('günlük kayıt varken çekirdek kart aynen durur, ek alanlar ayrı kartta', (tester) async {
      final tea = await field(tester, 'Çay', max: 20);
      await value(tester, tea, _today, 3);
      await tester.runAsync(() => DriftDailyLogRepository(db).upsert(
            logDate: _today,
            sleepHours: 7.5,
            waterIntake: 2,
            mood: 4,
            energyLevel: 3,
          ));

      await openApp(tester);
      expect(find.byKey(const ValueKey('timeline-daily')), findsOneWidget);
      expect(find.byKey(const ValueKey('timeline-extras')), findsOneWidget);
      expect(find.text('Çay: 3'), findsOneWidget);
    });
  });

  group('gün gezinmesi ve hata', () {
    testWidgets('önceki güne geçince o günün değerleri görünür, bugünküler görünmez', (tester) async {
      final tea = await field(tester, 'Çay', max: 20);
      final coffee = await field(tester, 'Kahve', max: 20);
      await value(tester, tea, _today, 3);
      await value(tester, coffee, _yesterday, 1);

      await openApp(tester);
      expect(find.text('Çay: 3'), findsOneWidget);
      expect(find.textContaining('Kahve'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('timeline-prev')));
      await tester.pumpAndSettle();
      expect(find.text('Kahve: 1'), findsOneWidget);
      expect(find.textContaining('Çay'), findsNothing);
    });

    testWidgets('ek alanlar okunamazsa çizelge yine açılır, günlük kart görünür', (tester) async {
      await tester.runAsync(() => DriftDailyLogRepository(db).upsert(
            logDate: _today,
            sleepHours: 7,
            waterIntake: 2,
            mood: 3,
            energyLevel: 3,
          ));
      final broken = DailyFieldService(
        fields: _BrokenFieldRepository(db),
        measurements: DriftMeasurementRepository(db),
        clock: _now,
      );

      await openApp(tester, extra: [dailyFieldServiceProvider.overrideWithValue(broken)]);
      expect(find.byKey(const ValueKey('timeline-error')), findsNothing);
      expect(find.byKey(const ValueKey('timeline-daily')), findsOneWidget);
      expect(find.byKey(const ValueKey('timeline-extras')), findsNothing);
    });
  });
}
