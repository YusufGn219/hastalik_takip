import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/widgets/pinned_action_bar.dart';

Widget _app({Widget? message}) => MaterialApp(
      home: Scaffold(
        bottomNavigationBar: PinnedActionBar(
          message: message,
          child: ElevatedButton(onPressed: () {}, child: const Text('Kaydet')),
        ),
        // İçerik ekrandan çok uzun: düğme kaydırmadan bağımsız görünür kalmalı.
        body: ListView(
          children: [
            for (var i = 0; i < 60; i++) SizedBox(height: 60, child: Text('satır $i')),
          ],
        ),
      ),
    );

void main() {
  testWidgets('içerik uzun olsa da düğme ekranın altında görünür', (tester) async {
    await tester.pumpWidget(_app());
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;

    expect(find.text('Kaydet'), findsOneWidget);
    expect(tester.getBottomLeft(find.text('Kaydet')).dy, greaterThan(screen.height - 100));

    await tester.drag(find.byType(ListView), const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(find.text('Kaydet'), findsOneWidget);
    expect(tester.getBottomLeft(find.text('Kaydet')).dy, greaterThan(screen.height - 100));
  });

  testWidgets('ileti düğmenin hemen üstünde durur; yoksa yer kaplamaz', (tester) async {
    await tester.pumpWidget(_app(message: const Text('Hata var')));
    expect(find.text('Hata var'), findsOneWidget);
    expect(tester.getBottomLeft(find.text('Hata var')).dy,
        lessThan(tester.getTopLeft(find.text('Kaydet')).dy));

    await tester.pumpWidget(_app());
    expect(find.text('Hata var'), findsNothing);
  });
}
