import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/repositories/symptom_repository.dart';
import 'package:mobile/features/health/screens/symptom_screen.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../data/test_support.dart';

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
    testWidgets('hazır semptomlar yerel veritabanından listelenir',
        (tester) async {
      _phoneSize(tester);
      await seed(tester);
      final expected = (await tester.runAsync(
              () => DriftSymptomRepository(db).listActive()))!
          .map((s) => s.name)
          .toList();
      expect(expected, hasLength(8)); // başlangıç verisi: 8 hazır semptom

      await tester.pumpWidget(_app(overrides()));
      await tester.pumpAndSettle();

      final names = await _openAndReadNames(tester);
      expect(names, expected); // aynı kayıtlar, aynı sıra
      expect(names, containsAll(['Baş ağrısı', 'Ateş', 'Öksürük']));
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
}
