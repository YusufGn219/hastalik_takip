import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/database/enums.dart';
import 'package:mobile/features/profile/body_measurements_screen.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../support/fake_measurement_repository.dart';

/// "Şimdi": yerel 8 Kasım 2026, 12:00.
DateTime _now() => DateTime(2026, 11, 8, 12);

Future<void> _open(WidgetTester tester, FakeMeasurementRepository repo) async {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      measurementRepositoryProvider.overrideWithValue(repo),
      clockProvider.overrideWithValue(_now),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const BodyMeasurementsScreen(),
    ),
  ));
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

String _fieldText(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

void main() {
  test('grafik noktaları eskiden yeniye dizilir ve en çok 60 kayıt alır', () {
    final repo = FakeMeasurementRepository();
    // 70 kayıt; en yeni önce (gün 70 ... gün 1).
    final newestFirst = [
      for (var i = 70; i >= 1; i--)
        repo.seed(MeasurementTypes.weight, 50 + i.toDouble(), DateTime(2026, 1, 1).add(Duration(days: i)))
    ];
    final series = chartSeries(newestFirst);
    expect(series, hasLength(60));
    expect(series.first.value, 61, reason: 'en eski gösterilen: 60. en yeni');
    expect(series.last.value, 120, reason: 'en yeni son noktada');
    expect(chartSeries(newestFirst.take(2).toList()).map((m) => m.value), [119, 120]);
  });

  testWidgets('ölçüm yokken: boş alanlar, grafik ve geçmiş için ipucu', (tester) async {
    await _open(tester, FakeMeasurementRepository());
    expect(_fieldText(tester, 'vucut_boy'), '');
    expect(_fieldText(tester, 'vucut_kilo'), '');
    expect(find.text('Bugün'), findsOneWidget);
    expect(find.byKey(const Key('vucut_grafik_bos')), findsOneWidget);
    expect(find.byKey(const Key('vucut_gecmis_bos')), findsOneWidget);
    expect(find.byKey(const Key('vucut_grafik')), findsNothing);
  });

  testWidgets('güncel boy alana yüklenir (tam sayı ondalıksız)', (tester) async {
    final repo = FakeMeasurementRepository()..seed(MeasurementTypes.height, 175, _now());
    await _open(tester, repo);
    expect(_fieldText(tester, 'vucut_boy'), '175');
  });

  testWidgets('boy: virgüllü değer kaydedilir, bildirim çıkar', (tester) async {
    final repo = FakeMeasurementRepository();
    await _open(tester, repo);
    await _type(tester, 'vucut_boy', '176,5');
    await _tap(tester, 'vucut_boy_kaydet');
    expect(repo.rows.single.value, 176.5);
    expect(repo.rows.single.type, MeasurementTypes.height);
    expect(find.text('Boy kaydedildi'), findsOneWidget);
  });

  testWidgets('boy: sayı değil ya da aralık dışı değer uyarı verir, yazılmaz', (tester) async {
    final repo = FakeMeasurementRepository();
    await _open(tester, repo);
    await _type(tester, 'vucut_boy', 'abc');
    await _tap(tester, 'vucut_boy_kaydet');
    expect(find.text('Geçerli bir sayı girin.'), findsOneWidget);

    await _type(tester, 'vucut_boy', '300');
    expect(find.text('Geçerli bir sayı girin.'), findsNothing, reason: 'yazınca uyarı kalkar');
    await _tap(tester, 'vucut_boy_kaydet');
    expect(find.text('Boyu 50 ile 250 cm arasında girin.'), findsOneWidget);
    expect(repo.rows, isEmpty);
  });

  testWidgets('kilo: eklenir, geçmişte görünür, alan temizlenir', (tester) async {
    final repo = FakeMeasurementRepository();
    await _open(tester, repo);
    await _type(tester, 'vucut_kilo', '72,5');
    await _tap(tester, 'vucut_kilo_ekle');

    expect(repo.rows.single.value, 72.5);
    expect(repo.rows.single.type, MeasurementTypes.weight);
    expect(find.text('72,5 kg'), findsOneWidget);
    expect(find.text('8 Kasım 2026'), findsOneWidget);
    expect(find.text('Kilo kaydedildi'), findsOneWidget);
    expect(_fieldText(tester, 'vucut_kilo'), '');
    expect(find.byKey(const Key('vucut_gecmis_bos')), findsNothing);
  });

  testWidgets('kilo: geçmiş bir gün seçilince o günün kaydı olur; sonra tarih "Bugün"e döner',
      (tester) async {
    final repo = FakeMeasurementRepository();
    await _open(tester, repo);
    await _tap(tester, 'vucut_tarih');
    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tamam'));
    await tester.pumpAndSettle();
    expect(find.text('3 Kasım 2026'), findsOneWidget);

    await _type(tester, 'vucut_kilo', '70');
    await _tap(tester, 'vucut_kilo_ekle');
    expect(repo.rows.single.logDate, '2026-11-03');
    expect(find.text('3 Kasım 2026'), findsOneWidget, reason: 'geçmişte listelenir');
    expect(find.text('Bugün'), findsOneWidget, reason: 'seçim sıfırlanır');
  });

  testWidgets('kilo: boş, sayı değil ya da aralık dışı değer yazılmaz', (tester) async {
    final repo = FakeMeasurementRepository();
    await _open(tester, repo);
    await _tap(tester, 'vucut_kilo_ekle');
    expect(find.text('Geçerli bir sayı girin.'), findsOneWidget);

    await _type(tester, 'vucut_kilo', '1');
    await _tap(tester, 'vucut_kilo_ekle');
    expect(find.text('Kiloyu 2 ile 500 kg arasında girin.'), findsOneWidget);
    expect(repo.rows, isEmpty);
  });

  testWidgets('grafik en az iki kilo kaydıyla görünür', (tester) async {
    final repo = FakeMeasurementRepository()..seed(MeasurementTypes.weight, 71, DateTime(2026, 10, 1, 12));
    await _open(tester, repo);
    expect(find.byKey(const Key('vucut_grafik')), findsNothing);
    expect(find.byKey(const Key('vucut_grafik_bos')), findsOneWidget);

    await _type(tester, 'vucut_kilo', '72');
    await _tap(tester, 'vucut_kilo_ekle');
    expect(find.byKey(const Key('vucut_grafik')), findsOneWidget);
    expect(find.byKey(const Key('vucut_grafik_bos')), findsNothing);
  });

  testWidgets('geçmiş en yeni önce sıralanır', (tester) async {
    final repo = FakeMeasurementRepository()
      ..seed(MeasurementTypes.weight, 71, DateTime(2026, 10, 1, 12))
      ..seed(MeasurementTypes.weight, 73, DateTime(2026, 10, 20, 12))
      ..seed(MeasurementTypes.weight, 72, DateTime(2026, 10, 10, 12));
    await _open(tester, repo);
    final y73 = tester.getTopLeft(find.text('73 kg')).dy;
    final y72 = tester.getTopLeft(find.text('72 kg')).dy;
    final y71 = tester.getTopLeft(find.text('71 kg')).dy;
    expect(y73 < y72 && y72 < y71, isTrue);
  });

  testWidgets('silme: vazgeçilirse kalır, onaylanırsa gider; boy etkilenmez', (tester) async {
    final repo = FakeMeasurementRepository()..seed(MeasurementTypes.height, 175, _now());
    final a = repo.seed(MeasurementTypes.weight, 71, DateTime(2026, 10, 1, 12));
    repo.seed(MeasurementTypes.weight, 72, DateTime(2026, 10, 2, 12));
    await _open(tester, repo);

    await _tap(tester, 'vucut_sil_${a.id}');
    await tester.tap(find.byKey(const Key('vucut_sil_vazgec')));
    await tester.pumpAndSettle();
    expect(find.text('71 kg'), findsOneWidget);

    await _tap(tester, 'vucut_sil_${a.id}');
    await tester.tap(find.byKey(const Key('vucut_sil_onay')));
    await tester.pumpAndSettle();
    expect(find.text('71 kg'), findsNothing);
    expect(find.text('72 kg'), findsOneWidget);
    expect(find.text('Kayıt silindi'), findsOneWidget);
    expect(_fieldText(tester, 'vucut_boy'), '175');
  });

  testWidgets('silinemezse kayıt yerinde kalır ve uyarı çıkar', (tester) async {
    final repo = FakeMeasurementRepository(failDeletes: true);
    final a = repo.seed(MeasurementTypes.weight, 71, DateTime(2026, 10, 1, 12));
    await _open(tester, repo);
    await _tap(tester, 'vucut_sil_${a.id}');
    await tester.tap(find.byKey(const Key('vucut_sil_onay')));
    await tester.pumpAndSettle();
    expect(find.text('71 kg'), findsOneWidget);
    expect(find.text('Kaydedilemedi.'), findsOneWidget);
  });

  testWidgets('yazılamazsa hata görünür ve girilen değer durur', (tester) async {
    final repo = FakeMeasurementRepository(failAdds: true);
    await _open(tester, repo);
    await _type(tester, 'vucut_kilo', '70');
    await _tap(tester, 'vucut_kilo_ekle');
    expect(find.text('Kaydedilemedi.'), findsOneWidget);
    expect(_fieldText(tester, 'vucut_kilo'), '70');

    await _type(tester, 'vucut_boy', '170');
    await _tap(tester, 'vucut_boy_kaydet');
    expect(find.text('Kaydedilemedi.'), findsNWidgets(2));
  });

  testWidgets('ölçümler okunamazsa yeniden dene düğmesi çıkar', (tester) async {
    final repo = FakeMeasurementRepository(failLoads: 1)
      ..seed(MeasurementTypes.weight, 71, DateTime(2026, 10, 1, 12));
    await _open(tester, repo);
    expect(find.byKey(const Key('vucut_okunamadi')), findsOneWidget);

    await tester.tap(find.byKey(const Key('vucut_tekrar')));
    await tester.pumpAndSettle();
    expect(find.text('71 kg'), findsOneWidget);
  });
}
