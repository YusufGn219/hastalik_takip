import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/seed_loader.dart';
import 'package:mobile/data/repositories/medication_log_repository.dart';
import 'package:mobile/data/repositories/medication_repository.dart';
import 'package:mobile/domain/services/medication_service.dart';
import 'package:mobile/features/medication/screens/chronic_condition_screen.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../data/test_support.dart';

/// Liste okunamıyormuş gibi davranan servis.
class _BrokenService extends MedicationService {
  _BrokenService(AppDatabase db)
      : super(
          medications: DriftMedicationRepository(db),
          logs: DriftMedicationLogRepository(db),
        );

  @override
  Future<List<ConditionSummary>> conditions() =>
      throw StateError('okunamadı');
}

/// Kaydı reddeden servis (silme ve kaydetme hata yolları için).
class _FailingWriteService extends MedicationService {
  _FailingWriteService(AppDatabase db)
      : super(
          medications: DriftMedicationRepository(db),
          logs: DriftMedicationLogRepository(db),
        );

  @override
  Future<void> deleteCondition(String id) => throw StateError('silinemedi');
}

void main() {
  late AppDatabase db;
  late DriftMedicationRepository repo;
  late MedicationService service;

  setUp(() {
    db = createTestDb();
    repo = DriftMedicationRepository(db);
    service = MedicationService(
      medications: repo,
      logs: DriftMedicationLogRepository(db),
    );
  });
  tearDown(() => db.close());

  final parol = SeedLoader.medicationId('parol');
  final vitD = SeedLoader.medicationId('vitamin_d');

  Future<void> openApp(WidgetTester tester, {List<Override>? extra}) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => seedLoaderFor(db).seedIfNeeded());
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        ...?extra,
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ChronicConditionScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<T> run<T>(WidgetTester tester, Future<T> Function() f) =>
      tester.runAsync(f).then((v) => v as T);

  Finder inDialog(Finder f) =>
      find.descendant(of: find.byType(AlertDialog), matching: f);

  Future<List<ConditionSummary>> conditions(WidgetTester tester) =>
      run(tester, () => service.conditions());

  Future<void> tapSaveInDialog(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
    await tester.pumpAndSettle();
  }

  group('liste', () {
    testWidgets('boşken ipucu çıkar', (tester) async {
      await openApp(tester);
      expect(find.text('Henüz kronik hastalık eklenmemiş.'), findsOneWidget);
    });

    testWidgets('hastalıklar ve ilaçları Türkçe sırada gösterilir',
        (tester) async {
      await run(tester, () => seedLoaderFor(db).seedIfNeeded());
      await run(tester, () async {
        await service.createCondition(name: 'Tansiyon', medicationIds: [parol]);
        await service.createCondition(name: 'Çölyak', medicationIds: [vitD]);
        await service.createCondition(name: 'Astım');
      });
      await openApp(tester);

      final names = ['Astım', 'Çölyak', 'Tansiyon'];
      final ys = [for (final n in names) tester.getTopLeft(find.text(n)).dy];
      expect(ys, orderedEquals([...ys]..sort()));
      expect(find.text('Parol'), findsOneWidget);
      expect(find.text('D Vitamini'), findsOneWidget);
      expect(find.text('İlaç eklenmemiş.'), findsOneWidget); // Astım
    });

    testWidgets('liste okunamazsa uyarı çıkar, ekleme kapalı', (tester) async {
      await openApp(tester, extra: [
        medicationServiceProvider.overrideWithValue(_BrokenService(db)),
      ]);
      expect(
        find.textContaining('Kronik hastalıklar okunamadı'),
        findsOneWidget,
      );
      final add = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add));
      expect(add.onPressed, isNull);
    });
  });

  group('ekleme', () {
    testWidgets('ad ve ilaçlarla eklenir, listede belirir', (tester) async {
      await openApp(tester);
      await tester.tap(find.byTooltip('Hastalık ekle'));
      await tester.pumpAndSettle();
      expect(find.text('Yeni Kronik Hastalık'), findsOneWidget);

      await tester.enterText(inDialog(find.byType(TextField)), '  Migren ');
      await tester.tap(find.byKey(ValueKey('med-$parol')));
      await tester.tap(find.byKey(ValueKey('med-$vitD')));
      await tester.pumpAndSettle();
      await tapSaveInDialog(tester);

      final list = await conditions(tester);
      expect(list.single.condition.name, 'Migren');
      expect(list.single.medications.map((m) => m.id).toSet(), {parol, vitD});
      expect(find.text('Hastalık eklendi.'), findsOneWidget);
      expect(find.text('Migren'), findsOneWidget);
      expect(find.text('Yeni Kronik Hastalık'), findsNothing);
    });

    testWidgets('boş ad hata verir, pencere açık kalır', (tester) async {
      await openApp(tester);
      await tester.tap(find.byTooltip('Hastalık ekle'));
      await tester.pumpAndSettle();
      await tapSaveInDialog(tester);

      expect(find.text('Hastalık adı boş olamaz.'), findsOneWidget);
      expect(find.text('Yeni Kronik Hastalık'), findsOneWidget);
      expect(await conditions(tester), isEmpty);
    });

    testWidgets('aynı ad hata verir; yazılanlar ve seçimler korunur',
        (tester) async {
      await run(tester, () => service.createCondition(name: 'Migren'));
      await openApp(tester);
      await tester.tap(find.byTooltip('Hastalık ekle'));
      await tester.pumpAndSettle();
      await tester.enterText(inDialog(find.byType(TextField)), 'migren');
      await tester.tap(find.byKey(ValueKey('med-$parol')));
      await tester.pumpAndSettle();
      await tapSaveInDialog(tester);

      expect(find.text('Bu adla bir kronik hastalık zaten var.'),
          findsOneWidget);
      expect(find.text('migren'), findsOneWidget); // yazılan ad
      expect(
        tester
            .widget<CheckboxListTile>(find.byKey(ValueKey('med-$parol')))
            .value,
        isTrue,
      );
      expect(await conditions(tester), hasLength(1));

      // Yazmaya başlayınca hata kalkar.
      await tester.enterText(inDialog(find.byType(TextField)), 'migren 2');
      await tester.pump();
      expect(find.text('Bu adla bir kronik hastalık zaten var.'), findsNothing);
    });

    testWidgets('hata metni ilaç listesinin altında değil, ad alanının altında',
        (tester) async {
      await run(tester, () => service.createCondition(name: 'Migren'));
      await openApp(tester);
      await tester.tap(find.byTooltip('Hastalık ekle'));
      await tester.pumpAndSettle();
      await tester.enterText(inDialog(find.byType(TextField)), 'migren');
      await tapSaveInDialog(tester);

      final errorTop =
          tester.getTopLeft(find.byKey(const ValueKey('cond-dialog-error'))).dy;
      final fieldBottom =
          tester.getBottomLeft(inDialog(find.byType(TextField))).dy;
      final firstMedTop =
          tester.getTopLeft(find.byKey(ValueKey('med-$parol'))).dy;
      expect(errorTop, greaterThanOrEqualTo(fieldBottom));
      expect(errorTop, lessThan(firstMedTop));
    });

    testWidgets('İptal hiçbir şey yazmaz', (tester) async {
      await openApp(tester);
      await tester.tap(find.byTooltip('Hastalık ekle'));
      await tester.pumpAndSettle();
      await tester.enterText(inDialog(find.byType(TextField)), 'Migren');
      await tester.tap(find.text('İptal'));
      await tester.pumpAndSettle();
      expect(await conditions(tester), isEmpty);
      expect(find.text('Yeni Kronik Hastalık'), findsNothing);
    });
  });

  group('düzenleme ve silme', () {
    testWidgets('mevcut ad ve ilaçlar dolu gelir; ad ve ilaçlar güncellenir',
        (tester) async {
      await run(tester, () => seedLoaderFor(db).seedIfNeeded());
      await run(
        tester,
        () => service.createCondition(name: 'Astim', medicationIds: [parol]),
      );
      await openApp(tester);

      await tester.tap(find.byTooltip('Düzenle'));
      await tester.pumpAndSettle();
      expect(find.text('Hastalığı Düzenle'), findsOneWidget);
      expect(find.text('Astim'), findsWidgets); // alan içinde de
      expect(
        tester
            .widget<CheckboxListTile>(find.byKey(ValueKey('med-$parol')))
            .value,
        isTrue,
      );

      await tester.enterText(inDialog(find.byType(TextField)), 'Astım');
      await tester.tap(find.byKey(ValueKey('med-$parol'))); // kaldır
      await tester.tap(find.byKey(ValueKey('med-$vitD'))); // ekle
      await tester.pumpAndSettle();
      await tapSaveInDialog(tester);

      final c = (await conditions(tester)).single;
      expect(c.condition.name, 'Astım');
      expect(c.medications.map((m) => m.id), [vitD]);
      expect(find.text('Hastalık güncellendi.'), findsOneWidget);
    });

    testWidgets('silme onay ister; iptalde silinmez, onayda ilaçlar kalır',
        (tester) async {
      await run(tester, () => seedLoaderFor(db).seedIfNeeded());
      await run(
        tester,
        () => service.createCondition(name: 'Astım', medicationIds: [parol]),
      );
      await openApp(tester);

      await tester.tap(find.byTooltip('Sil'));
      await tester.pumpAndSettle();
      expect(find.text('Hastalık silinsin mi?'), findsOneWidget);
      await tester.tap(find.text('İptal'));
      await tester.pumpAndSettle();
      expect(await conditions(tester), hasLength(1));

      await tester.tap(find.byTooltip('Sil'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
      await tester.pumpAndSettle();

      expect(await conditions(tester), isEmpty);
      expect((await run(tester, () => repo.getById(parol)))!.deletedAt, isNull);
      expect(find.text('Hastalık silindi.'), findsOneWidget);
      expect(find.text('Henüz kronik hastalık eklenmemiş.'), findsOneWidget);
    });

    testWidgets('silme başarısız olursa hata gösterilir, hastalık kalır',
        (tester) async {
      await run(tester, () => service.createCondition(name: 'Astım'));
      await openApp(tester, extra: [
        medicationServiceProvider.overrideWithValue(_FailingWriteService(db)),
      ]);
      await tester.tap(find.byTooltip('Sil'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
      await tester.pumpAndSettle();

      expect(find.text('İşlem yapılamadı. Tekrar deneyin.'), findsOneWidget);
      expect(find.text('Astım'), findsOneWidget);
      expect(await conditions(tester), hasLength(1));
    });
  });
}
