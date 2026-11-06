import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/repositories/daily_log_repository.dart';
import 'package:mobile/features/health/screens/daily_log_screen.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../data/test_support.dart';

/// Yerel 6 Kasım 2026, öğleden önce; "bugün" = '2026-11-06'.
DateTime _now() => DateTime(2026, 11, 6, 10, 30);

/// Okuma her zaman hata verir; ekranın hata yolunu denemek için.
class _FailingDailyLogRepository implements DailyLogRepository {
  @override
  Future<DailyLog?> getByDate(String logDate) async =>
      throw StateError('okunamadı');

  @override
  Future<DailyLog> upsert({
    required String logDate,
    required double sleepHours,
    required double waterIntake,
    required int mood,
    required int energyLevel,
    String? notes,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<DailyLog>> listInRange(String fromDate, String toDate) =>
      throw UnimplementedError();

  @override
  Future<void> softDelete(String id) => throw UnimplementedError();
}

Widget _app(List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const DailyLogScreen(),
      ),
    );

/// Okuma boş döner, yazma hata verir; kaydetme hata yolunu denemek için.
class _SaveFailsRepository extends _FailingDailyLogRepository {
  @override
  Future<DailyLog?> getByDate(String logDate) async => null;

  @override
  Future<DailyLog> upsert({
    required String logDate,
    required double sleepHours,
    required double waterIntake,
    required int mood,
    required int energyLevel,
    String? notes,
  }) async =>
      throw StateError('yazılamadı');
}

/// Ekranı bir ana ekranın üstüne açar; kaydedince geri dönüşü de görülür.
Widget _hosted(List<Override> overrides) => ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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

/// Uzun ekran: form kaydırmadan sığar, "Kaydet" her zaman dokunulabilir.
/// Genişlik bilerek geniş: flutter_test'in Ahem yazı tipi gerçek yazıdan çok
/// geniş çizilir, dar ekranda düzen taşması (bu testlerle ilgisiz) çıkar.
void _phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _openScreen(WidgetTester tester) async {
  _phoneSize(tester);
  await tester.tap(find.text('aç'));
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, int field, String text) =>
    tester.enterText(find.byType(TextField).at(field), text);

Future<void> _tapSave(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Kaydet'));
  await tester.tap(find.text('Kaydet'));
  await tester.pumpAndSettle();
}

String _fieldText(WidgetTester tester, int index) =>
    tester.widget<TextField>(find.byType(TextField).at(index)).controller!.text;

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDb());
  tearDown(() => db.close());

  List<Override> overrides() => [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(_now),
      ];

  group('DailyLogScreen / bugünün kaydını okuma', () {
    testWidgets('kayıt yoksa alanlar boş, başlık "Günlük Kayıt"', (tester) async {
      await tester.pumpWidget(_app(overrides()));
      await tester.pumpAndSettle();

      expect(find.text('Günlük Kayıt'), findsOneWidget);
      expect(_fieldText(tester, 0), isEmpty); // uyku
      expect(_fieldText(tester, 1), isEmpty); // su
      expect(_fieldText(tester, 2), isEmpty); // notlar
      expect(find.text('3 / 5'), findsNWidgets(2)); // ruh hali + enerji varsayılanı
    });

    testWidgets('bugün için kayıt varsa önceki değerler dolu gelir',
        (tester) async {
      await tester.runAsync(() => DriftDailyLogRepository(db).upsert(
            logDate: '2026-11-06',
            sleepHours: 7.5,
            waterIntake: 2,
            mood: 4,
            energyLevel: 2,
            notes: 'baş ağrısı yoktu',
          ));

      await tester.pumpWidget(_app(overrides()));
      await tester.runAsync(() => Future<void>.delayed(
            const Duration(milliseconds: 50),
          ));
      await tester.pumpAndSettle();

      expect(find.text('Kaydı Güncelle'), findsOneWidget);
      expect(_fieldText(tester, 0), '7,5'); // yerel ondalık ayracı, "7.5" değil
      expect(_fieldText(tester, 1), '2'); // 2.0 değil
      expect(_fieldText(tester, 2), 'baş ağrısı yoktu');
      expect(find.text('4 / 5'), findsOneWidget); // ruh hali
      expect(find.text('2 / 5'), findsOneWidget); // enerji
    });

    testWidgets('ondalık değer yuvarlanmadan, yerel ayraçla gösterilir',
        (tester) async {
      await tester.runAsync(() => DriftDailyLogRepository(db).upsert(
            logDate: '2026-11-06',
            sleepHours: 7.25,
            waterIntake: 1.1234,
            mood: 3,
            energyLevel: 3,
          ));

      await tester.pumpWidget(_app(overrides()));
      await tester.runAsync(() => Future<void>.delayed(
            const Duration(milliseconds: 50),
          ));
      await tester.pumpAndSettle();

      expect(_fieldText(tester, 0), '7,25');
      expect(_fieldText(tester, 1), '1,1234'); // 1,123 olmamalı (veri kaybı)
    });

    testWidgets('başka güne ait kayıt bugün için gösterilmez', (tester) async {
      await tester.runAsync(() => DriftDailyLogRepository(db).upsert(
            logDate: '2026-11-05',
            sleepHours: 6,
            waterIntake: 1,
            mood: 5,
            energyLevel: 5,
          ));

      await tester.pumpWidget(_app(overrides()));
      await tester.runAsync(() => Future<void>.delayed(
            const Duration(milliseconds: 50),
          ));
      await tester.pumpAndSettle();

      expect(find.text('Günlük Kayıt'), findsOneWidget);
      expect(_fieldText(tester, 0), isEmpty);
      expect(_fieldText(tester, 1), isEmpty);
    });

    testWidgets('okuma hata verirse mesaj çıkar ve Kaydet pasif olur',
        (tester) async {
      await tester.pumpWidget(_app([
        dailyLogRepositoryProvider.overrideWithValue(
          _FailingDailyLogRepository(),
        ),
        clockProvider.overrideWithValue(_now),
      ]));
      await tester.pumpAndSettle();

      expect(find.textContaining('Bugünün kaydı okunamadı'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);

      // Alana yazmak okuma uyarısını silmez: kaydetme kapalıyken uyarı gerekli.
      await _enter(tester, 0, '7');
      await tester.pump();
      expect(find.textContaining('Bugünün kaydı okunamadı'), findsOneWidget);
    });
  });

  group('DailyLogScreen / kaydetme', () {
    Future<List<DailyLog>> allLogs(WidgetTester tester) =>
        tester.runAsync(() => DriftDailyLogRepository(db)
            .listInRange('2000-01-01', '2100-01-01'))
        .then((v) => v!);

    testWidgets(
        'yeni kayıt: ondalık virgül kabul edilir, bugüne yazılır, ekran kapanır',
        (tester) async {
      await tester.pumpWidget(_hosted(overrides()));
      await _openScreen(tester);

      await _enter(tester, 0, '7,5');
      await _enter(tester, 1, '2');
      await _tapSave(tester);

      final logs = await allLogs(tester);
      expect(logs, hasLength(1));
      expect(logs.single.logDate, '2026-11-06');
      expect(logs.single.sleepHours, 7.5);
      expect(logs.single.waterIntake, 2);
      expect(logs.single.mood, 3); // varsayılan seçim
      expect(logs.single.energyLevel, 3);
      expect(logs.single.notes, isNull); // boş not null saklanır
      // Ekran kapandı, başarı mesajı çıktı.
      expect(find.text('Günlük Kayıt'), findsNothing);
      expect(find.text('Günlük kayıt kaydedildi'), findsOneWidget);
    });

    testWidgets('boş uyku veya su reddedilir, hiçbir şey yazılmaz',
        (tester) async {
      await tester.pumpWidget(_hosted(overrides()));
      await _openScreen(tester);

      await _tapSave(tester); // ikisi de boş
      expect(find.textContaining('Uyku süresini'), findsOneWidget);

      await _enter(tester, 0, '7');
      await _tapSave(tester); // su boş
      expect(find.textContaining('Su tüketimini'), findsOneWidget);

      expect(await allLogs(tester), isEmpty);
      expect(find.text('Günlük Kayıt'), findsOneWidget); // ekran açık kaldı
    });

    testWidgets('doğrulama uyarısı, alan düzeltilmeye başlanınca kalkar',
        (tester) async {
      await tester.pumpWidget(_hosted(overrides()));
      await _openScreen(tester);

      await _tapSave(tester); // ikisi de boş
      expect(find.textContaining('Uyku süresini'), findsOneWidget);
      await _enter(tester, 0, '7');
      await tester.pump();
      expect(find.textContaining('Uyku süresini'), findsNothing);

      await _tapSave(tester); // su boş
      expect(find.textContaining('Su tüketimini'), findsOneWidget);
      await _enter(tester, 1, '2');
      await tester.pump();
      expect(find.textContaining('Su tüketimini'), findsNothing);

      expect(await allLogs(tester), isEmpty); // düzeltilene kadar yazılmadı
    });

    testWidgets('sınır dışı değerler reddedilir (uyku 0-24, su 0-10)',
        (tester) async {
      await tester.pumpWidget(_hosted(overrides()));
      await _openScreen(tester);

      for (final bad in ['25', '-1', 'abc']) {
        await _enter(tester, 0, bad);
        await _enter(tester, 1, '2');
        await _tapSave(tester);
        expect(find.textContaining('Uyku süresini'), findsOneWidget,
            reason: 'uyku "$bad" reddedilmeli');
      }
      for (final bad in ['11', '-0,5']) {
        await _enter(tester, 0, '8');
        await _enter(tester, 1, bad);
        await _tapSave(tester);
        expect(find.textContaining('Su tüketimini'), findsOneWidget,
            reason: 'su "$bad" reddedilmeli');
      }
      expect(await allLogs(tester), isEmpty);

      // Sınır değerlerin kendisi geçerlidir.
      await _enter(tester, 0, '24');
      await _enter(tester, 1, '10');
      await _tapSave(tester);
      final logs = await allLogs(tester);
      expect(logs, hasLength(1));
      expect(logs.single.sleepHours, 24);
      expect(logs.single.waterIntake, 10);
    });

    testWidgets(
        'gün içi ikinci kayıt: önceki değerler dolu gelir, kayıt güncellenir, '
        'yeni satır açılmaz', (tester) async {
      final first = (await tester.runAsync(() => DriftDailyLogRepository(db)
          .upsert(
            logDate: '2026-11-06',
            sleepHours: 6,
            waterIntake: 1,
            mood: 2,
            energyLevel: 2,
            notes: 'sabah',
          )))!;

      await tester.pumpWidget(_hosted(overrides()));
      await _openScreen(tester);
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();

      expect(_fieldText(tester, 0), '6');
      expect(_fieldText(tester, 1), '1');
      expect(_fieldText(tester, 2), 'sabah');

      await _enter(tester, 1, '2,5'); // su üzerine yazılır, toplanmaz
      await _enter(tester, 2, 'sabah ve öğle');
      await _tapSave(tester);

      final logs = await allLogs(tester);
      expect(logs, hasLength(1));
      expect(logs.single.id, first.id);
      expect(logs.single.sleepHours, 6); // dokunulmayan alan korunur
      expect(logs.single.waterIntake, 2.5);
      expect(logs.single.mood, 2);
      expect(logs.single.notes, 'sabah ve öğle');
      expect(find.text('Günlük kayıt güncellendi'), findsOneWidget);
    });

    testWidgets('yazma hata verirse mesaj çıkar, ekran ve değerler korunur',
        (tester) async {
      await tester.pumpWidget(_hosted([
        dailyLogRepositoryProvider.overrideWithValue(_SaveFailsRepository()),
        clockProvider.overrideWithValue(_now),
      ]));
      await _openScreen(tester);

      await _enter(tester, 0, '7');
      await _enter(tester, 1, '2');
      await _tapSave(tester);

      expect(find.textContaining('Kayıt kaydedilemedi'), findsOneWidget);
      expect(find.text('Günlük Kayıt'), findsOneWidget);
      expect(_fieldText(tester, 0), '7');
      expect(_fieldText(tester, 1), '2');
      // Tekrar denenebilir: düğme pasif kalmadı.
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNotNull);
    });
  });
}
