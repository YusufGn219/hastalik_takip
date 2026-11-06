import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/seed_loader.dart';
import 'package:mobile/data/repositories/episode_repository.dart';
import 'package:mobile/data/repositories/symptom_entry_repository.dart';
import 'package:mobile/features/episode/episode_format.dart';
import 'package:mobile/features/episode/screens/episode_list_screen.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../data/test_support.dart';

/// Yerel 6 Kasım 2026, öğleden önce.
DateTime _now() => DateTime(2026, 11, 6, 10, 30);

/// Listeyi okuma hata verir; ekranın hata yolunu denemek için.
class _FailingEpisodeRepository implements EpisodeRepository {
  @override
  Future<List<Episode>> listAll() async => throw StateError('okunamadı');

  @override
  Future<Episode> start({
    required String symptomId,
    required DateTime startTime,
  }) =>
      throw UnimplementedError();

  @override
  Future<Episode?> getById(String id) => throw UnimplementedError();

  @override
  Future<Episode?> findOngoing(String symptomId) => throw UnimplementedError();

  @override
  Future<void> markResolved({
    required String id,
    required DateTime endedAt,
    String resolutionNotes = '',
  }) =>
      throw UnimplementedError();

  @override
  Future<EpisodeLocationEntry> addLocation({
    required String episodeId,
    required String location,
    required DateTime addedAt,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<EpisodeLocationEntry>> listLocations(String episodeId) =>
      throw UnimplementedError();

  @override
  Future<void> softDelete(String id) => throw UnimplementedError();
}

Widget _app(List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const EpisodeListScreen(),
      ),
    );

/// Genişlik bilerek geniş: flutter_test'in Ahem yazı tipi gerçek yazıdan çok
/// geniş çizilir, dar ekranda düzen taşması (bu testlerle ilgisiz) çıkar.
void _phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDb());
  tearDown(() => db.close());

  final headacheId = SeedLoader.symptomId('headache');
  final feverId = SeedLoader.symptomId('fever');

  // Testlerde hep UTC anlar kullanılır: UTC farkı 0 olur, makinenin saat
  // diliminden bağımsız sonuç çıkar.
  Future<Episode> startEpisode(
    WidgetTester tester,
    String symptomId,
    DateTime start,
  ) =>
      tester
          .runAsync(() => DriftEpisodeRepository(db)
              .start(symptomId: symptomId, startTime: start))
          .then((e) => e!);

  Future<void> addEntry(
    WidgetTester tester,
    Episode episode,
    int severity,
    DateTime at,
  ) async {
    await tester.runAsync(() => DriftSymptomEntryRepository(db).create(
          symptomId: episode.symptomId,
          severity: severity,
          timestamp: at,
          episodeId: episode.id,
        ));
  }

  Future<void> resolve(
    WidgetTester tester,
    Episode episode,
    DateTime end, [
    String notes = '',
  ]) async {
    await tester.runAsync(() => DriftEpisodeRepository(db).markResolved(
          id: episode.id,
          endedAt: end,
          resolutionNotes: notes,
        ));
  }

  Future<void> openApp(WidgetTester tester, [List<Override>? extra]) async {
    _phoneSize(tester);
    await tester.runAsync(() => seedLoaderFor(db).seedIfNeeded());
    await tester.pumpWidget(_app([
      databaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(_now),
      ...?extra,
    ]));
    await tester.pumpAndSettle();
  }

  Future<void> openHistoryTab(WidgetTester tester) async {
    await tester.tap(find.text('Geçmiş'));
    await tester.pumpAndSettle();
  }

  group('EpisodeListScreen / okuma', () {
    testWidgets('dönem yoksa iki sekmede de boş mesajı çıkar', (tester) async {
      await openApp(tester);

      expect(find.text('Devam eden dönem yok'), findsOneWidget);
      await openHistoryTab(tester);
      expect(find.text('Geçmiş dönem yok'), findsOneWidget);
    });

    testWidgets(
        'devam eden dönem kartı: semptom adı, son giriş şiddeti, bugünse yalnız '
        'saat, konumlar; düğmeler henüz pasif', (tester) async {
      await openApp(tester);
      final episode =
          await startEpisode(tester, headacheId, utc(2026, 11, 6, 8, 0));
      await addEntry(tester, episode, 3, utc(2026, 11, 6, 8, 0));
      await addEntry(tester, episode, 7, utc(2026, 11, 6, 9, 0));
      await tester.runAsync(() => DriftEpisodeRepository(db).addLocation(
            episodeId: episode.id,
            location: 'Şakak',
            addedAt: utc(2026, 11, 6, 8, 0),
          ));
      await tester.runAsync(() => DriftEpisodeRepository(db).addLocation(
            episodeId: episode.id,
            location: 'Alın',
            addedAt: utc(2026, 11, 6, 9, 0),
          ));

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(find.text('Baş ağrısı'), findsOneWidget);
      expect(find.text('Şiddet: 7/10'), findsOneWidget); // son giriş, en yüksek değil
      expect(find.text('Başlangıç: 08:00'), findsOneWidget);
      expect(find.text('Lokasyon: Şakak, Alın'), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Dönemi Kapat'),
        ).onPressed,
        isNull,
      );
    });

    testWidgets('girişsiz ve konumsuz dönem: şiddet "-", konum yok mesajı',
        (tester) async {
      await openApp(tester);
      await startEpisode(tester, headacheId, utc(2026, 11, 6, 8, 0));

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(find.text('Şiddet: -/10'), findsOneWidget);
      expect(find.text('Lokasyon belirtilmemiş'), findsOneWidget);
    });

    testWidgets('başka güne ait başlangıç tarihli yazılır', (tester) async {
      await openApp(tester);
      await startEpisode(tester, headacheId, utc(2026, 11, 5, 10, 58));

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(find.text('Başlangıç: 5 Kas 10:58'), findsOneWidget);
    });

    testWidgets('devam edenler en yeni başlayan üstte sıralanır',
        (tester) async {
      await openApp(tester);
      await startEpisode(tester, headacheId, utc(2026, 11, 6, 6, 0));
      await startEpisode(tester, feverId, utc(2026, 11, 6, 9, 0));

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      final fever = tester.getTopLeft(find.text('Ateş')).dy;
      final headache = tester.getTopLeft(find.text('Baş ağrısı')).dy;
      expect(fever, lessThan(headache));
    });

    testWidgets('silinmiş dönem listelenmez', (tester) async {
      await openApp(tester);
      final episode =
          await startEpisode(tester, headacheId, utc(2026, 11, 6, 8, 0));
      await tester
          .runAsync(() => DriftEpisodeRepository(db).softDelete(episode.id));

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(find.text('Devam eden dönem yok'), findsOneWidget);
      expect(find.text('Baş ağrısı'), findsNothing);
    });

    testWidgets(
        'biten dönem yalnız Geçmiş sekmesinde: en yüksek şiddet, aralık, süre, '
        'not', (tester) async {
      await openApp(tester);
      final episode =
          await startEpisode(tester, headacheId, utc(2026, 11, 6, 8, 0));
      await addEntry(tester, episode, 4, utc(2026, 11, 6, 8, 0));
      await addEntry(tester, episode, 9, utc(2026, 11, 6, 8, 30));
      await addEntry(tester, episode, 2, utc(2026, 11, 6, 10, 0));
      await resolve(tester, episode, utc(2026, 11, 6, 10, 5), 'ilaçla geçti');

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();
      expect(find.text('Devam eden dönem yok'), findsOneWidget);

      await openHistoryTab(tester);
      expect(find.text('Baş ağrısı'), findsOneWidget);
      expect(find.text('Maks. şiddet: 9/10'), findsOneWidget);
      expect(find.text('08:00 → 10:05 · 2 saat 5 dakika'), findsOneWidget);
      expect(find.text('📝 ilaçla geçti'), findsOneWidget);
    });

    testWidgets('bir saatten kısa süre yalnız dakika yazılır; not yoksa satır yok',
        (tester) async {
      await openApp(tester);
      final episode =
          await startEpisode(tester, headacheId, utc(2026, 11, 6, 8, 0));
      await resolve(tester, episode, utc(2026, 11, 6, 8, 45));

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();
      await openHistoryTab(tester);

      expect(find.text('Maks. şiddet: -/10'), findsOneWidget); // giriş yok
      expect(find.text('08:00 → 08:45 · 45 dakika'), findsOneWidget);
      expect(find.textContaining('📝'), findsNothing);
    });

    testWidgets('geçmiş en son biten üstte sıralanır', (tester) async {
      await openApp(tester);
      // Önce başlayan ama sonra biten (Ateş), sonra başlayıp erken biten
      // (Baş ağrısı): sıralama başlangıca değil bitişe göre olmalı.
      final first =
          await startEpisode(tester, feverId, utc(2026, 11, 6, 1, 0));
      final second =
          await startEpisode(tester, headacheId, utc(2026, 11, 6, 2, 0));
      await resolve(tester, second, utc(2026, 11, 6, 3, 0));
      await resolve(tester, first, utc(2026, 11, 6, 5, 0));

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();
      await openHistoryTab(tester);

      final fever = tester.getTopLeft(find.text('Ateş')).dy;
      final headache = tester.getTopLeft(find.text('Baş ağrısı')).dy;
      expect(fever, lessThan(headache));
    });

    testWidgets('yenile düğmesi sonradan eklenen dönemi getirir',
        (tester) async {
      await openApp(tester);
      expect(find.text('Baş ağrısı'), findsNothing);

      await startEpisode(tester, headacheId, utc(2026, 11, 6, 8, 0));
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(find.text('Baş ağrısı'), findsOneWidget);
    });

    testWidgets('okuma hata verirse mesaj çıkar, çökmez', (tester) async {
      await openApp(tester, [
        episodeRepositoryProvider.overrideWithValue(_FailingEpisodeRepository()),
      ]);

      expect(find.textContaining('Dönemler okunamadı'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('formatEpisodeMoment', () {
    // "Şimdi": 6 Kasım 2026 yerel.
    final now = DateTime(2026, 11, 6, 10, 30);

    test('aynı günse yalnız saat', () {
      expect(formatEpisodeMoment(utc(2026, 11, 6, 8, 5), 0, now, 'tr'), '08:05');
    });

    test('başka güne aitse gün, kısa ay adı ve saat', () {
      expect(
        formatEpisodeMoment(utc(2026, 11, 5, 10, 58), 0, now, 'tr'),
        '5 Kas 10:58',
      );
    });

    test('kaydın kendi UTC farkı uygulanır: 22:30Z + 3 saat = ertesi gün 01:30',
        () {
      // 5 Kasım 22:30 UTC, +03:00 farkla 6 Kasım 01:30 olur: bugündür.
      expect(
        formatEpisodeMoment(utc(2026, 11, 5, 22, 30), 180, now, 'tr'),
        '01:30',
      );
      // Aynı an farksız yazılsa dünün tarihli saati çıkardı.
      expect(
        formatEpisodeMoment(utc(2026, 11, 5, 22, 30), 0, now, 'tr'),
        '5 Kas 22:30',
      );
    });
  });
}
