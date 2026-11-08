import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/seed_loader.dart';
import 'package:mobile/data/repositories/support.dart';
import 'package:mobile/domain/services/analytics_service.dart';
import 'package:mobile/domain/services/dose_adherence_service.dart';
import 'package:mobile/domain/weekdays.dart';
import 'package:mobile/features/analytics/analytics_overview.dart';
import 'package:mobile/features/analytics/screens/analytics_dashboard_screen.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../data/test_support.dart';

/// Saat: 2026-11-07 Cumartesi 12:00.
DateTime _now() => DateTime(2026, 11, 7, 12, 0);

/// Hazır sonuç veren, istenen dönemleri kaydeden yükleyici.
class _FakeLoader implements AnalyticsOverviewLoader {
  _FakeLoader(this.build);

  final AnalyticsOverview Function(int days) build;
  final List<int> requested = [];

  @override
  Future<AnalyticsOverview> load(int days) async {
    requested.add(days);
    return build(days);
  }
}

class _BrokenLoader implements AnalyticsOverviewLoader {
  @override
  Future<AnalyticsOverview> load(int days) => throw StateError('okunamadı');
}

AnalyticsOverview _empty(int days) => AnalyticsOverview(
      days: days,
      symptoms: SymptomAnalytics(days, const [], const []),
      daily: DailyTrends(days, const [], const {
        'sleep_hours': null,
        'water_intake': null,
        'mood': null,
        'energy_level': null,
      }),
      effect: MedicationEffect(days, const []),
      adherence: DoseAdherence(days, const []),
    );

AnalyticsOverview _filled(int days) => AnalyticsOverview(
      days: days,
      symptoms: SymptomAnalytics(
        days,
        const [
          SymptomFrequency('Baş ağrısı', 3, 6.0),
          SymptomFrequency('Ateş', 1, 4.5),
        ],
        const [SeverityPoint('2026-11-05', 5.0), SeverityPoint('2026-11-06', 7.0)],
      ),
      daily: DailyTrends(
        days,
        const [
          DailyTrendPoint('2026-11-05', 7.5, 2.0, 4, 3),
          DailyTrendPoint('2026-11-06', 6.0, 2.5, 5, 4),
        ],
        const {
          'sleep_hours': 6.8,
          'water_intake': 2.3,
          'mood': 4.5,
          'energy_level': 3.5,
        },
      ),
      effect: MedicationEffect(days, const [
        MedicationEffectItem(
          medicationName: 'Parol',
          usageCount: 5,
          avgSeverityBefore: 7.0,
          avgSeverityAfter: 4.0,
          avgReliefMinutes: 45,
        ),
      ]),
      adherence: DoseAdherence(days, const []),
    );

