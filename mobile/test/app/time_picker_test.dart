import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/medication/screens/recurring_screen.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// Saat seçici, uygulamanın gerçek temasıyla ve telefonun yazı boyutu küçükken
/// (0,81) klavye girişi moduna geçince bozulmamalı (telefonda "BoxConstraints has
/// non-normalized height" hata ekranı çıkmıştı; Flutter'ın kendi sorunu, düz
/// temayla da çıkıyor). Telefonun gerçek değerleri: 1080x2400, yoğunluk 440
/// (2,75), yazı ölçeği 0,81.
void main() {
  Future<void> open(WidgetTester tester,
      {required double textScale, double keyboard = 0}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showTimePicker(
                context: context,
                initialTime: const TimeOfDay(hour: 8, minute: 0),
                builder: timePickerBuilder, // ekrandaki gerçek yapılandırma
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

  for (final (scale, keyboard) in [
    (0.81, 0.0),
    (1.0, 0.0),
    (1.3, 0.0),
    (0.81, 1000.0),
    (1.0, 1000.0),
    (1.3, 1000.0),
    (1.0, 1300.0),
  ]) {
    testWidgets(
        'klavye girişi modu hata vermeden açılır (yazı ölçeği $scale, klavye $keyboard)',
        (tester) async {
      await open(tester, textScale: scale);
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      if (keyboard > 0) {
        // Metin alanı odak alınca ekran klavyesi açılır ve boş alanı daraltır.
        tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
        await tester.pumpAndSettle();
      }

      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsWidgets);
    });
  }
}
