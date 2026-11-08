// Günlük ekranındaki "Ek alanlar" bölümü: gösterim, yazma, silme, doğrulama,
// hata yolları ve alan yönetimine gidip dönme. Gerçek (bellek içi) veritabanı.

import 'package:drift/drift.dart' hide isNotNull, isNull;
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
import 'package:mobile/features/health/screens/daily_log_screen.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../data/test_support.dart';

/// "Bugün" = '2026-11-06'.
DateTime _now() => DateTime(2026, 11, 6, 10, 30);
const _today = '2026-11-06';

class _FailingAddRepository extends DriftMeasurementRepository {
  _FailingAddRepository(super.db);

  @override
  Future<Measurement> add({
    required String type,
    required double value,
    required DateTime measuredAt,
    String unit = '',
    String? notes,
  }) =>
      throw StateError('yazılamadı');
}

/// Alan listesini okuyamayan depo: ek alanlar yüklenemez.
class _BrokenFieldRepository extends DriftDailyFieldRepository {
  _BrokenFieldRepository(super.db);

  @override
  Future<List<DailyField>> listAll() => throw StateError('okunamadı');
}

Widget _app(List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routes: {'/daily-fields': (_) => const DailyFieldsScreen()},
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const DailyLogScreen()),
              ),
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    );

void _phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _open(WidgetTester tester) async {
  _phoneSize(tester);
  await tester.tap(find.text('aç'));
  await tester.pumpAndSettle();
}

Future<void> _fillCore(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).at(0), '7');
  await tester.enterText(find.byType(TextField).at(1), '2');
}

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Kaydet'));
  await tester.tap(find.text('Kaydet'));
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, Key key) =>
    tester.widget<TextField>(find.byKey(key)).controller!.text;

