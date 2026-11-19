import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/widgets/form_sheet.dart';

String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString().replaceAll('.', ',');

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  group('StepperField', () {
    testWidgets('artı ve eksi değeri adım kadar değiştirir, sınırları aşmaz', (tester) async {
      final c = TextEditingController(text: '23,5');
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(StepperField(
        label: 'Uyku',
        controller: c,
        unit: 'saat',
        step: 0.5,
        min: 0,
        max: 24,
        format: _fmt,
      )));

      await tester.tap(find.text('+'));
      await tester.pump();
      expect(c.text, '24');
      await tester.tap(find.text('+'));
      await tester.pump();
      expect(c.text, '24'); // üst sınır

      c.text = '0,5';
      await tester.tap(find.text('−'));
      await tester.pump();
      expect(c.text, '0');
      await tester.tap(find.text('−'));
      await tester.pump();
      expect(c.text, '0'); // alt sınır
    });

    testWidgets('boş alanda ilk basış başlangıç değerinden sayar; değişiklik bildirilir',
        (tester) async {
      final c = TextEditingController();
      addTearDown(c.dispose);
      var changes = 0;
      await tester.pumpWidget(_wrap(StepperField(
        label: 'Uyku',
        controller: c,
        unit: 'saat',
        step: 0.5,
        min: 0,
        max: 24,
        start: 7,
        format: _fmt,
        onChanged: () => changes++,
      )));

      await tester.tap(find.text('+'));
      await tester.pump();
      expect(c.text, '7,5');
      expect(changes, 1);
    });

    testWidgets('değer alanına elle yazılabilir', (tester) async {
      final c = TextEditingController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_wrap(StepperField(
        label: 'Su',
        controller: c,
        unit: 'litre',
        step: 0.5,
        min: 0,
        max: 10,
        format: _fmt,
      )));

      await tester.enterText(find.byType(TextField), '2,5');
      expect(c.text, '2,5');
    });
  });

  group('ScaleButtons', () {
    testWidgets('dokunulan sayı bildirilir', (tester) async {
      var value = 3;
      await tester.pumpWidget(_wrap(StatefulBuilder(
        builder: (context, setState) => ScaleButtons(
          label: 'Ruh hali',
          value: value,
          onChanged: (v) => setState(() => value = v),
        ),
      )));

      await tester.tap(find.byKey(const Key('olcek_5')));
      await tester.pump();
      expect(value, 5);
    });
  });

  group('FormSheet', () {
    testWidgets('başlığı gösterir; X ve dışına dokunmak sayfayı kapatır', (tester) async {
      await tester.pumpWidget(MaterialApp(
        onGenerateRoute: (s) => s.name == '/'
            ? MaterialPageRoute(
                settings: s,
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push(formSheetRoute<void>(
                      const RouteSettings(name: '/sayfa'),
                      (_) => const FormSheet(title: 'Günlük kayıt', child: Text('içerik')),
                    )),
                    child: const Text('aç'),
                  ),
                ),
              )
            : null,
      ));

      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      expect(find.text('Günlük kayıt'), findsOneWidget);
      expect(find.text('içerik'), findsOneWidget);

      await tester.tap(find.byKey(const Key('sayfa_kapat')));
      await tester.pumpAndSettle();
      expect(find.text('içerik'), findsNothing);

      // Dışına (üstteki karartılmış alana) dokunmak da kapatır.
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.text('içerik'), findsNothing);
    });
  });
}
