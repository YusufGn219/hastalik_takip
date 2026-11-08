// Alan yönetim ekranı: hazır alanları açıp kapatma, kendi alanını ekleme ve
// düzenleme, hata yolları. Gerçek (bellek içi) veritabanı.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/enums.dart';
import 'package:mobile/data/repositories/daily_field_repository.dart';
import 'package:mobile/data/repositories/measurement_repository.dart';
import 'package:mobile/domain/services/daily_field_service.dart';
import 'package:mobile/features/health/screens/daily_fields_screen.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../data/test_support.dart';

DateTime _now() => DateTime(2026, 11, 6, 10, 30);

/// Okuma ve yazma istenince hata verebilen alan deposu.
class _FlakyFieldRepository extends DriftDailyFieldRepository {
  _FlakyFieldRepository(super.db);
  bool failList = false;
  bool failUpdate = false;

  @override
  Future<List<DailyField>> listAll() {
    if (failList) throw StateError('okunamadı');
    return super.listAll();
  }

  @override
  Future<DailyField> update(String id, DailyFieldsCompanion changes) {
    if (failUpdate) throw StateError('yazılamadı');
    return super.update(id, changes);
  }
}

Widget _app(List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const DailyFieldsScreen()),
              ),
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    );

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.tap(find.text('aç'));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

bool _switchOn(WidgetTester tester, String id) =>
    tester.widget<Switch>(find.byKey(Key('alan_ac_$id'))).value;