void main() {
  late AppDatabase db;

  setUp(() async {
    db = createTestDb();
    await seedLoaderFor(db).seedIfNeeded();
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
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AnalyticsDashboardScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester tester, String name) async {
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  Override fake(_FakeLoader l) =>
      analyticsOverviewLoaderProvider.overrideWithValue(l);

  testWidgets('hiç veri yokken dört sekmede de anlaşılır boş durum çıkar',
      (tester) async {
    await openApp(tester);

    expect(find.byKey(const ValueKey('analytics-symptoms-empty')), findsOneWidget);
    expect(find.byKey(const ValueKey('analytics-trend-empty')), findsOneWidget);

    await openTab(tester, 'Günlük');
    expect(find.byKey(const ValueKey('analytics-daily-empty')), findsOneWidget);
    // Veri yokken uyku ve su eğilim grafikleri de çizilmez.
    expect(find.byKey(const ValueKey('daily-sleep-chart')), findsNothing);
    expect(find.byKey(const ValueKey('daily-water-chart')), findsNothing);
    expect(find.text('-'), findsNWidgets(4)); // dört ortalama da boş

    await openTab(tester, 'İlaç etkisi');
    expect(find.byKey(const ValueKey('analytics-effect-empty')), findsOneWidget);

    await openTab(tester, 'Uyum');
    expect(find.byKey(const ValueKey('analytics-adherence-empty')), findsOneWidget);
  });

  testWidgets('semptom sekmesi: sıklık çubukları ve şiddet grafiği',
      (tester) async {
    await openApp(tester, extra: [fake(_FakeLoader(_filled))]);

    expect(find.text('Baş ağrısı'), findsOneWidget);
    expect(find.text('3 kez'), findsOneWidget);
    expect(find.text('Ort: 6'), findsOneWidget);
    expect(find.text('Ort: 4,5'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('günlük sekmesi: ortalamalar ve iki çizgili grafik',
      (tester) async {
    await openApp(tester, extra: [fake(_FakeLoader(_filled))]);
    await openTab(tester, 'Günlük');

    expect(find.text('6,8 saat'), findsOneWidget);
    expect(find.text('2,3 litre'), findsOneWidget);
    expect(find.text('4,5 / 5'), findsOneWidget);
    expect(find.text('3,5 / 5'), findsOneWidget);
    expect(find.textContaining('son 30 gün'), findsOneWidget);
    final chart = tester.widget<LineChart>(
        find.byKey(const ValueKey('daily-mood-energy-chart')));
    expect(chart.data.lineBarsData, hasLength(2)); // ruh hali ve enerji
    // Az nokta (2): ham değerler, noktalar görünür, hareketli ortalama notu yok.
    expect(chart.data.lineBarsData.first.spots.map((s) => s.y), [4.0, 5.0]);
    expect(chart.data.lineBarsData.first.dotData.show, isTrue);
    expect(find.byKey(const ValueKey('daily-smoothed-note')), findsNothing);
    // Uyku ve su için de birer eğilim grafiği vardır.
    final sleep = tester.widget<LineChart>(
        find.byKey(const ValueKey('daily-sleep-chart')));
    final water = tester.widget<LineChart>(
        find.byKey(const ValueKey('daily-water-chart')));
    expect(sleep.data.lineBarsData.single.spots.map((s) => s.y), [7.5, 6.0]);
    expect(water.data.lineBarsData.single.spots.map((s) => s.y), [2.0, 2.5]);
    expect(find.text('Uyku eğilimi (saat)'), findsOneWidget);
    expect(find.text('Su eğilimi (litre)'), findsOneWidget);
  });

  AnalyticsOverview withDaily(int days, List<DailyTrendPoint> points) =>
      AnalyticsOverview(
        days: days,
        symptoms: _empty(days).symptoms,
        daily: DailyTrends(days, points, const {
          'sleep_hours': 7.0,
          'water_intake': 2.0,
          'mood': 3.0,
          'energy_level': 3.0,
        }),
        effect: _empty(days).effect,
        adherence: _empty(days).adherence,
      );

  testWidgets(
      'günlük sekmesi: 30 günde ruh hali, enerji, uyku ve su 7 günlük hareketli ortalama çizilir',
      (tester) async {
    // 2026-10-09 .. 2026-11-07, art arda 30 gün.
    final points = [
      for (var i = 0; i < 30; i++)
        DailyTrendPoint(
          dayKey(DateTime(2026, 10, 9 + i)),
          6.0 + (i % 3), // uyku 6, 7, 8, 6, 7, 8 ...
          2.0, // su sabit
          i.isEven ? 2 : 4, // ruh hali 2, 4, 2, 4 ...
          3, // enerji sabit
        ),
    ];
    await openApp(tester, extra: [fake(_FakeLoader((d) => withDaily(d, points)))]);
    await openTab(tester, 'Günlük');

    final moodEnergy = tester.widget<LineChart>(
        find.byKey(const ValueKey('daily-mood-energy-chart')));
    final mood = moodEnergy.data.lineBarsData[0];
    final energy = moodEnergy.data.lineBarsData[1];
    expect(mood.spots, hasLength(30));
    expect(mood.dotData.show, isFalse);
    // İlk günde pencerede yalnız kendisi var; ortalama kendi değeri.
    expect(mood.spots.first.y, 2.0);
    // Son 7 gün ruh hali: 4, 2, 4, 2, 4, 2, 4 -> 22/7.
    expect(mood.spots.last.y, closeTo(22 / 7, 1e-9));
    expect(energy.spots.last.y, closeTo(3.0, 1e-9));

    final sleep = tester
        .widget<LineChart>(find.byKey(const ValueKey('daily-sleep-chart')))
        .data
        .lineBarsData
        .single;
    // Son 7 günde uyku: 8, 6, 7, 8, 6, 7, 8 -> 50/7.
    expect(sleep.spots.last.y, closeTo(50 / 7, 1e-9));
    expect(sleep.dotData.show, isFalse);

    final water = tester
        .widget<LineChart>(find.byKey(const ValueKey('daily-water-chart')))
        .data
        .lineBarsData
        .single;
    expect(water.spots.last.y, closeTo(2.0, 1e-9));

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('daily-smoothed-note')),
      find.byType(ListView).first,
      const Offset(0, -200),
    );
    expect(find.textContaining('7 günlük hareketli ortalama'), findsOneWidget);
  });

  testWidgets('günlük sekmesi: 14 nokta sınırında hâlâ ham değer çizilir',
      (tester) async {
    final points = [
      for (var i = 0; i < 14; i++)
        DailyTrendPoint(dayKey(DateTime(2026, 10, 25 + i)), 7.0, 2.0, i.isEven ? 1 : 5, 3),
    ];
    await openApp(tester, extra: [fake(_FakeLoader((d) => withDaily(d, points)))]);
    await openTab(tester, 'Günlük');

    final mood = tester
        .widget<LineChart>(find.byKey(const ValueKey('daily-mood-energy-chart')))
        .data
        .lineBarsData
        .first;
    expect(mood.spots.map((s) => s.y).take(4), [1.0, 5.0, 1.0, 5.0]);
    expect(mood.dotData.show, isTrue);
    expect(find.byKey(const ValueKey('daily-smoothed-note')), findsNothing);
  });

  testWidgets('günlük sekmesi: büyük uyku ve su değerinde grafik üst sınırı yukarı açılır',
      (tester) async {
    final points = [
      DailyTrendPoint('2026-11-05', 11.2, 5.3, 3, 3),
      DailyTrendPoint('2026-11-06', 7.0, 2.0, 3, 3),
    ];
    await openApp(tester, extra: [fake(_FakeLoader((d) => withDaily(d, points)))]);
    await openTab(tester, 'Günlük');

    final sleep = tester.widget<LineChart>(find.byKey(const ValueKey('daily-sleep-chart')));
    final water = tester.widget<LineChart>(find.byKey(const ValueKey('daily-water-chart')));
    expect(sleep.data.maxY, 12.0); // 11,2 yukarı yuvarlanır (en az 10)
    expect(water.data.maxY, 6.0); // 5,3 yukarı yuvarlanır (en az 4)
  });

  testWidgets('ilaç etkisi: önce/sonra, fark, ortalama etki ve uyarı',
      (tester) async {
    await openApp(tester, extra: [fake(_FakeLoader(_filled))]);
    await openTab(tester, 'İlaç etkisi');

    expect(find.text('Parol'), findsOneWidget);
    expect(find.text('5 kez kullanıldı'), findsOneWidget);
    expect(find.text('-3'), findsOneWidget);
    expect(find.text('Ortalama etki: 45 dakika'), findsOneWidget);
    expect(find.textContaining('tıbbi tavsiye değildir'), findsOneWidget);
  });

  testWidgets('ilaç sonrası şiddet düşmediyse "azalma" rozeti gösterilmez',
      (tester) async {
    AnalyticsOverview worse(int days) => AnalyticsOverview(
          days: days,
          symptoms: _empty(days).symptoms,
          daily: _empty(days).daily,
          effect: MedicationEffect(days, const [
            MedicationEffectItem(
              medicationName: 'Nurofen',
              usageCount: 2,
              avgSeverityBefore: 4.0,
              avgSeverityAfter: 6.0,
              avgReliefMinutes: null,
            ),
          ]),
          adherence: _empty(days).adherence,
        );
    await openApp(tester, extra: [fake(_FakeLoader(worse))]);
    await openTab(tester, 'İlaç etkisi');

    expect(find.text('Nurofen'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^-')), findsNothing); // fark rozeti yok
    expect(find.textContaining('Ortalama etki'), findsNothing); // süre bilinmiyor
  });

  testWidgets('plansız alım satırı yalnız ekstra alımı olan ilaçta görünür',
      (tester) async {
    AnalyticsOverview withExtras(int days) => AnalyticsOverview(
          days: days,
          symptoms: _empty(days).symptoms,
          daily: _empty(days).daily,
          effect: _empty(days).effect,
          adherence: DoseAdherence(days, const [
            DoseAdherenceItem(
              medicationId: 'a',
              medicationName: 'Aspirin',
              taken: 2,
              skipped: 0,
              unrecorded: 0,
              extraIntakes: 2,
            ),
            DoseAdherenceItem(
              medicationId: 'b',
              medicationName: 'Parol',
              taken: 1,
              skipped: 0,
              unrecorded: 0,
              extraIntakes: 0,
            ),
          ]),
        );
    await openApp(tester, extra: [fake(_FakeLoader(withExtras))]);
    await openTab(tester, 'Uyum');

    expect(find.text('Plansız alım: 2'), findsOneWidget);
    expect(find.textContaining('Plansız alım'), findsOneWidget); // Parol'da yok
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('adherence-rate-a'))).data,
      '%100',
    );
  });

  testWidgets('dönem seçimi yeniden okur: varsayılan 30, sonra 7 ve 90',
      (tester) async {
    final loader = _FakeLoader(_empty);
    await openApp(tester, extra: [fake(loader)]);
    expect(loader.requested, [30]);

    await tester.tap(find.byKey(const ValueKey('analytics-days-7')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('analytics-days-90')));
    await tester.pumpAndSettle();
    // Seçili dönemi yeniden seçmek gereksiz okuma yapmaz.
    await tester.tap(find.byKey(const ValueKey('analytics-days-90')));
    await tester.pumpAndSettle();

    expect(loader.requested, [30, 7, 90]);
  });

  testWidgets('uyum sekmesi doz bazlı: atlananlar paydada, veri yoksa "Henüz veri yok"',
      (tester) async {
    final aspirin = SeedLoader.medicationId('aspirin');
    final parol = SeedLoader.medicationId('parol');
    await tester.runAsync(() async {
      final c = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(_now),
      ]);
      final meds = c.read(medicationServiceProvider);
      await meds.setRoutine(
          medicationId: aspirin, times: ['08:00', '20:00'], days: weekdayKeys);
      await meds.setRoutine(
          medicationId: parol, times: ['09:00'], days: weekdayKeys);
      final doses = c.read(doseServiceProvider);
      // Dört gün: sabah atlandı (üç gün), akşam alındı; bugün sabah alındı.
      for (final d in ['2026-11-04', '2026-11-05', '2026-11-06']) {
        await doses.markSkipped(medicationId: aspirin, time: '08:00', day: d);
        await doses.markTaken(medicationId: aspirin, time: '20:00', day: d);
      }
      await doses.markTaken(
          medicationId: aspirin, time: '08:00', day: '2026-11-07');
      c.dispose();
    });
    await openApp(tester);
    await openTab(tester, 'Uyum');

    // Eski gün bazlı hesap bunu %100 gösterirdi.
    expect(find.byKey(ValueKey('adherence-rate-$aspirin')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(ValueKey('adherence-rate-$aspirin'))).data,
      '%57,1',
    );
    expect(
      tester.widget<Text>(find.byKey(ValueKey('adherence-line-$aspirin'))).data,
      '4 alındı · 3 atlandı · 0 kaydedilmedi',
    );
    // Hiç kaydı olmayan rutin yüzde yerine "Henüz veri yok" gösterir.
    expect(
      tester.widget<Text>(find.byKey(ValueKey('adherence-rate-$parol'))).data,
      'Henüz veri yok',
    );
    expect(find.byKey(ValueKey('adherence-line-$parol')), findsNothing);
    expect(find.textContaining('ilk kayıtlı dozundan'), findsOneWidget);
  });

  testWidgets('okunamazsa anlaşılır hata gösterilir', (tester) async {
    await openApp(tester, extra: [
      analyticsOverviewLoaderProvider.overrideWithValue(_BrokenLoader()),
    ]);

    expect(find.byKey(const ValueKey('analytics-error')), findsOneWidget);
    expect(find.textContaining('Verileriniz silinmedi'), findsOneWidget);
  });
}
