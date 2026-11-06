import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/enums.dart';
import 'package:mobile/data/database/seed_loader.dart';
import 'package:mobile/data/repositories/episode_repository.dart';
import 'package:mobile/data/repositories/symptom_entry_repository.dart';
import 'package:mobile/domain/services/episode_service.dart';
import 'package:mobile/data/repositories/symptom_repository.dart';
import 'package:mobile/features/health/screens/symptom_screen.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../data/test_support.dart';

/// Yerel 6 Kasım 2026, öğleden önce.
DateTime _now() => DateTime(2026, 11, 6, 10, 30);

/// Listeyi okuma hata verir; ekranın hata yolunu denemek için.
class _FailingSymptomRepository implements SymptomRepository {
  @override
  Future<List<Symptom>> listActive() async => throw StateError('okunamadı');

  @override
  Future<Symptom?> getById(String id) => throw UnimplementedError();

  @override
  Future<Symptom> createCustom({
    required String name,
    String category = 'genel',
    String description = '',
  }) =>
      throw UnimplementedError();

  @override
  Future<void> softDelete(String id) => throw UnimplementedError();
}

Widget _app(List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SymptomScreen(),
      ),
    );

/// Genişlik bilerek geniş: flutter_test'in Ahem yazı tipi gerçek yazıdan çok
/// geniş çizilir, dar ekranda düzen taşması (bu testlerle ilgisiz) çıkar.
void _phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Listeyi açıp görünen semptom adlarını sırasıyla verir.
Future<List<String>> _openAndReadNames(WidgetTester tester) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  return tester
      .widgetList<DropdownMenuItem<String>>(find.byType(DropdownMenuItem<String>))
      .map((item) => (item.child as Text).data!)
      .toList();
}

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDb());
  tearDown(() => db.close());

  List<Override> overrides() => [databaseProvider.overrideWithValue(db)];

  Future<void> seed(WidgetTester tester) async {
    await tester.runAsync(() => seedLoaderFor(db).seedIfNeeded());
  }

  group('SymptomScreen / semptom listesini okuma', () {
    testWidgets('hazır semptomlar yerel veritabanından, Türkçe sırayla listelenir',
        (tester) async {
      _phoneSize(tester);
      await seed(tester);

      await tester.pumpWidget(_app(overrides()));
      await tester.pumpAndSettle();

      final names = await _openAndReadNames(tester);
      // Başlangıç verisi: 8 hazır semptom. "Öksürük", "Yorgunluk"tan önce gelir
      // (veritabanının ikili sırası onu sona atardı).
      expect(names, [
        'Ateş',
        'Baş ağrısı',
        'Baş dönmesi',
        'Bulantı',
        'Karın ağrısı',
        'Nefes darlığı',
        'Öksürük',
        'Yorgunluk',
      ]);
    });

    testWidgets('kullanıcının eklediği özel semptom da listelenir',
        (tester) async {
      _phoneSize(tester);
      await seed(tester);
      await tester.runAsync(() =>
          DriftSymptomRepository(db).createCustom(name: 'Kulak çınlaması'));

      await tester.pumpWidget(_app(overrides()));
      await tester.pumpAndSettle();

      final names = await _openAndReadNames(tester);
      expect(names, hasLength(9));
      expect(names, contains('Kulak çınlaması'));
    });

    testWidgets('silinmiş semptom listelenmez', (tester) async {
      _phoneSize(tester);
      await seed(tester);
      final custom = (await tester.runAsync(() =>
          DriftSymptomRepository(db).createCustom(name: 'Silinecek')))!;
      await tester.runAsync(() => DriftSymptomRepository(db).softDelete(custom.id));

      await tester.pumpWidget(_app(overrides()));
      await tester.pumpAndSettle();

      final names = await _openAndReadNames(tester);
      expect(names, hasLength(8));
      expect(names, isNot(contains('Silinecek')));
    });

    testWidgets('liste okunamazsa mesaj çıkar ve Kaydet pasif olur',
        (tester) async {
      _phoneSize(tester);
      await tester.pumpWidget(_app([
        symptomRepositoryProvider.overrideWithValue(_FailingSymptomRepository()),
      ]));
      await tester.pumpAndSettle();

      expect(find.textContaining('Semptom listesi okunamadı'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });
  });

  group('SymptomScreen / giriş kaydetme', () {
    Future<List<SymptomEntry>> allEntries(WidgetTester tester) =>
        tester
            .runAsync(() => DriftSymptomEntryRepository(db)
                .listInRange(DateTime.utc(2000), DateTime.utc(2100)))
            .then((v) => v!);

    Future<void> openAndPick(WidgetTester tester, String name) async {
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(name).last);
      await tester.pumpAndSettle();
    }

    Future<void> tapSave(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(ElevatedButton, 'Kaydet'));
      await tester.pumpAndSettle();
    }

    Future<void> openApp(WidgetTester tester, [List<Override>? extra]) async {
      _phoneSize(tester);
      await seed(tester);
      await tester.pumpWidget(_app([
        ...overrides(),
        clockProvider.overrideWithValue(_now),
        ...?extra,
      ]));
      await tester.pumpAndSettle();
    }

    testWidgets('semptom seçilmeden kaydedilmez', (tester) async {
      await openApp(tester);

      await tapSave(tester);

      expect(find.text('Lütfen bir semptom seçin'), findsOneWidget);
      expect(await allEntries(tester), isEmpty);
    });

    testWidgets(
        'giriş yerel veritabanına yazılır: semptom, şiddet, konum, not, zaman; '
        'form sıfırlanır; dönem bağlanmaz', (tester) async {
      await openApp(tester);

      await openAndPick(tester, 'Baş ağrısı');
      await tester.enterText(find.byType(TextField).at(0), '  Şakaklarda ');
      await tester.enterText(find.byType(TextField).at(1), 'sabahtan beri');
      await tapSave(tester);

      final entries = await allEntries(tester);
      expect(entries, hasLength(1));
      final e = entries.single;
      expect(e.symptomId, SeedLoader.symptomId('headache'));
      expect(e.severity, 5); // varsayılan
      expect(e.location, 'Şakaklarda'); // kırpılmış
      expect(e.notes, 'sabahtan beri');
      expect(e.timestamp.toUtc(), _now().toUtc()); // şimdiki zaman
      expect(e.episodeId, isNull);

      expect(find.text('Semptom kaydedildi'), findsOneWidget);
      // Form sıfırlandı: seçim kalktı, alanlar boş, şiddet varsayılanda.
      expect(find.text('Semptom seçin'), findsOneWidget);
      expect(find.text('Şiddet: 5'), findsOneWidget);
      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields.every((f) => f.controller!.text.isEmpty), isTrue);
    });

    testWidgets('kaydırıcıyla seçilen şiddet kaydedilir', (tester) async {
      await openApp(tester);

      await openAndPick(tester, 'Ateş');
      await tester.drag(find.byType(Slider), const Offset(300, 0));
      await tester.pumpAndSettle();
      final shown = int.parse(RegExp(r'Şiddet: (\d+)')
          .firstMatch(tester
              .widget<Text>(find.textContaining('Şiddet: '))
              .data!)!
          .group(1)!);
      expect(shown, greaterThan(5)); // sağa çekildi
      await tapSave(tester);

      final entries = await allEntries(tester);
      expect(entries.single.severity, shown);
    });

    testWidgets('yazma hata verirse mesaj çıkar, form değerleri korunur',
        (tester) async {
      await openApp(tester, [
        symptomEntryRepositoryProvider
            .overrideWithValue(_FailingEntryRepository()),
      ]);

      await openAndPick(tester, 'Baş ağrısı');
      await tester.enterText(find.byType(TextField).at(0), 'Şakaklarda');
      await tapSave(tester);

      expect(find.textContaining('Semptom kaydedilemedi'), findsOneWidget);
      expect(find.text('Baş ağrısı'), findsOneWidget); // seçim durur
      expect(
        tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
        'Şakaklarda',
      );
      // Tekrar denenebilir.
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNotNull);
    });
  });

  group('SymptomScreen / dönem akışı', () {
    final headacheId = SeedLoader.symptomId('headache');

    Future<void> openApp(WidgetTester tester, [List<Override>? extra]) async {
      _phoneSize(tester);
      await seed(tester);
      await tester.pumpWidget(_app([
        ...overrides(),
        clockProvider.overrideWithValue(_now),
        ...?extra,
      ]));
      await tester.pumpAndSettle();
    }

    /// Semptomu seçer, istenirse konum yazar, Kaydet'e basar.
    Future<void> record(WidgetTester tester, String symptom,
        {String? location}) async {
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(symptom).last);
      await tester.pumpAndSettle();
      if (location != null) {
        await tester.enterText(find.byType(TextField).at(0), location);
      }
      await tester.tap(find.widgetWithText(ElevatedButton, 'Kaydet'));
      await tester.pumpAndSettle();
    }

    Future<void> choose(WidgetTester tester, String label) async {
      await tester.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.text(label)));
      await tester.pumpAndSettle();
    }

    Future<List<SymptomEntry>> entries(WidgetTester tester) => tester
        .runAsync(() => DriftSymptomEntryRepository(db)
            .listInRange(DateTime.utc(2000), DateTime.utc(2100)))
        .then((v) => v!);

    Future<List<Episode>> episodes(WidgetTester tester) =>
        tester.runAsync(() => db.select(db.episodes).get()).then((v) => v!);

    Future<List<EpisodeLocationEntry>> locations(WidgetTester tester) => tester
        .runAsync(() => db.select(db.episodeLocationEntries).get())
        .then((v) => v!);

    Future<Episode> seedOngoing(WidgetTester tester, String symptomId) async {
      return (await tester.runAsync(() => DriftEpisodeRepository(db)
          .start(symptomId: symptomId, startTime: utc(2026, 11, 5, 8))))!;
    }

    /// Kullanıcıya "atak" denmez: görünen hiçbir metinde geçmemeli.
    void expectNoAtak(WidgetTester tester) {
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => (t.data ?? '').toLowerCase());
      expect(texts.where((t) => t.contains('atak')), isEmpty);
    }

    testWidgets('devam eden dönem yoksa takip sorulur; "Hayır" dönem açmaz',
        (tester) async {
      await openApp(tester);

      await record(tester, 'Baş ağrısı');

      expect(find.text('Dönem takibi'), findsOneWidget);
      expect(find.text('Bu şikâyeti bir dönem olarak takip etmek ister misiniz?'),
          findsOneWidget);
      expectNoAtak(tester);

      await choose(tester, 'Hayır, sadece kaydet');

      expect(await episodes(tester), isEmpty);
      final saved = await entries(tester);
      expect(saved, hasLength(1));
      expect(saved.single.episodeId, isNull);
      expect(find.text('Semptom kaydedildi'), findsOneWidget);
    });

    testWidgets(
        '"Evet": dönem girişin zamanında başlar, giriş ona bağlanır, konum '
        'dönemin ilk konumu olur', (tester) async {
      await openApp(tester);

      await record(tester, 'Baş ağrısı', location: 'Şakaklarda');
      await choose(tester, 'Evet, dönem başlat');

      final eps = await episodes(tester);
      expect(eps, hasLength(1));
      final ep = eps.single;
      expect(ep.symptomId, headacheId);
      expect(ep.startTime.toUtc(), _now().toUtc());
      expect(ep.endedAt, isNull);
      expect(ep.status, EpisodeStatus.ongoing);
      expect((await entries(tester)).single.episodeId, ep.id);
      final locs = await locations(tester);
      expect(locs.map((l) => l.location), ['Şakaklarda']);
      expect(find.text('Semptom kaydedildi ve dönem başlatıldı'),
          findsOneWidget);
    });

    testWidgets('devam eden dönem varken seçenekler sorulur; konum yoksa '
        '"Yeni konumla ekle" görünmez', (tester) async {
      await openApp(tester);
      await seedOngoing(tester, headacheId);

      await record(tester, 'Baş ağrısı');

      expect(find.text('Devam eden Baş ağrısı döneminiz var'), findsOneWidget);
      expect(find.text('Bu kayıt nasıl eklensin?'), findsOneWidget);
      expect(find.text('Bağımsız kayıt'), findsOneWidget);
      expect(find.text('Döneme ekle'), findsOneWidget);
      expect(find.text('Yeni konumla ekle'), findsNothing);
      expectNoAtak(tester);
      // Aynı semptom için ikinci bir dönem açılmaz.
      expect(await episodes(tester), hasLength(1));
    });

    testWidgets('"Döneme ekle": giriş bağlanır, konum dönemin konumlarına '
        'eklenmez', (tester) async {
      await openApp(tester);
      final ep = await seedOngoing(tester, headacheId);

      await record(tester, 'Baş ağrısı', location: 'Şakaklarda');
      expect(find.text('Yeni konumla ekle'), findsOneWidget); // konum yazıldı
      await choose(tester, 'Döneme ekle');

      expect((await entries(tester)).single.episodeId, ep.id);
      expect(await locations(tester), isEmpty);
      expect(await episodes(tester), hasLength(1));
      expect(find.text('Semptom kaydedildi ve döneme eklendi'), findsOneWidget);
    });

    testWidgets('"Yeni konumla ekle": konum bir kez eklenir, tekrarı çoğaltmaz',
        (tester) async {
      await openApp(tester);
      final ep = await seedOngoing(tester, headacheId);

      await record(tester, 'Baş ağrısı', location: 'Göz arkasında');
      await choose(tester, 'Yeni konumla ekle');
      expect(find.text('Semptom kaydedildi, yeni konumla döneme eklendi'),
          findsOneWidget);

      await record(tester, 'Baş ağrısı', location: 'Göz arkasında');
      await choose(tester, 'Yeni konumla ekle');

      final saved = await entries(tester);
      expect(saved, hasLength(2));
      expect(saved.every((e) => e.episodeId == ep.id), isTrue);
      expect((await locations(tester)).map((l) => l.location), ['Göz arkasında']);
    });

    testWidgets('"Bağımsız kayıt": giriş döneme bağlanmaz', (tester) async {
      await openApp(tester);
      await seedOngoing(tester, headacheId);

      await record(tester, 'Baş ağrısı', location: 'Şakaklarda');
      await choose(tester, 'Bağımsız kayıt');

      expect((await entries(tester)).single.episodeId, isNull);
      expect(await locations(tester), isEmpty);
      expect(find.text('Semptom kaydedildi'), findsOneWidget);
    });

    testWidgets('başka semptomun devam eden dönemi karışmaz', (tester) async {
      await openApp(tester);
      await seedOngoing(tester, SeedLoader.symptomId('fever'));

      await record(tester, 'Baş ağrısı');

      // Baş ağrısı için devam eden dönem yok: takip sorulur.
      expect(find.text('Dönem takibi'), findsOneWidget);
      expect(find.textContaining('Devam eden'), findsNothing);
    });

    testWidgets('dönem işlemi hata verirse mesaj çıkar, giriş yine de kayıtlıdır',
        (tester) async {
      await openApp(tester, [
        episodeServiceProvider.overrideWithValue(_FailingEpisodeService(db)),
      ]);

      await record(tester, 'Baş ağrısı');

      expect(find.text('Semptom kaydedildi ama dönem işlemi yapılamadı.'),
          findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(await entries(tester), hasLength(1));
    });
  });

  group('SymptomScreen / yeni semptom ekleme', () {
    Future<void> openApp(WidgetTester tester) async {
      _phoneSize(tester);
      await seed(tester);
      await tester.pumpWidget(_app(overrides()));
      await tester.pumpAndSettle();
    }

    Future<void> addViaDialog(WidgetTester tester, String name) async {
      await tester.tap(find.text('Yeni ekle'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextField)),
        name,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Ekle'));
      await tester.pumpAndSettle();
    }

    Future<List<Symptom>> symptoms(WidgetTester tester) => tester
        .runAsync(() => DriftSymptomRepository(db).listActive())
        .then((v) => v!);

    testWidgets('yeni ad özel semptom olarak eklenir, listelenir ve seçilir',
        (tester) async {
      await openApp(tester);

      await addViaDialog(tester, '  Kulak çınlaması ');

      final all = await symptoms(tester);
      expect(all, hasLength(9));
      final created = all.firstWhere((s) => s.name == 'Kulak çınlaması');
      expect(created.isCustom, isTrue);
      expect(find.text('Semptom eklendi'), findsOneWidget);
      // Eklenen semptom seçili görünür (kapalı listede seçili ad yazar).
      expect(find.text('Kulak çınlaması'), findsOneWidget);
    });

    testWidgets(
        'aynı ad (büyük/küçük harf, fazla boşluk, Türkçe harf) yeni satır açmaz, '
        'mevcut semptom seçilir', (tester) async {
      await openApp(tester);

      await addViaDialog(tester, 'BAŞ   AĞRISI ');

      expect(await symptoms(tester), hasLength(8)); // yeni satır yok
      expect(find.text('Bu semptom listede zaten var, onu seçtim.'),
          findsOneWidget);
      expect(find.text('Baş ağrısı'), findsOneWidget); // mevcut olan seçili
    });

    testWidgets('Türkçe I/İ kuralı: "IŞIK" ile "ışık" aynı ad sayılır',
        (tester) async {
      await openApp(tester);
      await tester.runAsync(() =>
          DriftSymptomRepository(db).createCustom(name: 'Işık hassasiyeti'));
      // Ekranı özel semptom eklenmiş veritabanıyla yeniden aç.
      await tester.pumpWidget(_app(overrides()));
      await tester.pumpAndSettle();

      await addViaDialog(tester, 'IŞIK HASSASİYETİ');

      expect(await symptoms(tester), hasLength(9)); // 8 hazır + 1 özel, çift yok
    });

    testWidgets('boş ad eklenmez, pencere açık kalır; iptal hiçbir şey eklemez',
        (tester) async {
      await openApp(tester);

      await tester.tap(find.text('Yeni ekle'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Ekle'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget); // hâlâ açık

      await tester.tap(find.widgetWithText(TextButton, 'İptal'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(await symptoms(tester), hasLength(8));
    });
  });
}

/// Devam eden dönem sorgusu hata verir; dönem hata yolunu denemek için.
class _FailingEpisodeService extends EpisodeService {
  _FailingEpisodeService(AppDatabase db)
      : super(
          episodes: DriftEpisodeRepository(db),
          entries: DriftSymptomEntryRepository(db),
        );

  @override
  Future<Episode?> activeEpisode(String symptomId) async =>
      throw StateError('okunamadı');
}

/// Yazma her zaman hata verir; kaydetme hata yolunu denemek için.
class _FailingEntryRepository implements SymptomEntryRepository {
  @override
  Future<SymptomEntry> create({
    required String symptomId,
    required int severity,
    required DateTime timestamp,
    String? episodeId,
    String notes = '',
    String location = '',
  }) async =>
      throw StateError('yazılamadı');

  @override
  Future<SymptomEntry?> getById(String id) => throw UnimplementedError();

  @override
  Future<List<SymptomEntry>> listInRange(DateTime from, DateTime to) =>
      throw UnimplementedError();

  @override
  Future<List<SymptomEntry>> listSince(DateTime from) =>
      throw UnimplementedError();

  @override
  Future<List<SymptomEntry>> listForEpisode(String episodeId) =>
      throw UnimplementedError();

  @override
  Future<void> attachToEpisode(String entryId, String episodeId) =>
      throw UnimplementedError();

  @override
  Future<void> softDelete(String id) => throw UnimplementedError();
}
