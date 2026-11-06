import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/core/utils/turkish_text.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/seed_loader.dart';
import 'package:mobile/data/repositories/episode_repository.dart';
import 'package:mobile/data/database/enums.dart';
import 'package:mobile/data/repositories/medication_log_repository.dart';
import 'package:mobile/data/repositories/medication_repository.dart';
import 'package:mobile/data/repositories/symptom_entry_repository.dart';
import 'package:mobile/domain/services/episode_service.dart';
import 'package:mobile/domain/services/medication_service.dart';
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

/// Kapatma beklenmedik şekilde hata verir; ekranın genel hata yolunu denemek
/// için.
class _FailingCloseService extends EpisodeService {
  _FailingCloseService(AppDatabase db)
      : super(
          episodes: DriftEpisodeRepository(db),
          entries: DriftSymptomEntryRepository(db),
        );

  @override
  Future<void> close(
    Episode episode, {
    DateTime? endedAt,
    String resolutionNotes = '',
  }) async =>
      throw StateError('yazılamadı');
}

/// İlaç servisi bozuk: listeyi ya da kaydı hata verdirerek pencerenin hata
/// yollarını denemek için.
class _BrokenMedicationService extends MedicationService {
  _BrokenMedicationService(AppDatabase db,
      {this.failList = false, this.failLog = false})
      : super(
          medications: DriftMedicationRepository(db),
          logs: DriftMedicationLogRepository(db),
        );

  final bool failList;
  final bool failLog;

  @override
  Future<List<Medication>> available() =>
      failList ? throw StateError('okunamadı') : super.available();

