import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/enums.dart';
import 'package:mobile/data/database/seed_loader.dart';
import 'package:mobile/data/repositories/daily_log_repository.dart';
import 'package:mobile/data/repositories/dose_skip_repository.dart';
import 'package:mobile/data/repositories/medication_log_repository.dart';
import 'package:mobile/data/repositories/symptom_entry_repository.dart';
import 'package:mobile/features/timeline/screens/day_timeline_screen.dart';
import 'package:mobile/features/timeline/timeline_day.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../data/test_support.dart';

/// Saat: 2026-11-07 Cumartesi 12:00.
DateTime _now() => DateTime(2026, 11, 7, 12, 0);

/// Okuyamayan yükleyici.
class _BrokenLoader implements TimelineDayLoader {
  @override
  Future<TimelineDay> load(String day, {bool withActiveEpisodes = false}) =>
      throw StateError('okunamadı');
}

void main() {
  late AppDatabase db;
  late DriftSymptomEntryRepository entries;
  late DriftMedicationLogRepository logs;
  late DriftDoseSkipRepository skips;
  late DriftDailyLogRepository dailyLogs;

  final headache = SeedLoader.symptomId('headache');
  final parol = SeedLoader.medicationId('parol');
  final aspirin = SeedLoader.medicationId('aspirin');

  setUp(() async {
    db = createTestDb();
    await seedLoaderFor(db).seedIfNeeded();
    entries = DriftSymptomEntryRepository(db);
    logs = DriftMedicationLogRepository(db);
    skips = DriftDoseSkipRepository(db);
    dailyLogs = DriftDailyLogRepository(db);
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
        home: const DayTimelineScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> seedDay(WidgetTester tester) => tester.runAsync(() async {
        await dailyLogs.upsert(
          logDate: '2026-11-07',
          sleepHours: 7.5,
          waterIntake: 2,
          mood: 4,
          energyLevel: 3,
          notes: 'Hafif yorgunum',
        );
        await entries.create(
          symptomId: headache,
          severity: 6,
          timestamp: DateTime(2026, 11, 7, 9, 30),
          notes: 'Şakaklarda',
        );
        await logs.create(
          medicationId: parol,
          takenAt: DateTime(2026, 11, 7, 8, 5),
          scheduledTime: '08:00',
          scheduledDay: '2026-11-07',
        );
        await skips.create(
          medicationId: aspirin,
          scheduledDay: '2026-11-07',
          scheduledTime: '10:00',
          skippedAt: DateTime(2026, 11, 7, 10, 45),
        );
      });

  testWidgets('boş gün: günlük kayıt yok, kayıt yok, ekleme düğmesi bugün var',
      (tester) async {
    await openApp(tester);

    expect(find.text('Bu gün için günlük kayıt yok.'), findsOneWidget);
    expect(find.byKey(const ValueKey('timeline-events-empty')), findsOneWidget);
    expect(find.byKey(const ValueKey('timeline-add-daily')), findsOneWidget);
    expect(find.textContaining('Bugün ·'), findsOneWidget);
  });

  testWidgets('dolu gün: günlük kayıt ve üç satır zaman sırasıyla gelir',
      (tester) async {
    await seedDay(tester);
    await openApp(tester);

    expect(find.text('Uyku: 7,5 saat'), findsOneWidget);
    expect(find.text('Su: 2 litre'), findsOneWidget);
    expect(find.text('Ruh hali: 4/5'), findsOneWidget);
    expect(find.text('Enerji: 3/5'), findsOneWidget);
    expect(find.text('Hafif yorgunum'), findsOneWidget);

    expect(find.text('Parol alındı'), findsOneWidget);
    expect(find.text('Baş ağrısı · Şiddet 6/10'), findsOneWidget);
    expect(find.text('Şakaklarda'), findsOneWidget);
    expect(find.text('Aspirin atlandı'), findsOneWidget);

    // Zaman sırası: 08:05 alım, 09:30 semptom, 10:45 atlama.
    double y(String t) => tester.getTopLeft(find.text(t)).dy;
    expect(y('Parol alındı'), lessThan(y('Baş ağrısı · Şiddet 6/10')));
    expect(y('Baş ağrısı · Şiddet 6/10'), lessThan(y('Aspirin atlandı')));
    expect(find.text('08:05'), findsOneWidget);
    expect(find.text('09:30'), findsOneWidget);
    expect(find.text('10:45'), findsOneWidget);
  });

  testWidgets('atlanan doz "alındı" diye gösterilmez; alınan doz saatini taşır',
      (tester) async {
    await seedDay(tester);
    await openApp(tester);

    expect(find.text('Aspirin alındı'), findsNothing);
    expect(find.text('10:00 dozu'), findsOneWidget); // atlanan dozun planlı saati
    expect(find.text('08:00 dozu'), findsOneWidget); // alınan dozun planlı saati
  });

  testWidgets('plansız alım dozu ve "doz saati" etiketi olmadan görünür',
      (tester) async {
    await tester.runAsync(() => logs.create(
          medicationId: parol,
          takenAt: DateTime(2026, 11, 7, 11, 0),
          doseAmount: 1.5,
          doseUnit: DoseUnit.drop,
        ));
    await openApp(tester);

    expect(find.text('Parol (1,5 damla) alındı'), findsOneWidget);
    expect(find.textContaining('dozu'), findsNothing);
  });

  testWidgets('gün gezinme: önceki güne geç, bugüne dön; ileri bugünde kapalı',
      (tester) async {
    await tester.runAsync(() => logs.create(
          medicationId: parol,
          takenAt: DateTime(2026, 11, 6, 21, 0),
        ));
    await openApp(tester);

    IconButton next() =>
        tester.widget<IconButton>(find.byKey(const ValueKey('timeline-next')));
    expect(next().onPressed, isNull); // gelecek gün yok

    await tester.tap(find.byKey(const ValueKey('timeline-prev')));
    await tester.pumpAndSettle();
    expect(find.text('Parol alındı'), findsOneWidget);
    expect(find.text('21:00'), findsOneWidget);
    expect(find.textContaining('Bugün ·'), findsNothing);
    expect(next().onPressed, isNotNull);
    // Geçmiş güne günlük kayıt ekleme düğmesi konmaz.
    expect(find.byKey(const ValueKey('timeline-add-daily')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('timeline-today')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bugün ·'), findsOneWidget);
    expect(find.text('Parol alındı'), findsNothing);
    expect(next().onPressed, isNull);
  });

  testWidgets('ay sınırında önceki gün doğru hesaplanır', (tester) async {
    expect(shiftDay('2026-12-01', -1), '2026-11-30');
    expect(shiftDay('2026-03-01', -1), '2026-02-28');
    expect(shiftDay('2026-12-31', 1), '2027-01-01');
  });

  testWidgets('süren dönem yalnız bugün üstte görünür', (tester) async {
    await tester.runAsync(() async {
      final e = await entries.create(
        symptomId: headache,
        severity: 7,
        timestamp: DateTime(2026, 11, 6, 22, 0),
      );
      final episodes = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(_now),
      ]);
      await episodes.read(episodeServiceProvider).start(e);
      episodes.dispose();
    });
    await openApp(tester);

    expect(find.text('Devam eden dönemler'), findsOneWidget);
    expect(find.text('Baş ağrısı'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('timeline-prev')));
    await tester.pumpAndSettle();
    expect(find.text('Devam eden dönemler'), findsNothing);
  });

  testWidgets('okunamazsa anlaşılır hata gösterilir', (tester) async {
    await openApp(tester, extra: [
      timelineDayLoaderProvider.overrideWithValue(_BrokenLoader()),
    ]);

    expect(find.byKey(const ValueKey('timeline-error')), findsOneWidget);
    expect(find.textContaining('Verileriniz silinmedi'), findsOneWidget);
  });
}
