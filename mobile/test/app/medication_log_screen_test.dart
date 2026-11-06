import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/enums.dart';
import 'package:mobile/data/database/seed_loader.dart';
import 'package:mobile/data/repositories/medication_log_repository.dart';
import 'package:mobile/data/repositories/medication_repository.dart';
import 'package:mobile/domain/services/medication_service.dart';
import 'package:mobile/features/medication/screens/medication_log_screen.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../data/test_support.dart';

/// Yerel 6 Kasım 2026, öğleden önce.
DateTime _now() => DateTime(2026, 11, 6, 10, 30);

/// İlaç servisi bozuk: listeyi ya da kaydı hata verdirerek ekranın hata
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
        home: const MedicationLogScreen(),
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

  final parolId = SeedLoader.medicationId('parol');

  List<Override> overrides([List<Override>? extra]) => [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(_now),
        ...?extra,
      ];

  Future<void> openApp(
    WidgetTester tester, {
    List<Override>? extra,
    bool seed = true,
  }) async {
    _phoneSize(tester);
    if (seed) await tester.runAsync(() => seedLoaderFor(db).seedIfNeeded());
    await tester.pumpWidget(_app(overrides(extra)));
    await tester.pumpAndSettle();
  }

  Future<List<MedicationLog>> allLogs(WidgetTester tester) => tester
      .runAsync(() => DriftMedicationLogRepository(db)
          .listInRange(DateTime.utc(2000), DateTime.utc(2100)))
      .then((v) => v!);

  Future<List<Medication>> allMedications(WidgetTester tester) => tester
      .runAsync(() => DriftMedicationRepository(db).listAvailable())
      .then((v) => v!);

  Future<void> pickMedication(WidgetTester tester, String name) async {
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(name).last);
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(ElevatedButton, 'Kaydet'));
    await tester.pumpAndSettle();
  }

  group('MedicationLogScreen / ilaç listesi', () {
    testWidgets(
        'ilaçlar Türkçe sırada ve türüyle listelenir (kullanıcının ilacı dahil)',
        (tester) async {
      await tester.runAsync(() => seedLoaderFor(db).seedIfNeeded());
      // "Çinko": ikili sıra Ç'yi Z'den sonraya atar, Türkçe sırada C'den sonra,
      // D'den önce gelir.
      await tester.runAsync(() => DriftMedicationRepository(db)
          .create(name: 'Çinko', type: MedicationType.chronic));
      await openApp(tester, seed: false);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      final names = tester
          .widgetList<DropdownMenuItem<String>>(
              find.byType(DropdownMenuItem<String>))
          .map((i) => (i.child as Text).data!)
          .toList();
      expect(names, hasLength(11)); // 10 katalog + Çinko
      final plain = names.map((n) => n.split(' · ').first).toList();
      expect(plain.indexOf('Çinko'), lessThan(plain.indexOf('D Vitamini')));
      expect(names, contains('Çinko · Kronik'));
      expect(names.where((n) => n.endsWith('· Semptomatik')), isNotEmpty);
    });

    testWidgets('liste okunamazsa mesaj çıkar, Kaydet pasif, yazmak mesajı silmez',
        (tester) async {
      await openApp(tester, extra: [
        medicationServiceProvider
            .overrideWithValue(_BrokenMedicationService(db, failList: true)),
      ]);

      expect(find.textContaining('İlaç listesi okunamadı'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Kaydet'))
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField).first, '2');
      await tester.pump();
      expect(find.textContaining('İlaç listesi okunamadı'), findsOneWidget);
    });

    testWidgets('klavye açıkken (kısa ekran) taşma olmaz, Kaydet\'e ulaşılır',
        (tester) async {
      tester.view.physicalSize = const Size(800, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(() => seedLoaderFor(db).seedIfNeeded());
      await tester.pumpWidget(_app(overrides()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final save = find.widgetWithText(ElevatedButton, 'Kaydet');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      expect(tester.getBottomLeft(save).dy, lessThanOrEqualTo(300));
    });
  });

  group('MedicationLogScreen / kaydetme', () {
    testWidgets(
        'ilaç, doz, birim ve not yerel veritabanına yazılır; form sıfırlanır; '
        'döneme bağlanmaz', (tester) async {
      await openApp(tester);

      await pickMedication(tester, 'Parol');
      await tester.enterText(find.byType(TextField).at(0), '1,5'); // ondalık virgül
      await tester.tap(find.byType(DropdownButton<DoseUnit>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('damla').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), '  yemekten sonra ');
      await tapSave(tester);

      final logs = await allLogs(tester);
      expect(logs, hasLength(1));
      final log = logs.single;
      expect(log.medicationId, parolId);
      expect(log.doseAmount, 1.5);
      expect(log.doseUnit, DoseUnit.drop);
      expect(log.notes, 'yemekten sonra'); // kırpılmış
      expect(log.episodeId, isNull);
      expect(log.conditionId, isNull);
      expect(log.takenAt.toUtc(), _now().toUtc()); // şimdiki zaman

      expect(find.text('İlaç kaydedildi.'), findsOneWidget);
      // Form sıfırlandı: seçim kalktı, alanlar boş, birim varsayılanda.
      expect(find.text('İlaç seçin...'), findsOneWidget);
      expect(
        tester.widgetList<TextField>(find.byType(TextField))
            .every((f) => f.controller!.text.isEmpty),
        isTrue,
      );
      expect(find.text('tablet'), findsOneWidget);
    });

    testWidgets('doz ve not boş bırakılabilir; varsayılan birim tablet',
        (tester) async {
      await openApp(tester);

      await pickMedication(tester, 'Parol');
      await tapSave(tester);

      final log = (await allLogs(tester)).single;
      expect(log.doseAmount, isNull);
      expect(log.doseUnit, DoseUnit.tablet);
      expect(log.notes, '');
    });

    testWidgets('ilaç seçilmeden kaydedilmez; seçilince uyarı kalkar',
        (tester) async {
      await openApp(tester);

      await tapSave(tester);
      expect(find.text('Lütfen bir ilaç seçin.'), findsOneWidget);
      expect(await allLogs(tester), isEmpty);

      await pickMedication(tester, 'Parol');
      expect(find.text('Lütfen bir ilaç seçin.'), findsNothing);
    });

    for (final bad in ['abc', '0', '-2']) {
      testWidgets('geçersiz doz "$bad" reddedilir; yazmaya başlayınca uyarı kalkar',
          (tester) async {
        await openApp(tester);

        await pickMedication(tester, 'Parol');
        await tester.enterText(find.byType(TextField).at(0), bad);
        await tapSave(tester);
        expect(find.text('Doz sıfırdan büyük bir sayı olmalı'), findsOneWidget);
        expect(await allLogs(tester), isEmpty);

        await tester.enterText(find.byType(TextField).at(0), '2');
        await tester.pump();
        expect(find.text('Doz sıfırdan büyük bir sayı olmalı'), findsNothing);
      });
    }

    testWidgets('yazma hata verirse mesaj çıkar, değerler korunur, tekrar denenebilir',
        (tester) async {
      await openApp(tester, extra: [
        medicationServiceProvider
            .overrideWithValue(_BrokenMedicationService(db, failLog: true)),
      ]);

      await pickMedication(tester, 'Parol');
      await tester.enterText(find.byType(TextField).at(0), '2');
      await tapSave(tester);

      expect(find.textContaining('İlaç kaydedilemedi'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
          '2');
      expect(find.textContaining('Parol'), findsOneWidget); // seçim durur
      expect(
        tester
            .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Kaydet'))
            .onPressed,
        isNotNull,
      );
      expect(await allLogs(tester), isEmpty);
    });
  });

  group('MedicationLogScreen / yeni ilaç ekleme', () {
    Future<void> addViaDialog(WidgetTester tester, String name) async {
      await tester.tap(find.text('Yeni ilaç ekle'));
      await tester.pumpAndSettle();
      expect(find.text('Yeni İlaç Ekle'), findsOneWidget);
      await tester.enterText(
          find.descendant(
              of: find.byType(AlertDialog), matching: find.byType(TextField)),
          name);
      await tester.tap(find.text('Ekle'));
      await tester.pumpAndSettle();
    }

    testWidgets(
        'yeni ilaç kullanıcının kendi ilacı (semptomatik) olarak eklenir ve '
        'seçilir', (tester) async {
      await openApp(tester);

      await addViaDialog(tester, '  Kulak damlası ');

      final meds = await allMedications(tester);
      final added = meds.where((m) => m.name == 'Kulak damlası').single; // kırpılmış
      expect(added.type, MedicationType.symptomatic);
      expect(added.isCatalog, isFalse);
      expect(meds, hasLength(11));
      expect(find.text('Kulak damlası eklendi.'), findsOneWidget);
      // Eklenen ilaç seçili geldi.
      expect(find.text('Kulak damlası · Semptomatik'), findsOneWidget);

      // Seçili ilaçla kayıt yapılabilir.
      await tapSave(tester);
      expect((await allLogs(tester)).single.medicationId, added.id);
    });

    testWidgets(
        'aynı adlı ilaç (büyük/küçük harf, fazla boşluk önemsiz) yeni satır '
        'açmaz, mevcut olan seçilir', (tester) async {
      await openApp(tester);

      await addViaDialog(tester, '  PAROL ');

      expect(await allMedications(tester), hasLength(10)); // artmadı
      expect(find.text('Parol zaten var, seçildi.'), findsOneWidget);
      await tapSave(tester);
      expect((await allLogs(tester)).single.medicationId, parolId);
    });

    testWidgets('iptal edilirse ilaç eklenmez', (tester) async {
      await openApp(tester);

      await tester.tap(find.text('Yeni ilaç ekle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('İptal'));
      await tester.pumpAndSettle();

      expect(await allMedications(tester), hasLength(10));
      expect(find.text('Yeni İlaç Ekle'), findsNothing);
    });
  });
}