  @override
  Future<MedicationLog> logIntake({
    required String medicationId,
    required DateTime takenAt,
    double? doseAmount,
    DoseUnit doseUnit = DoseUnit.tablet,
    String? episodeId,
    String? conditionId,
    String notes = '',
  }) =>
      failLog
          ? throw StateError('yazılamadı')
          : super.logIntake(
              medicationId: medicationId,
              takenAt: takenAt,
              doseAmount: doseAmount,
              doseUnit: doseUnit,
              episodeId: episodeId,
              conditionId: conditionId,
              notes: notes,
            );
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
        'saat, konumlar; iki düğme de aktif', (tester) async {
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
      // Kartın iki düğmesi de bağlı (Grup 2 ve 3).
      expect(
        tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Dönemi Kapat'),
        ).onPressed,
        isNotNull,
      );
      expect(
        tester.widget<ButtonStyleButton>(
          find.ancestor(
            of: find.text('İlaç Ekle'),
            matching: find.bySubtype<ButtonStyleButton>(),
          ),
        ).onPressed,
        isNotNull,
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

  group('EpisodeListScreen / dönemi kapatma', () {
    // Başlangıç yerel saatle verilir: bitiş "şimdi" (yerel 10:30) olduğundan
    // süre makinenin saat diliminden bağımsız çıkar.
    final start = DateTime(2026, 11, 6, 8, 0);

    Future<Episode> readEpisode(WidgetTester tester, String id) => tester
        .runAsync(() => DriftEpisodeRepository(db).getById(id))
        .then((e) => e!);

    Future<void> openClose(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Dönemi Kapat'));
      await tester.pumpAndSettle();
    }

    Future<void> tapCloseButton(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Dönemi Kapat'));
      await tester.pumpAndSettle();
    }

    testWidgets(
        'not yazılıp kapatılınca dönem yerel veritabanında kapanır, liste '
        'yenilenir, Geçmiş\'e geçer ve bilgi çıkar', (tester) async {
      await openApp(tester);
      final episode = await startEpisode(tester, headacheId, start);
      await addEntry(tester, episode, 6, start);
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      await openClose(tester);
      expect(find.text('Nasıl geçti? (isteğe bağlı)'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '  ilaçla geçti ');
      await tapCloseButton(tester);

      final saved = await readEpisode(tester, episode.id);
      expect(saved.status.name, 'resolved');
      expect(saved.resolutionNotes, 'ilaçla geçti'); // kırpılmış
      expect(saved.endedAt!.toUtc(), _now().toUtc()); // "şimdi"

      // Liste ekranına dönüldü, yenilendi.
      expect(find.text('Dönem kapatıldı.'), findsOneWidget);
      expect(find.text('Devam eden dönem yok'), findsOneWidget);
      await openHistoryTab(tester);
      expect(find.text('Maks. şiddet: 6/10'), findsOneWidget);
      expect(find.text('08:00 → 10:30 · 2 saat 30 dakika'), findsOneWidget);
      expect(find.text('📝 ilaçla geçti'), findsOneWidget);
    });

    testWidgets('not boş bırakılırsa boş not kaydedilir', (tester) async {
      await openApp(tester);
      final episode = await startEpisode(tester, headacheId, start);
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      await openClose(tester);
      await tester.enterText(find.byType(TextField), '   ');
      await tapCloseButton(tester);

      final saved = await readEpisode(tester, episode.id);
      expect(saved.status.name, 'resolved');
      expect(saved.resolutionNotes, '');
    });

    testWidgets('vazgeçilirse dönem açık kalır ve bilgi çıkmaz',
        (tester) async {
      await openApp(tester);
      final episode = await startEpisode(tester, headacheId, start);
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      await openClose(tester);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect((await readEpisode(tester, episode.id)).status.name, 'ongoing');
      expect(find.text('Dönem kapatıldı.'), findsNothing);
      expect(find.text('Baş ağrısı'), findsOneWidget);
    });

    testWidgets(
        'şimdi başlangıçtan önceyse (cihaz saati geri) anlaşılır mesaj çıkar, '
        'dönem açık kalır, yazılan not korunur', (tester) async {
      await openApp(tester);
      final episode = await startEpisode(
        tester,
        headacheId,
        DateTime(2026, 11, 6, 12, 0), // "şimdi" 10:30'dan sonra
      );
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      await openClose(tester);
      await tester.enterText(find.byType(TextField), 'not');
      await tapCloseButton(tester);

      expect(
        find.text('Bitiş zamanı başlangıçtan önce olamaz. Cihazın saatini '
            'kontrol edin.'),
        findsOneWidget,
      );
      expect((await readEpisode(tester, episode.id)).status.name, 'ongoing');
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'not');
      // Tekrar denenebilir.
      expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Dönemi Kapat'))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets(
        'kart eskiyse (dönem başka yerden kapanmış) tekrar kapatılmaz, bitiş '
        've not üzerine yazılmaz', (tester) async {
      await openApp(tester);
      final episode = await startEpisode(tester, headacheId, start);
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      // Liste hâlâ "devam ediyor" gösterirken kayıt arkadan kapanır.
      await resolve(tester, episode, DateTime(2026, 11, 6, 9, 0), 'ilk not');

      await openClose(tester);
      await tester.enterText(find.byType(TextField), 'ikinci not');
      await tapCloseButton(tester);

      expect(find.text('Bu dönem zaten kapatılmış. Listeyi yenileyin.'),
          findsOneWidget);
      final saved = await readEpisode(tester, episode.id);
      expect(saved.resolutionNotes, 'ilk not');
      expect(saved.endedAt!.toUtc(), DateTime(2026, 11, 6, 9, 0).toUtc());
    });

    testWidgets('beklenmedik hata: genel mesaj, not korunur, tekrar denenebilir',
        (tester) async {
      await openApp(tester, [
        episodeServiceProvider.overrideWithValue(_FailingCloseService(db)),
      ]);
      await startEpisode(tester, headacheId, start);
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      await openClose(tester);
      await tester.enterText(find.byType(TextField), 'yazdığım not');
      await tapCloseButton(tester);

      expect(find.textContaining('Dönem kapatılamadı'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'yazdığım not');
      expect(
        tester
            .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Dönemi Kapat'))
            .onPressed,
        isNotNull,
      );
    });
  });

  group('EpisodeListScreen / döneme ilaç ekleme', () {
    final start = DateTime(2026, 11, 6, 8, 0);
    final parolId = SeedLoader.medicationId('parol');

    Future<List<MedicationLog>> allLogs(WidgetTester tester) => tester
        .runAsync(() => DriftMedicationLogRepository(db)
            .listInRange(DateTime.utc(2000), DateTime.utc(2100)))
        .then((v) => v!);

    /// Dönemi kurar, listeyi yeniler, pencereyi açar.
    Future<Episode> openSheet(
      WidgetTester tester, [
      List<Override>? extra,
      Future<void> Function()? beforeOpen,
    ]) async {
      await openApp(tester, extra);
      final episode = await startEpisode(tester, headacheId, start);
      await beforeOpen?.call();
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'İlaç Ekle'));
      await tester.pumpAndSettle();
      return episode;
    }

    Future<void> pickMedication(WidgetTester tester, String name) async {
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(name).last);
      await tester.pumpAndSettle();
    }

    Future<void> tapSave(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Kaydet'));
      await tester.pumpAndSettle();
    }

    testWidgets('ilaçlar Türkçe sırada listelenir', (tester) async {
      // Kullanıcının eklediği "Çinko": veritabanının ikili sırası Ç'yi Z'den
      // sonraya atar, Türkçe sırada C'den hemen sonra, D'den önce gelir.
      await openSheet(tester, null, () async {
        await tester.runAsync(
            () => DriftMedicationRepository(db).create(name: 'Çinko'));
      });

      expect(find.text('Döneme İlaç Ekle'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      final names = tester
          .widgetList<DropdownMenuItem<String>>(
              find.byType(DropdownMenuItem<String>))
          .map((i) => (i.child as Text).data!)
          .toList();
      expect(names, hasLength(11)); // 10 katalog + Çinko
      final sorted = [...names]..sort(compareTr);
      expect(names, sorted);
      expect(names.indexOf('Çinko'), lessThan(names.indexOf('D Vitamini')));
      expect(names, contains('Parol'));
    });

    testWidgets(
        'ilaç, doz ve birim seçilip kaydedilince alım döneme bağlı yazılır, '
        'pencere kapanır, bilgi çıkar', (tester) async {
      final episode = await openSheet(tester);

      await pickMedication(tester, 'Parol');
      await tester.enterText(find.byType(TextField), '1,5'); // ondalık virgül
      await tester.tap(find.byType(DropdownButton<DoseUnit>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('damla').last);
      await tester.pumpAndSettle();
      await tapSave(tester);

      final logs = await allLogs(tester);
      expect(logs, hasLength(1));
      final log = logs.single;
      expect(log.medicationId, parolId);
      expect(log.episodeId, episode.id);
      expect(log.doseAmount, 1.5);
      expect(log.doseUnit, DoseUnit.drop);
      expect(log.takenAt.toUtc(), _now().toUtc()); // "şimdi"

      expect(find.text('Döneme İlaç Ekle'), findsNothing); // kapandı
      expect(find.text('İlaç döneme eklendi.'), findsOneWidget);
    });

    testWidgets('doz boş bırakılabilir; varsayılan birim tablet',
        (tester) async {
      await openSheet(tester);

      await pickMedication(tester, 'Parol');
      await tapSave(tester);

      final log = (await allLogs(tester)).single;
      expect(log.doseAmount, isNull);
      expect(log.doseUnit, DoseUnit.tablet);
    });

    testWidgets('ilaç seçilmeden kaydedilmez', (tester) async {
      await openSheet(tester);

      await tapSave(tester);

      expect(find.text('Lütfen bir ilaç seçin'), findsOneWidget);
      expect(find.text('Döneme İlaç Ekle'), findsOneWidget); // açık kaldı
      expect(await allLogs(tester), isEmpty);
    });

    for (final bad in ['abc', '0', '-2']) {
      testWidgets('geçersiz doz "$bad" reddedilir, kayıt yazılmaz',
          (tester) async {
        await openSheet(tester);

        await pickMedication(tester, 'Parol');
        await tester.enterText(find.byType(TextField), bad);
        await tapSave(tester);

        expect(find.text('Doz sıfırdan büyük bir sayı olmalı'), findsOneWidget);
        expect(await allLogs(tester), isEmpty);
      });
    }

    testWidgets('pencerenin dışına dokunup kapatılırsa hiçbir şey yazılmaz',
        (tester) async {
      await openSheet(tester);
      await pickMedication(tester, 'Parol');

      // Pencerenin dışına dokunmak kapatır.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Döneme İlaç Ekle'), findsNothing);
      expect(find.text('İlaç döneme eklendi.'), findsNothing);
      expect(await allLogs(tester), isEmpty);
    });

    testWidgets('ilaç listesi okunamazsa mesaj çıkar, Kaydet pasif',
        (tester) async {
      await openSheet(tester, [
        medicationServiceProvider
            .overrideWithValue(_BrokenMedicationService(db, failList: true)),
      ]);

      expect(find.text('İlaç listesi okunamadı.'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Kaydet'))
            .onPressed,
        isNull,
      );
    });

    testWidgets(
        'yazma hata verirse pencere açık kalır, mesaj çıkar, değerler korunur',
        (tester) async {
      await openSheet(tester, [
        medicationServiceProvider
            .overrideWithValue(_BrokenMedicationService(db, failLog: true)),
      ]);

      await pickMedication(tester, 'Parol');
      await tester.enterText(find.byType(TextField), '2');
      await tapSave(tester);

      expect(find.text('İlaç kaydedilemedi. Tekrar deneyin.'), findsOneWidget);
      expect(find.text('Döneme İlaç Ekle'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '2');
      expect(
        tester
            .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Kaydet'))
            .onPressed,
        isNotNull,
      );
      expect(await allLogs(tester), isEmpty);
    });

    testWidgets('ilaç seçilince "Lütfen bir ilaç seçin" uyarısı kalkar',
        (tester) async {
      await openSheet(tester);
      await tapSave(tester);
      expect(find.text('Lütfen bir ilaç seçin'), findsOneWidget);

      await pickMedication(tester, 'Parol');

      expect(find.text('Lütfen bir ilaç seçin'), findsNothing);
    });

    testWidgets('doz yazılmaya başlanınca "geçersiz doz" uyarısı kalkar',
        (tester) async {
      await openSheet(tester);
      await pickMedication(tester, 'Parol');
      await tester.enterText(find.byType(TextField), 'abc');
      await tapSave(tester);
      expect(find.text('Doz sıfırdan büyük bir sayı olmalı'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '2');
      await tester.pump();

      expect(find.text('Doz sıfırdan büyük bir sayı olmalı'), findsNothing);
    });

    testWidgets(
        'klavye açıkken geri tuşu önce yalnız klavyeyi kapatır, pencere '
        'bir sonraki geri tuşuyla kapanır', (tester) async {
      await openSheet(tester);
      await pickMedication(tester, 'Parol');

      // Klavye açık: alan odakta ve ekranın altı klavyeyle kısalmış.
      await tester.tap(find.byType(TextField));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      bool doseHasFocus() => tester
          .widget<EditableText>(find.byType(EditableText))
          .focusNode
          .hasFocus;
      expect(doseHasFocus(), isTrue);

      await tester.binding.handlePopRoute(); // 1. geri
      await tester.pumpAndSettle();
      expect(find.text('Döneme İlaç Ekle'), findsOneWidget); // pencere açık
      expect(doseHasFocus(), isFalse); // odak bırakıldı (klavye kapanır)

      // Klavye kapandı (sistem alanı geri verir); ikinci geri pencereyi kapatır.
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute(); // 2. geri
      await tester.pumpAndSettle();
      expect(find.text('Döneme İlaç Ekle'), findsNothing);
    });
  });

  group('EpisodeListScreen / kapatma ekranı görünümü', () {
    testWidgets('semptom kartı tam genişlikte', (tester) async {
      await openApp(tester);
      await startEpisode(tester, headacheId, DateTime(2026, 11, 6, 8, 0));
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Dönemi Kapat'));
      await tester.pumpAndSettle();

      // Ekran 800 geniş, kenar boşlukları 16'şar: kart 768 olmalı. Sayfada tek
      // Card var.
      expect(tester.getSize(find.byType(Card)).width, 800 - 32);
    });
  });

  group('EpisodeListScreen / kartta ilaç alımları', () {
    final start = utc(2026, 11, 6, 8, 0);
    final parolId = SeedLoader.medicationId('parol');
    final aspirinId = SeedLoader.medicationId('aspirin');

    Future<MedicationLog> logIntake(
      WidgetTester tester,
      Episode episode,
      String medicationId,
      DateTime at, {
      double? dose,
      DoseUnit unit = DoseUnit.tablet,
    }) =>
        tester
            .runAsync(() => DriftMedicationLogRepository(db).create(
                  medicationId: medicationId,
                  takenAt: at,
                  doseAmount: dose,
                  doseUnit: unit,
                  episodeId: episode.id,
                ))
            .then((v) => v!);

    Future<void> refresh(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();
    }

    testWidgets('ilaç alınmamış dönemde ilaç satırı yok', (tester) async {
      await openApp(tester);
      await startEpisode(tester, headacheId, start);
      await refresh(tester);

      expect(find.textContaining('İlaç: '), findsNothing);
    });

    testWidgets(
        'devam eden kartta alımlar eskiden yeniye: doz ve birim, doz yoksa '
        'yalnız ad ve saat', (tester) async {
      await openApp(tester);
      final episode = await startEpisode(tester, headacheId, start);
      // Önce yeni olan eklenir: sıra eklenme sırasına değil zamana bağlı.
      await logIntake(tester, episode, aspirinId, utc(2026, 11, 6, 9, 15));
      await logIntake(tester, episode, parolId, utc(2026, 11, 6, 8, 30),
          dose: 1.5, unit: DoseUnit.drop);
      await refresh(tester);

      expect(find.text('İlaç: Parol (1,5 damla) · 08:30'), findsOneWidget);
      expect(find.text('İlaç: Aspirin · 09:15'), findsOneWidget);
      final parol =
          tester.getTopLeft(find.text('İlaç: Parol (1,5 damla) · 08:30')).dy;
      final aspirin = tester.getTopLeft(find.text('İlaç: Aspirin · 09:15')).dy;
      expect(parol, lessThan(aspirin));
    });

    testWidgets('tam sayı doz ondalıksız yazılır ("2 tablet", "500 mg")',
        (tester) async {
      await openApp(tester);
      final episode = await startEpisode(tester, headacheId, start);
      await logIntake(tester, episode, parolId, utc(2026, 11, 6, 8, 30),
          dose: 2);
      await logIntake(tester, episode, aspirinId, utc(2026, 11, 6, 9, 0),
          dose: 500, unit: DoseUnit.mg);
      await refresh(tester);

      expect(find.text('İlaç: Parol (2 tablet) · 08:30'), findsOneWidget);
      expect(find.text('İlaç: Aspirin (500 mg) · 09:00'), findsOneWidget);
    });

    testWidgets('başka güne ait alım tarihli yazılır', (tester) async {
      await openApp(tester);
      final episode =
          await startEpisode(tester, headacheId, utc(2026, 11, 5, 21, 0));
      await logIntake(tester, episode, parolId, utc(2026, 11, 5, 22, 10),
          dose: 1);
      await refresh(tester);

      expect(find.text('İlaç: Parol (1 tablet) · 5 Kas 22:10'), findsOneWidget);
    });

    testWidgets('silinmiş alım gösterilmez', (tester) async {
      await openApp(tester);
      final episode = await startEpisode(tester, headacheId, start);
      final log = await logIntake(
          tester, episode, parolId, utc(2026, 11, 6, 8, 30));
      await tester.runAsync(
          () => DriftMedicationLogRepository(db).softDelete(log.id));
      await refresh(tester);

      expect(find.textContaining('İlaç: '), findsNothing);
    });

    testWidgets('biten dönemin geçmiş kartında da görünür', (tester) async {
      await openApp(tester);
      final episode = await startEpisode(tester, headacheId, start);
      await logIntake(tester, episode, parolId, utc(2026, 11, 6, 8, 30),
          dose: 1.5, unit: DoseUnit.ml);
      await resolve(tester, episode, utc(2026, 11, 6, 10, 0));
      await refresh(tester);
      await openHistoryTab(tester);

      expect(find.text('İlaç: Parol (1,5 ml) · 08:30'), findsOneWidget);
    });

    testWidgets(
        'İlaç Ekle penceresinden kaydedince alım kartta kendiliğinden belirir',
        (tester) async {
      await openApp(tester);
      await startEpisode(tester, headacheId, start);
      await refresh(tester);
      expect(find.textContaining('İlaç: '), findsNothing);

      await tester.tap(find.widgetWithText(ElevatedButton, 'İlaç Ekle'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Parol').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1,5');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Kaydet'));
      await tester.pumpAndSettle();

      // Elle yenilenmedi; "şimdi" yerel 10:30.
      expect(find.text('İlaç: Parol (1,5 tablet) · 10:30'), findsOneWidget);
      expect(find.text('İlaç döneme eklendi.'), findsOneWidget);
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