void main() {
  late AppDatabase db;
  late DailyFieldService service;

  setUp(() {
    db = createTestDb();
    service = DailyFieldService(
      fields: DriftDailyFieldRepository(db),
      measurements: DriftMeasurementRepository(db),
      clock: _now,
      transactor: db.transaction,
    );
  });
  tearDown(() => db.close());

  List<Override> overrides() => [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(_now),
      ];

  Future<List<Measurement>> live(WidgetTester tester, String type) =>
      tester.runAsync(() => (db.select(db.measurements)
            ..where((t) => t.deletedAt.isNull() & t.type.equals(type)))
          .get())
      .then((v) => v!);

  Future<List<Measurement>> everything(WidgetTester tester, String type) =>
      tester.runAsync(() =>
              (db.select(db.measurements)..where((t) => t.type.equals(type)))
                  .get())
          .then((v) => v!);

  Future<DailyField> custom(
    WidgetTester tester,
    String name, {
    String kind = DailyFieldKinds.number,
    String unit = '',
    double? min,
    double? max,
  }) =>
      tester
          .runAsync(() => service.create(
              name: name, kind: kind, unit: unit, min: min, max: max))
          .then((v) => v!);

  Key inputKey(DailyField f) => Key('ek_alan_${f.id}');
  String typeOf(DailyField f) => '${MeasurementTypes.customFieldPrefix}${f.id}';

  group('gösterim', () {
    testWidgets('açık alan yokken bölüm, boş açıklama ve düzenle düğmesi görünür; mevcut alan sırası değişmez',
        (tester) async {
      await tester.pumpWidget(_app(overrides()));
      await _open(tester);

      expect(find.text('Ek alanlar'), findsOneWidget);
      expect(find.byKey(const Key('ek_alan_bos')), findsOneWidget);
      expect(find.byKey(const Key('gunluk_alanlari_duzenle')), findsOneWidget);
      // Uyku, su, not: yalnız üç metin alanı.
      expect(find.byType(TextField), findsNWidgets(3));
      // Hazır alanlar (kapalı) eklenmiş olmalı.
      final all = await tester.runAsync(service.list);
      expect(all!.map((f) => f.builtinKey), [
        MeasurementTypes.caffeine,
        MeasurementTypes.exercise,
        MeasurementTypes.pain,
        MeasurementTypes.steps,
      ]);
    });

    testWidgets('açık sayı alanı etiketi birimi taşır, ipucu aralığı gösterir; kapalı alan görünmez', (tester) async {
      final f = await custom(tester, 'Çay', unit: 'bardak', min: 0, max: 20);
      await custom(tester, 'Gizli');
      final hidden = (await tester.runAsync(service.list))!.firstWhere((x) => x.name == 'Gizli');
      await tester.runAsync(() => service.setActive(hidden.id, false));

      await tester.pumpWidget(_app(overrides()));
      await _open(tester);

      expect(find.text('Çay (bardak)'), findsOneWidget);
      expect(find.byKey(inputKey(f)), findsOneWidget);
      expect(find.text('0–20'), findsOneWidget);
      expect(find.text('Gizli'), findsNothing);
    });

    testWidgets('bugünün kayıtlı değeri alanda dolu gelir', (tester) async {
      final f = await custom(tester, 'Çay', max: 20);
      await tester.runAsync(() => service.setValue(f.id, _today, 2.5));

      await tester.pumpWidget(_app(overrides()));
      await _open(tester);

      expect(_text(tester, inputKey(f)), '2,5');
    });
  });

  group('kaydetme', () {
    testWidgets('sayı alanı yazılır; günlük kayıt da kaydedilir; ekran kapanır', (tester) async {
      final f = await custom(tester, 'Çay', unit: 'bardak', max: 20);
      await tester.pumpWidget(_app(overrides()));
      await _open(tester);

      await _fillCore(tester);
      await tester.enterText(find.byKey(inputKey(f)), '3');
      await _save(tester);

      expect(find.byType(DailyLogScreen), findsNothing);
      final rows = await live(tester, typeOf(f));
      expect(rows.single.value, 3);
      expect(rows.single.logDate, _today);
      expect((await tester.runAsync(() => db.select(db.dailyLogs).get()))!, hasLength(1));
    });

    testWidgets('ölçek ve evet/hayır seçilir; seçili değere yeniden dokunmak kaldırır', (tester) async {
      final s = await custom(tester, 'Stres', kind: DailyFieldKinds.scale);
      final y = await custom(tester, 'Spor yaptım', kind: DailyFieldKinds.yesNo);
      await tester.pumpWidget(_app(overrides()));
      await _open(tester);

      await tester.tap(find.byKey(Key('ek_alan_${s.id}_4')));
      await tester.pump();
      await tester.tap(find.byKey(Key('ek_alan_${y.id}_evet')));
      await tester.pump();
      // Yanlış seçip geri alma: hayır'a, sonra yeniden hayır'a dokun.
      await tester.tap(find.byKey(Key('ek_alan_${y.id}_hayir')));
      await tester.pump();
      await tester.tap(find.byKey(Key('ek_alan_${y.id}_hayir')));
      await tester.pump();

      await _fillCore(tester);
      await _save(tester);

      expect((await live(tester, typeOf(s))).single.value, 4);
      expect(await live(tester, typeOf(y)), isEmpty); // seçim kaldırıldı
    });

    testWidgets('evet/hayır "hayır" seçilince 0 yazılır', (tester) async {
      final y = await custom(tester, 'Spor yaptım', kind: DailyFieldKinds.yesNo);
      await tester.pumpWidget(_app(overrides()));
      await _open(tester);
      await tester.tap(find.byKey(Key('ek_alan_${y.id}_hayir')));
      await tester.pump();
      await _fillCore(tester);
      await _save(tester);
      expect((await live(tester, typeOf(y))).single.value, 0);
    });

    testWidgets('alan boşaltılırsa o günün değeri silinir; değişmeyen alana yeniden yazılmaz', (tester) async {
      final a = await custom(tester, 'Çay', max: 20);
      final b = await custom(tester, 'Kahve', max: 20);
      await tester.runAsync(() => service.setValue(a.id, _today, 2));
      await tester.runAsync(() => service.setValue(b.id, _today, 1));

      await tester.pumpWidget(_app(overrides()));
      await _open(tester);
      await _fillCore(tester);
      await tester.enterText(find.byKey(inputKey(a)), '');
      await _save(tester);

      expect(await live(tester, typeOf(a)), isEmpty);
      // Kahve'ye dokunulmadı: tek satır, silinmiş satır yok.
      expect(await everything(tester, typeOf(b)), hasLength(1));
      expect((await live(tester, typeOf(b))).single.value, 1);
    });

    testWidgets('ek alana dokunulmadan kaydedince hiçbir ölçüm satırı eklenmez', (tester) async {
      final f = await custom(tester, 'Çay', max: 20);
      await tester.pumpWidget(_app(overrides()));
      await _open(tester);
      await _fillCore(tester);
      await _save(tester);
      expect(await everything(tester, typeOf(f)), isEmpty);
    });
  });

  group('doğrulama ve hatalar', () {
    testWidgets('sınır dışı ya da okunamayan değerde uyarı çıkar; hiçbir şey kaydedilmez', (tester) async {
      final f = await custom(tester, 'Çay', min: 0, max: 20);
      await tester.pumpWidget(_app(overrides()));
      await _open(tester);
      await _fillCore(tester);

      await tester.enterText(find.byKey(inputKey(f)), '25');
      await _save(tester);
      expect(find.text('Çay için geçerli bir değer girin (0–20).'), findsOneWidget);
      expect(find.byType(DailyLogScreen), findsOneWidget);

      await tester.enterText(find.byKey(inputKey(f)), 'abc');
      await _save(tester);
      expect(find.text('Çay için geçerli bir değer girin (0–20).'), findsOneWidget);

      expect(await tester.runAsync(() => db.select(db.dailyLogs).get()), isEmpty);
      expect(await everything(tester, typeOf(f)), isEmpty);
    });

    testWidgets('ek alanlar yazılamazsa günlük kaydı yine de yazılır, uyarı çıkar, ekran açık kalır', (tester) async {
      await custom(tester, 'Çay', max: 20);
      final failing = DailyFieldService(
        fields: DriftDailyFieldRepository(db),
        measurements: _FailingAddRepository(db),
        clock: _now,
        transactor: db.transaction,
      );
      await tester.pumpWidget(_app([
        ...overrides(),
        dailyFieldServiceProvider.overrideWithValue(failing),
      ]));
      await _open(tester);
      await _fillCore(tester);
      final f = (await tester.runAsync(service.list))!.firstWhere((x) => x.name == 'Çay');
      await tester.enterText(find.byKey(inputKey(f)), '3');
      await _save(tester);

      expect(find.text('Günlük kaydedildi ama ek alanlar kaydedilemedi. Tekrar deneyin.'), findsOneWidget);
      expect(find.byType(DailyLogScreen), findsOneWidget);
      expect((await tester.runAsync(() => db.select(db.dailyLogs).get()))!, hasLength(1));
      expect(_text(tester, inputKey(f)), '3'); // yazılan korunur
    });

    testWidgets('ek alanlar yüklenemezse bölüm görünmez; günlük kaydı çalışır', (tester) async {
      final broken = DailyFieldService(
        fields: _BrokenFieldRepository(db),
        measurements: DriftMeasurementRepository(db),
        clock: _now,
      );
      await tester.pumpWidget(_app([
        ...overrides(),
        dailyFieldServiceProvider.overrideWithValue(broken),
      ]));
      await _open(tester);

      expect(find.text('Ek alanlar'), findsNothing);
      await _fillCore(tester);
      await _save(tester);
      expect(find.byType(DailyLogScreen), findsNothing);
      expect((await tester.runAsync(() => db.select(db.dailyLogs).get()))!, hasLength(1));
    });
  });

  group('alan yönetimine gidip dönme', () {
    testWidgets('yönetimden dönünce açılan alan günlükte görünür; yazılan uyku değeri korunur', (tester) async {
      await tester.pumpWidget(_app(overrides()));
      await _open(tester);
      await tester.enterText(find.byType(TextField).at(0), '6');

      await tester.ensureVisible(find.byKey(const Key('gunluk_alanlari_duzenle')));
      await tester.tap(find.byKey(const Key('gunluk_alanlari_duzenle')));
      await tester.pumpAndSettle();
      expect(find.byType(DailyFieldsScreen), findsOneWidget);

      final caffeine = (await tester.runAsync(service.list))!
          .firstWhere((f) => f.builtinKey == MeasurementTypes.caffeine);
      await tester.tap(find.byKey(Key('alan_ac_${caffeine.id}')));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(DailyLogScreen), findsOneWidget);
      expect(find.byKey(inputKey(caffeine)), findsOneWidget);
      expect(find.text('Kafein (bardak)'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text, '6');
    });

    testWidgets('yönetimden dönünce ek alana yazılan değer korunur; kapatılan alan listeden kalkar', (tester) async {
      final tea = await custom(tester, 'Çay', max: 20);
      final coffee = await custom(tester, 'Kahve', max: 20);
      await tester.pumpWidget(_app(overrides()));
      await _open(tester);
      await tester.enterText(find.byKey(inputKey(tea)), '4');
      await tester.enterText(find.byKey(inputKey(coffee)), '2');

      await tester.ensureVisible(find.byKey(const Key('gunluk_alanlari_duzenle')));
      await tester.tap(find.byKey(const Key('gunluk_alanlari_duzenle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('alan_ac_${coffee.id}'))); // Kahve kapatılır
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(_text(tester, inputKey(tea)), '4');
      expect(find.byKey(inputKey(coffee)), findsNothing);

      // Kapatılan alanın yazılmamış değeri kaydedilmez.
      await _fillCore(tester);
      await _save(tester);
      expect((await live(tester, typeOf(tea))).single.value, 4);
      expect(await everything(tester, typeOf(coffee)), isEmpty);
    });
  });
}