void main() {
  late AppDatabase db;
  late _FlakyFieldRepository fields;
  late DailyFieldService service;

  setUp(() {
    db = createTestDb();
    fields = _FlakyFieldRepository(db);
    service = DailyFieldService(
      fields: fields,
      measurements: DriftMeasurementRepository(db),
      clock: _now,
      transactor: db.transaction,
    );
  });
  tearDown(() => db.close());

  List<Override> overrides() => [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(_now),
        dailyFieldServiceProvider.overrideWithValue(service),
      ];

  Future<List<DailyField>> all(WidgetTester tester) =>
      tester.runAsync(service.list).then((v) => v!);

  group('liste ve açma/kapatma', () {
    testWidgets('üç hazır alan kapalı gelir; hazır alanda düzenle düğmesi yok', (tester) async {
      await tester.pumpWidget(_app(overrides()));
      await _open(tester);

      expect(find.text('Günlük alanları'), findsOneWidget);
      expect(find.text('Kafein'), findsOneWidget);
      expect(find.text('Spor'), findsOneWidget);
      expect(find.text('Ağrı düzeyi'), findsOneWidget);
      expect(find.byType(Switch), findsNWidgets(3));
      for (final f in await all(tester)) {
        expect(_switchOn(tester, f.id), isFalse);
        expect(find.byKey(Key('alan_duzenle_${f.id}')), findsNothing);
      }
      expect(find.text('Hazır alan · 0–20 bardak'), findsOneWidget);
    });

    testWidgets('anahtar alanı açar ve kapatır', (tester) async {
      await tester.pumpWidget(_app(overrides()));
      await _open(tester);
      final caffeine = (await all(tester)).firstWhere((f) => f.builtinKey == 'caffeine');

      await _tap(tester, 'alan_ac_${caffeine.id}');
      expect(_switchOn(tester, caffeine.id), isTrue);
      expect((await tester.runAsync(service.listActive))!.single.id, caffeine.id);

      await _tap(tester, 'alan_ac_${caffeine.id}');
      expect(_switchOn(tester, caffeine.id), isFalse);
      expect(await tester.runAsync(service.listActive), isEmpty);
    });

    testWidgets('değiştirilemezse uyarı çıkar ve anahtar eski durumda kalır', (tester) async {
      await tester.pumpWidget(_app(overrides()));
      await _open(tester);
      final caffeine = (await all(tester)).firstWhere((f) => f.builtinKey == 'caffeine');

      fields.failUpdate = true;
      await _tap(tester, 'alan_ac_${caffeine.id}');
      expect(find.text('Alan değiştirilemedi.'), findsOneWidget);
      expect(_switchOn(tester, caffeine.id), isFalse);
    });

    testWidgets('liste okunamazsa hata ve "Tekrar dene" çıkar; düzelince liste gelir', (tester) async {
      fields.failList = true;
      await tester.pumpWidget(_app(overrides()));
      await _open(tester);
      expect(find.byKey(const Key('alanlar_hata')), findsOneWidget);
      expect(find.text('Alanlar yüklenemedi.'), findsOneWidget);

      fields.failList = false;
      await _tap(tester, 'alanlar_tekrar');
      expect(find.byKey(const Key('alanlar_hata')), findsNothing);
      expect(find.text('Kafein'), findsOneWidget);
    });
  });

  group('alan ekleme', () {
    testWidgets('kendi sayı alanı eklenir, listede birim ve aralıkla görünür, açık başlar', (tester) async {
      await tester.pumpWidget(_app(overrides()));
      await _open(tester);

      await _tap(tester, 'alan_ekle');
      await _type(tester, 'alan_ad', '  Yürüyüş ');
      await _type(tester, 'alan_birim', 'km');
      await _type(tester, 'alan_min', '0');
      await _type(tester, 'alan_max', '50,5');
      await _tap(tester, 'alan_kaydet');

      expect(find.byKey(const Key('alan_kaydet')), findsNothing); // pencere kapandı
      expect(find.text('Alan kaydedildi'), findsOneWidget);
      expect(find.text('Yürüyüş'), findsOneWidget);
      expect(find.text('Sayı · 0–50.5 km'), findsOneWidget);

      final f = (await all(tester)).firstWhere((x) => x.name == 'Yürüyüş');
      expect((f.unit, f.minValue, f.maxValue, f.isActive), ('km', 0.0, 50.5, true));
      expect(_switchOn(tester, f.id), isTrue);
    });

    testWidgets('ölçek seçilince birim ve sınır alanları kalkar; 1–5 olarak kaydedilir', (tester) async {
      await tester.pumpWidget(_app(overrides()));
      await _open(tester);

      await _tap(tester, 'alan_ekle');
      expect(find.byKey(const Key('alan_birim')), findsOneWidget);
      await _tap(tester, 'alan_tur');
      await tester.tap(find.text('1–5 ölçek').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('alan_birim')), findsNothing);
      expect(find.byKey(const Key('alan_min')), findsNothing);

      await _type(tester, 'alan_ad', 'Stres');
      await _tap(tester, 'alan_kaydet');

      final f = (await all(tester)).firstWhere((x) => x.name == 'Stres');
      expect((f.kind, f.minValue, f.maxValue), (DailyFieldKinds.scale, 1.0, 5.0));
    });

    testWidgets('boş ad, aynı ad ve bozuk sınır uyarı verir; pencere açık kalır', (tester) async {
      await tester.pumpWidget(_app(overrides()));
      await _open(tester);

      await _tap(tester, 'alan_ekle');
      await _tap(tester, 'alan_kaydet');
      expect(find.text('Alan adı boş olamaz.'), findsOneWidget);

      await _type(tester, 'alan_ad', 'kafein'); // hazır "Kafein" ile aynı (büyük/küçük harf farkı)
      await _tap(tester, 'alan_kaydet');
      expect(find.text('Bu adda bir alan zaten var.'), findsOneWidget);

      await _type(tester, 'alan_ad', 'Çay');
      await _type(tester, 'alan_min', '5');
      await _type(tester, 'alan_max', '5');
      await _tap(tester, 'alan_kaydet');
      expect(find.text('En az değer, en çok değerden küçük olmalı.'), findsOneWidget);

      await _type(tester, 'alan_min', 'x');
      await _tap(tester, 'alan_kaydet');
      expect(find.text('En az değer, en çok değerden küçük olmalı.'), findsOneWidget);

      expect(find.byKey(const Key('alan_kaydet')), findsOneWidget);
      expect((await all(tester)).any((f) => f.name == 'Çay'), isFalse);
    });

    testWidgets('vazgeçilirse hiçbir şey eklenmez', (tester) async {
      await tester.pumpWidget(_app(overrides()));
      await _open(tester);
      await _tap(tester, 'alan_ekle');
      await _type(tester, 'alan_ad', 'Çay');
      await _tap(tester, 'alan_vazgec');
      expect(find.text('Çay'), findsNothing);
      expect((await all(tester)).any((f) => f.name == 'Çay'), isFalse);
    });
  });

  group('alan düzenleme', () {
    testWidgets('kendi alanı düzenlenir: ad, birim ve sınır değişir; tür seçici yoktur', (tester) async {
      final f = (await tester.runAsync(() => service.create(
            name: 'Adım', kind: DailyFieldKinds.number, unit: 'adet', min: 0, max: 20000,
          )))!;
      await tester.pumpWidget(_app(overrides()));
      await _open(tester);

      await _tap(tester, 'alan_duzenle_${f.id}');
      expect(find.byKey(const Key('alan_tur')), findsNothing);
      expect(find.text('Alanı düzenle'), findsWidgets);
      await _type(tester, 'alan_ad', 'Yürüyüş');
      await _type(tester, 'alan_max', '30');
      await _tap(tester, 'alan_kaydet');

      expect(find.text('Yürüyüş'), findsOneWidget);
      expect(find.text('Adım'), findsNothing);
      final updated = (await all(tester)).firstWhere((x) => x.id == f.id);
      expect((updated.name, updated.maxValue, updated.unit), ('Yürüyüş', 30.0, 'adet'));
    });

    testWidgets('düzenlerken başka alanın adı verilirse uyarı çıkar', (tester) async {
      await tester.runAsync(() => service.create(name: 'Çay', kind: DailyFieldKinds.number));
      final f = (await tester.runAsync(() => service.create(name: 'Kahve', kind: DailyFieldKinds.number)))!;
      await tester.pumpWidget(_app(overrides()));
      await _open(tester);

      await _tap(tester, 'alan_duzenle_${f.id}');
      await _type(tester, 'alan_ad', 'çay');
      await _tap(tester, 'alan_kaydet');
      expect(find.text('Bu adda bir alan zaten var.'), findsOneWidget);
      expect((await all(tester)).firstWhere((x) => x.id == f.id).name, 'Kahve');
    });

    testWidgets('kaydedilemezse genel uyarı çıkar, pencere açık kalır', (tester) async {
      final f = (await tester.runAsync(() => service.create(name: 'Çay', kind: DailyFieldKinds.number)))!;
      await tester.pumpWidget(_app(overrides()));
      await _open(tester);

      await _tap(tester, 'alan_duzenle_${f.id}');
      await _type(tester, 'alan_ad', 'Çaylar');
      fields.failUpdate = true;
      await _tap(tester, 'alan_kaydet');
      expect(find.text('Kaydedilemedi, tekrar deneyin.'), findsOneWidget);
      expect(find.byKey(const Key('alan_kaydet')), findsOneWidget);
    });
  });
}
