// Sağlık ölçümleri ekranı: tür seçimi, ekleme, hata metinleri, birim, düzenleme,
// silme, grafik ve okuma hatası. Bellek içi sahte depolarla; AppTheme ile.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/database/enums.dart';
import 'package:mobile/features/readings/readings_screen.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../support/fake_measurement_repository.dart';
import '../support/fake_settings_repository.dart';

/// "Şimdi": yerel 10 Kasım 2026, 12:00.
DateTime _now() => DateTime(2026, 11, 10, 12);

const _bp = MeasurementTypes.bloodPressure;
const _glucose = MeasurementTypes.bloodGlucose;

Future<void> _open(
  WidgetTester tester,
  FakeMeasurementRepository repo, {
  FakeSettingsRepository? settings,
  Size size = const Size(800, 3200),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      measurementRepositoryProvider.overrideWithValue(repo),
      settingsRepositoryProvider.overrideWithValue(settings ?? FakeSettingsRepository()),
      clockProvider.overrideWithValue(_now),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const ReadingsScreen()),
            ),
            child: const Text('aç'),
          ),
        ),
      ),
    ),
  ));
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

String _fieldText(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

String _errorText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('olcum_hata'))).data!;

void main() {
  testWidgets('ölçüm yokken: boş ipucu, uyarı notu, grafik yok; yorum etiketi yok', (tester) async {
    await _open(tester, FakeMeasurementRepository());
    expect(find.byKey(const Key('olcum_bos')), findsOneWidget);
    expect(find.byKey(const Key('olcum_uyari')), findsOneWidget);
    expect(find.text('Bu değerler yalnızca kayıt amaçlıdır; tıbbi tavsiye değildir.'), findsOneWidget);
    expect(find.byKey(const Key('olcum_grafik')), findsNothing);
    expect(find.text('Tansiyon'), findsOneWidget);
    expect(find.text('Nabız'), findsOneWidget);
    expect(find.text('Kan şekeri'), findsOneWidget);
  });

  group('tansiyon ekleme', () {
    testWidgets('iki sayı yazılır; satır, son ölçüm ve bildirim çıkar', (tester) async {
      final repo = FakeMeasurementRepository();
      await _open(tester, repo);
      await _tap(tester, 'olcum_ekle');
      expect(_fieldText(tester, 'olcum_deger'), '');
      expect(find.text('12:00'), findsOneWidget, reason: 'varsayılan an: şimdi');

      await _type(tester, 'olcum_deger', '120');
      await _type(tester, 'olcum_deger2', '80');
      await _tap(tester, 'olcum_kaydet');

      final m = repo.rows.single;
      expect((m.type, m.value, m.value2, m.unit), (_bp, 120.0, 80.0, 'mmHg'));
      expect(m.measuredAt, DateTime(2026, 11, 10, 12));
      expect(find.text('Ölçüm kaydedildi'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('olcum_son_deger'))).data, '120/80 mmHg');
      expect(find.byKey(Key('olcum_kayit_${m.id}')), findsOneWidget);
      expect(find.byKey(const Key('olcum_bos')), findsNothing);
    });

    testWidgets('hatalı girişler açıklayıcı metin verir ve hiçbir şey yazılmaz', (tester) async {
      final repo = FakeMeasurementRepository();
      await _open(tester, repo);
      await _tap(tester, 'olcum_ekle');

      await _tap(tester, 'olcum_kaydet');
      expect(_errorText(tester), 'Geçerli bir sayı girin.');

      await _type(tester, 'olcum_deger', '120');
      expect(find.byKey(const Key('olcum_hata')), findsNothing, reason: 'yazınca uyarı kalkar');
      await _tap(tester, 'olcum_kaydet');
      expect(_errorText(tester), 'Geçerli bir sayı girin.', reason: 'ikinci değer eksik');

      await _type(tester, 'olcum_deger', '300');
      await _type(tester, 'olcum_deger2', '80');
      await _tap(tester, 'olcum_kaydet');
      expect(_errorText(tester), 'Değer 60 ile 260 mmHg arasında olmalı.');

      await _type(tester, 'olcum_deger', '120');
      await _type(tester, 'olcum_deger2', '10');
      await _tap(tester, 'olcum_kaydet');
      expect(_errorText(tester), 'Değer 30 ile 150 mmHg arasında olmalı.');

      await _type(tester, 'olcum_deger', '70');
      await _type(tester, 'olcum_deger2', '90');
      await _tap(tester, 'olcum_kaydet');
      expect(_errorText(tester), 'Büyük tansiyon küçük tansiyondan yüksek olmalı.');

      expect(repo.rows, isEmpty);
      expect(find.byKey(const Key('olcum_kaydet')), findsOneWidget, reason: 'pencere açık kalır');
    });

    testWidgets('yazılamazsa hata görünür, girilenler durur', (tester) async {
      final repo = FakeMeasurementRepository(failAdds: true);
      await _open(tester, repo);
      await _tap(tester, 'olcum_ekle');
      await _type(tester, 'olcum_deger', '120');
      await _type(tester, 'olcum_deger2', '80');
      await _tap(tester, 'olcum_kaydet');
      expect(_errorText(tester), 'Kaydedilemedi.');
      expect(_fieldText(tester, 'olcum_deger'), '120');
      expect(_fieldText(tester, 'olcum_deger2'), '80');
    });

    testWidgets('geçmiş gün ve saat seçilebilir', (tester) async {
      final repo = FakeMeasurementRepository();
      await _open(tester, repo);
      await _tap(tester, 'olcum_ekle');
      await _type(tester, 'olcum_deger', '118');
      await _type(tester, 'olcum_deger2', '76');

      await _tap(tester, 'olcum_tarih');
      await tester.tap(find.text('5'));
      await tester.tap(find.text('Tamam'));
      await tester.pumpAndSettle();
      expect(find.text('5 Kasım 2026'), findsOneWidget);

      await _tap(tester, 'olcum_kaydet');
      expect(repo.rows.single.logDate, '2026-11-05');
    });
  });

  group('nabız', () {
    testWidgets('tek değerli; ikinci alan yok', (tester) async {
      final repo = FakeMeasurementRepository();
      await _open(tester, repo);
      await _tap(tester, 'olcum_tur_${MeasurementTypes.pulse}');
      await _tap(tester, 'olcum_ekle');
      expect(find.byKey(const Key('olcum_deger2')), findsNothing);
      await _type(tester, 'olcum_deger', '72');
      await _tap(tester, 'olcum_kaydet');
      expect(repo.rows.single.type, MeasurementTypes.pulse);
      expect(tester.widget<Text>(find.byKey(const Key('olcum_son_deger'))).data, '72 bpm');
    });
  });

  group('kan şekeri', () {
    testWidgets('mg/dL girişi bağlamla yazılır; seçili bağlama dokunmak kaldırır', (tester) async {
      final repo = FakeMeasurementRepository();
      await _open(tester, repo);
      await _tap(tester, 'olcum_tur_$_glucose');
      await _tap(tester, 'olcum_ekle');
      await _type(tester, 'olcum_deger', '105');
      await _tap(tester, 'olcum_baglam_fasting');
      await _tap(tester, 'olcum_baglam_other');
      await _tap(tester, 'olcum_baglam_other'); // kaldır
      await _tap(tester, 'olcum_baglam_fasting'); // kaldır
      await _tap(tester, 'olcum_baglam_after_meal');
      await _tap(tester, 'olcum_kaydet');

      final m = repo.rows.single;
      expect((m.value, m.unit, m.context), (105.0, 'mg/dL', 'after_meal'));
      expect(find.textContaining('Tokluk'), findsWidgets);
    });

    testWidgets('seçili bağlama yeniden dokununca bağlam kaldırılır ve boş yazılır', (tester) async {
      final repo = FakeMeasurementRepository();
      await _open(tester, repo);
      await _tap(tester, 'olcum_tur_$_glucose');
      await _tap(tester, 'olcum_ekle');
      await _type(tester, 'olcum_deger', '105');
      await _tap(tester, 'olcum_baglam_fasting');
      await _tap(tester, 'olcum_baglam_fasting');
      await _tap(tester, 'olcum_kaydet');
      expect(repo.rows.single.context, isNull);
    });

    testWidgets('aralık uyarısı seçili birimde yazılır (mmol/L)', (tester) async {
      final repo = FakeMeasurementRepository();
      await _open(tester, repo);
      await _tap(tester, 'olcum_tur_$_glucose');
      await _tap(tester, 'olcum_ekle');
      await _tap(tester, 'olcum_birim_mmol/L');
      await _type(tester, 'olcum_deger', '1');
      await _tap(tester, 'olcum_kaydet');
      expect(_errorText(tester), 'Değer 1,1 ile 33,3 mmol/L arasında olmalı.');
      expect(repo.rows, isEmpty);

      await _tap(tester, 'olcum_birim_mg/dL');
      await _type(tester, 'olcum_deger', '5');
      await _tap(tester, 'olcum_kaydet');
      expect(_errorText(tester), 'Değer 20 ile 600 mg/dL arasında olmalı.');
    });

    testWidgets('pencerede birim değişince yazılan sayı çevrilir; mmol/L girişi mg/dL saklanır', (tester) async {
      final repo = FakeMeasurementRepository();
      await _open(tester, repo);
      await _tap(tester, 'olcum_tur_$_glucose');
      await _tap(tester, 'olcum_ekle');
      await _type(tester, 'olcum_deger', '99');
      await _tap(tester, 'olcum_birim_mmol/L');
      expect(_fieldText(tester, 'olcum_deger'), '5,5');
      await _tap(tester, 'olcum_birim_mg/dL');
      expect(_fieldText(tester, 'olcum_deger'), '99');

      await _tap(tester, 'olcum_birim_mmol/L');
      await _type(tester, 'olcum_deger', '5,5');
      await _tap(tester, 'olcum_kaydet');
      final m = repo.rows.single;
      expect(m.value, closeTo(99.088, 1e-9));
      expect(m.unit, 'mg/dL');
    });

    testWidgets('ekrandaki birim seçimi kalıcıdır ve değerler yeni birimde görünür', (tester) async {
      final settings = FakeSettingsRepository();
      final repo = FakeMeasurementRepository()..seed(_glucose, 99.088, DateTime(2026, 11, 10, 7), unit: 'mg/dL');
      await _open(tester, repo, settings: settings);
      await _tap(tester, 'olcum_tur_$_glucose');
      expect(tester.widget<Text>(find.byKey(const Key('olcum_son_deger'))).data, '99 mg/dL');

      await _tap(tester, 'olcum_ekran_birim_mmol/L');
      expect(tester.widget<Text>(find.byKey(const Key('olcum_son_deger'))).data, '5,5 mmol/L');
      expect(settings.values['reading_unit:$_glucose'], 'mmol/L');
    });

    testWidgets('tansiyonda ve nabızda birim seçimi yoktur', (tester) async {
      await _open(tester, FakeMeasurementRepository());
      expect(find.byKey(const Key('olcum_ekran_birim_mmol/L')), findsNothing);
      await _tap(tester, 'olcum_ekle');
      expect(find.byKey(const Key('olcum_birim_mmol/L')), findsNothing);
    });
  });

  group('düzenleme ve silme', () {
    testWidgets('düzenleme açılışta değerleri doldurur ve kaydı günceller', (tester) async {
      final repo = FakeMeasurementRepository();
      final m = repo.seed(_bp, 120, DateTime(2026, 11, 9, 8, 30), unit: 'mmHg', value2: 80);
      await _open(tester, repo);
      await _tap(tester, 'olcum_duzenle_${m.id}');
      expect(_fieldText(tester, 'olcum_deger'), '120');
      expect(_fieldText(tester, 'olcum_deger2'), '80');
      expect(find.text('08:30'), findsOneWidget);
      expect(find.text('9 Kasım 2026'), findsOneWidget);

      await _type(tester, 'olcum_deger', '130');
      await _type(tester, 'olcum_deger2', '85');
      await _tap(tester, 'olcum_kaydet');
      expect(repo.rows, hasLength(1));
      expect((repo.rows.single.value, repo.rows.single.value2), (130.0, 85.0));
      expect(repo.rows.single.id, m.id);
      expect(repo.rows.single.measuredAt, DateTime(2026, 11, 9, 8, 30));
    });

    testWidgets('silme onay ister; vazgeçince kayıt kalır, onaylayınca gider', (tester) async {
      final repo = FakeMeasurementRepository();
      final m = repo.seed(_bp, 120, DateTime(2026, 11, 9, 8, 30), unit: 'mmHg', value2: 80);
      await _open(tester, repo);

      await _tap(tester, 'olcum_sil_${m.id}');
      expect(find.text('Ölçüm silinsin mi?'), findsOneWidget);
      await _tap(tester, 'olcum_sil_vazgec');
      expect(find.byKey(Key('olcum_kayit_${m.id}')), findsOneWidget);

      await _tap(tester, 'olcum_sil_${m.id}');
      await _tap(tester, 'olcum_sil_onay');
      expect(find.byKey(Key('olcum_kayit_${m.id}')), findsNothing);
      expect(find.text('Ölçüm silindi'), findsOneWidget);
      expect(repo.rows.single.deletedAt, isNotNull);
    });

    testWidgets('silinemezse kayıt yerinde kalır ve uyarı çıkar', (tester) async {
      final repo = FakeMeasurementRepository(failDeletes: true);
      final m = repo.seed(_bp, 120, DateTime(2026, 11, 9, 8, 30), unit: 'mmHg', value2: 80);
      await _open(tester, repo);
      await _tap(tester, 'olcum_sil_${m.id}');
      await _tap(tester, 'olcum_sil_onay');
      expect(find.text('Kaydedilemedi.'), findsOneWidget);
      expect(find.byKey(Key('olcum_kayit_${m.id}')), findsOneWidget);
    });
  });

  group('geçmiş ve grafik', () {
    testWidgets('en yeni önce; tek ölçümde grafik yerine ipucu, iki ölçümde grafik ve gösterge', (tester) async {
      final repo = FakeMeasurementRepository()..seed(_bp, 118, DateTime(2026, 11, 8, 8), unit: 'mmHg', value2: 76);
      await _open(tester, repo);
      expect(find.byKey(const Key('olcum_grafik_bos')), findsOneWidget);
      expect(find.byKey(const Key('olcum_grafik')), findsNothing);

      final newer = repo.seed(_bp, 130, DateTime(2026, 11, 9, 20), unit: 'mmHg', value2: 85);
      await _tap(tester, 'olcum_tur_$_glucose');
      await _tap(tester, 'olcum_tur_$_bp');
      expect(find.byKey(const Key('olcum_grafik')), findsOneWidget);
      expect(find.text('Büyük'), findsOneWidget);
      expect(find.text('Küçük'), findsOneWidget);
      // Tansiyonda iki çizgi: büyük (118 → 130) ve küçük (76 → 85), eskiden yeniye.
      final bars = tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData;
      expect(bars, hasLength(2));
      expect(bars[0].spots.map((s) => s.y), [118.0, 130.0]);
      expect(bars[1].spots.map((s) => s.y), [76.0, 85.0]);
      expect(tester.widget<Text>(find.byKey(const Key('olcum_son_deger'))).data, '130/85 mmHg');
      expect(
        tester.getTopLeft(find.byKey(Key('olcum_kayit_${newer.id}'))).dy,
        lessThan(tester.getTopLeft(find.byKey(Key('olcum_kayit_${repo.rows.first.id}'))).dy),
      );
    });

    testWidgets('notlu kayıtta not görünür; türler birbirine karışmaz', (tester) async {
      final repo = FakeMeasurementRepository()
        ..seed(MeasurementTypes.pulse, 70, DateTime(2026, 11, 9, 8), unit: 'bpm')
        ..seed(MeasurementTypes.weight, 72, DateTime(2026, 11, 9, 8), unit: 'kg');
      await _open(tester, repo);
      expect(find.byKey(const Key('olcum_bos')), findsOneWidget, reason: 'tansiyon boş; nabız ve kilo sayılmaz');
      await _tap(tester, 'olcum_tur_${MeasurementTypes.pulse}');
      expect(find.text('70 bpm'), findsWidgets);
      expect(find.textContaining('72'), findsNothing, reason: 'kilo gösterilmez');
    });
  });

  for (final (scale, size) in [
    (0.81, const Size(360, 700)), // Redmi'de görülen küçük yazı ölçeği
    (1.0, const Size(360, 700)),
    (1.6, const Size(360, 700)), // büyük yazı
  ]) {
    testWidgets('küçük ekranda ve yazı ölçeği $scale ile pencere taşmadan açılır ve kaydeder', (tester) async {
      final repo = FakeMeasurementRepository();
      await _open(tester, repo, size: size, textScale: scale);
      await _tap(tester, 'olcum_tur_$_glucose');
      await _tap(tester, 'olcum_ekle');
      await _type(tester, 'olcum_deger', '110');
      await _tap(tester, 'olcum_baglam_fasting');
      await _tap(tester, 'olcum_kaydet');
      expect(tester.takeException(), isNull);
      expect(repo.rows.single.value, 110.0);
      expect(find.byKey(const Key('olcum_grafik_bos')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('okuma hatasında mesaj ve yeniden dene düğmesi çıkar', (tester) async {
    final repo = FakeMeasurementRepository(failLoads: 1);
    await _open(tester, repo);
    expect(find.byKey(const Key('olcum_okunamadi')), findsOneWidget);
    expect(find.byKey(const Key('olcum_ekle')), findsNothing, reason: 'veri yokken ekleme düğmesi gizli');
    await _tap(tester, 'olcum_tekrar');
    expect(find.byKey(const Key('olcum_okunamadi')), findsNothing);
    expect(find.byKey(const Key('olcum_bos')), findsOneWidget);
  });
}
