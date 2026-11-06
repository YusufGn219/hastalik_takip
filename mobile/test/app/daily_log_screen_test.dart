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
      expect(_fieldText(tester, 0), '7.5');
      expect(_fieldText(tester, 1), '2'); // 2.0 değil
      expect(_fieldText(tester, 2), 'baş ağrısı yoktu');
      expect(find.text('4 / 5'), findsOneWidget); // ruh hali
      expect(find.text('2 / 5'), findsOneWidget); // enerji
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
    });
  });
}
