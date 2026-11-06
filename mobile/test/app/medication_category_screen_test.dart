import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/seed_loader.dart';
import 'package:mobile/data/repositories/medication_repository.dart';
import 'package:mobile/features/medication/screens/medication_log_screen.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../data/test_support.dart';

DateTime _now() => DateTime(2026, 11, 6, 10, 30);

void main() {
  late AppDatabase db;
  late DriftMedicationRepository repo;

  setUp(() {
    db = createTestDb();
    repo = DriftMedicationRepository(db);
  });
  tearDown(() => db.close());

  final parolId = SeedLoader.medicationId('parol');

  Future<void> openApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => seedLoaderFor(db).seedIfNeeded());
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(_now),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MedicationLogScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<T> run<T>(WidgetTester tester, Future<T> Function() f) =>
      tester.runAsync(f).then((v) => v as T);

  Finder inDialog(Finder f) =>
      find.descendant(of: find.byType(AlertDialog), matching: f);

  Future<void> pickFromDropdown(
      WidgetTester tester, Finder dropdown, String text) async {
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  /// "Yeni ilaç ekle" penceresini açar, adı yazar; kategori seçimi çağırana kalır.
  Future<void> openAddDialog(WidgetTester tester, String name) async {
    await tester.tap(find.text('Yeni ilaç ekle'));
    await tester.pumpAndSettle();
    await tester.enterText(inDialog(find.byType(TextField)).first, name);
  }

  Future<List<Medication>> meds(WidgetTester tester) =>
      run(tester, () => repo.listAvailable());

  Future<List<MedicationCategory>> cats(WidgetTester tester) =>
      run(tester, () => repo.listCategories());

  group('yeni ilaç penceresi', () {
    testWidgets('yeni kategori yazılırsa kategori oluşur, ilaç ona bağlanır',
        (tester) async {
      await openApp(tester);
      await openAddDialog(tester, 'Kulak damlası');
      await pickFromDropdown(
        tester,
        inDialog(find.byType(DropdownButtonFormField<String?>)),
        'Yeni kategori oluştur…',
      );
      await tester.enterText(inDialog(find.byType(TextField)).last, ' Kulak ');
      await tester.tap(find.text('Ekle'));
      await tester.pumpAndSettle();

      final categories = await cats(tester);
      expect(categories.map((c) => c.name), ['Kulak']);
      final added = (await meds(tester)).singleWhere(
        (m) => m.name == 'Kulak damlası',
      );
      expect(added.categoryId, categories.single.id);
      // Seçili ilaç ve etiketi.
      expect(find.text('Kulak damlası · Kulak'), findsOneWidget);
    });

    testWidgets('var olan kategori seçilebilir', (tester) async {
      await openApp(tester);
      final c = await run(tester, () => repo.createCategory('Ağrı'));
      // Ekran kategorileri açılışta okur: yeniden aç.
      await tester.pumpWidget(const SizedBox());
      await openApp(tester);
      await openAddDialog(tester, 'Majol');
      await pickFromDropdown(
        tester,
        inDialog(find.byType(DropdownButtonFormField<String?>)),
        'Ağrı',
      );
      await tester.tap(find.text('Ekle'));
      await tester.pumpAndSettle();

      final added =
          (await meds(tester)).singleWhere((m) => m.name == 'Majol');
      expect(added.categoryId, c.id);
      expect(find.text('Majol · Ağrı'), findsOneWidget);
    });

    testWidgets('yeni kategori adı var olanla aynıysa kopya açılmaz',
        (tester) async {
      await run(tester, () => repo.createCategory('Ağrı'));
      await openApp(tester);
      await openAddDialog(tester, 'Majol');
      await pickFromDropdown(
        tester,
        inDialog(find.byType(DropdownButtonFormField<String?>)),
        'Yeni kategori oluştur…',
      );
      await tester.enterText(inDialog(find.byType(TextField)).last, 'AĞRI');
      await tester.tap(find.text('Ekle'));
      await tester.pumpAndSettle();

      final categories = await cats(tester);
      expect(categories, hasLength(1));
      final added =
          (await meds(tester)).singleWhere((m) => m.name == 'Majol');
      expect(added.categoryId, categories.single.id);
    });

    testWidgets('kategori seçilmezse ilaç kategorisiz kalır', (tester) async {
      await openApp(tester);
      await openAddDialog(tester, 'Majol');
      await tester.tap(find.text('Ekle'));
      await tester.pumpAndSettle();
      expect(
        (await meds(tester)).singleWhere((m) => m.name == 'Majol').categoryId,
        isNull,
      );
      expect(await cats(tester), isEmpty);
    });
  });

  group('mevcut ilaca kategori atama', () {
    testWidgets('katalog ilacına kategori atanır ve kaldırılır',
        (tester) async {
      await run(tester, () => repo.createCategory('Ağrı'));
      await openApp(tester);
      // İlaç seçilmeden kategori alanı yok.
      expect(find.text('Kategori (isteğe bağlı)'), findsNothing);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Parol').last);
      await tester.pumpAndSettle();

      final catDropdown = find.byType(DropdownButtonFormField<String?>);
      expect(catDropdown, findsOneWidget);
      await pickFromDropdown(tester, catDropdown, 'Ağrı');
      expect(find.text('Kategori güncellendi.'), findsOneWidget);
      final cat = (await cats(tester)).single;
      expect((await run(tester, () => repo.getById(parolId)))!.categoryId,
          cat.id);
      // İlaç listesindeki etiket güncellendi (seçili öğe "Parol · Ağrı").
      expect(find.text('Parol · Ağrı'), findsWidgets);

      await pickFromDropdown(tester, catDropdown, 'Kategorisiz');
      expect((await run(tester, () => repo.getById(parolId)))!.categoryId,
          isNull);
    });
  });

  group('Kategoriler yönetimi', () {
    Future<void> openManager(WidgetTester tester) async {
      await tester.tap(find.text('Kategoriler'));
      await tester.pumpAndSettle();
    }

    testWidgets('boşken ipucu çıkar; kategori eklenir, aynı ad reddedilir',
        (tester) async {
      await openApp(tester);
      await openManager(tester);
      expect(find.text('Henüz kategori yok. Aşağıdan ekleyebilirsiniz.'),
          findsOneWidget);

      await tester.enterText(inDialog(find.byType(TextField)), 'Vitamin');
      await tester.tap(find.widgetWithText(FilledButton, 'Ekle'));
      await tester.pumpAndSettle();
      expect((await cats(tester)).map((c) => c.name), ['Vitamin']);
      expect(inDialog(find.text('Vitamin')), findsOneWidget);

      await tester.enterText(inDialog(find.byType(TextField)), 'vitamin');
      await tester.tap(find.widgetWithText(FilledButton, 'Ekle'));
      await tester.pumpAndSettle();
      expect(find.text('Bu adla bir kategori zaten var.'), findsOneWidget);
      expect(await cats(tester), hasLength(1));
    });

    testWidgets('ad değiştirilir', (tester) async {
      await run(tester, () => repo.createCategory('Agri'));
      await openApp(tester);
      await openManager(tester);

      await tester.tap(find.byTooltip('Adı değiştir'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog).last, // üstteki: ad penceresi
          matching: find.byType(TextField),
        ),
        'Ağrı',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
      await tester.pumpAndSettle();

      expect((await cats(tester)).map((c) => c.name), ['Ağrı']);
      expect(inDialog(find.text('Ağrı')), findsOneWidget);
    });

    testWidgets('silme onay ister; iptalde silinmez, onayda ilaçlar kalır',
        (tester) async {
      // Parol'un var olması için önce katalog yüklenir (openApp tekrar yükler,
      // zararsız).
      await run(tester, () => seedLoaderFor(db).seedIfNeeded());
      final c = await run(tester, () => repo.createCategory('Ağrı'));
      await run(tester, () => repo.setMedicationCategory(parolId, c.id));
      await openApp(tester);
      // Başlangıçta etiket kategoriyi gösterir (aşağıdaki "düştü" kontrolü
      // boşuna geçmesin).
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('Parol · Ağrı'), findsWidgets);
      await tester.tap(find.text('Parol · Ağrı').last);
      await tester.pumpAndSettle();
      await openManager(tester);

      await tester.tap(find.byTooltip('Sil'));
      await tester.pumpAndSettle();
      expect(find.text('Kategori silinsin mi?'), findsOneWidget);
      await tester.tap(find.text('İptal'));
      await tester.pumpAndSettle();
      expect(await cats(tester), hasLength(1));

      await tester.tap(find.byTooltip('Sil'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
      await tester.pumpAndSettle();
      expect(await cats(tester), isEmpty);
      final parol = (await run(tester, () => repo.getById(parolId)))!;
      expect(parol.categoryId, isNull);
      expect(parol.deletedAt, isNull);

      // Pencere kapanınca ekran etiketleri tazelenir.
      await tester.tap(find.text('Kapat'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('Parol · Ağrı'), findsNothing);
      expect(find.text('Parol'), findsWidgets);
    });
  });
}
