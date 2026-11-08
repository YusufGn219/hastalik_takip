import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/data/backup/backup_service.dart';
import 'package:mobile/features/backup/backup_exporter.dart';
import 'package:mobile/features/backup/backup_export_screen.dart';
import 'package:mobile/features/backup/backup_platform.dart';
import 'package:mobile/l10n/app_localizations.dart';

class _FakeStorage implements BackupStorage {
  @override
  Future<File> databaseFile() => throw UnimplementedError();
  @override
  Future<String> databaseKey() => throw UnimplementedError();
  @override
  Future<Directory> scratchDirectory() => throw UnimplementedError();
}

class _FakeSaver implements BackupFileSaver {
  @override
  Future<bool> save({required fileName, required bytes}) => throw UnimplementedError();
}

/// Gerçek dosya işi yapmadan sonucu önceden belirlenen "Yedek al" işi.
class _FakeExporter extends BackupExporter {
  _FakeExporter({this.result = BackupExportResult.saved, this.error})
      : super(
          service: BackupService(currentSchemaVersion: 3),
          storage: _FakeStorage(),
          saver: _FakeSaver(),
        );

  final BackupExportResult result;
  final Object? error;
  final passphrases = <String>[];

  @override
  Future<BackupExportResult> run(String passphrase) async {
    passphrases.add(passphrase);
    if (error != null) throw error!;
    return result;
  }
}

Widget _app(_FakeExporter exporter) => ProviderScope(
      overrides: [backupExporterProvider.overrideWithValue(exporter)],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const BackupExportScreen(),
      ),
    );

Future<void> _fill(WidgetTester tester, String pass, String confirm) async {
  await tester.enterText(find.byKey(const Key('yedek_parola')), pass);
  await tester.enterText(find.byKey(const Key('yedek_parola_tekrar')), confirm);
  await tester.pump();
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('yedek_al')));
  await tester.tap(find.byKey(const Key('yedek_al')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

TextField _field(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(Key(key)));

void main() {
  testWidgets('uyarı metni görünür: parola unutulursa kurtarma yok', (tester) async {
    await tester.pumpWidget(_app(_FakeExporter()));

    expect(find.byKey(const Key('yedek_uyari')), findsOneWidget);
    expect(find.textContaining('kurtarma yolu yoktur'), findsOneWidget);
  });

  testWidgets('parola varsayılan gizli; göz düğmesi gösterir ve gizler', (tester) async {
    await tester.pumpWidget(_app(_FakeExporter()));

    expect(_field(tester, 'yedek_parola').obscureText, isTrue);
    expect(_field(tester, 'yedek_parola_tekrar').obscureText, isTrue);
    await tester.tap(find.byKey(const Key('yedek_goster')));
    await tester.pump();
    expect(_field(tester, 'yedek_parola').obscureText, isFalse);
    expect(_field(tester, 'yedek_parola_tekrar').obscureText, isFalse);
    await tester.tap(find.byKey(const Key('yedek_goster')));
    await tester.pump();
    expect(_field(tester, 'yedek_parola').obscureText, isTrue);
  });

  testWidgets('kısa parola reddedilir, yedek başlamaz', (tester) async {
    final exporter = _FakeExporter();
    await tester.pumpWidget(_app(exporter));
    await _fill(tester, 'kısa', 'kısa');
    await _submit(tester);

    expect(find.text('Parola en az 8 karakter olmalı'), findsOneWidget);
    expect(exporter.passphrases, isEmpty);
  });

  testWidgets('parolalar farklıysa reddedilir, yedek başlamaz', (tester) async {
    final exporter = _FakeExporter();
    await tester.pumpWidget(_app(exporter));
    await _fill(tester, 'yedek parolam 2026', 'yedek parolam 2027');
    await _submit(tester);

    expect(find.text('Parolalar aynı değil'), findsOneWidget);
    expect(exporter.passphrases, isEmpty);
  });

  testWidgets('geçerli parolayla yedek alınır, başarı gösterilir, alanlar temizlenir',
      (tester) async {
    final exporter = _FakeExporter();
    await tester.pumpWidget(_app(exporter));
    await _fill(tester, 'yedek parolam 2026', 'yedek parolam 2026');
    await _submit(tester);

    expect(exporter.passphrases, ['yedek parolam 2026']);
    expect(find.text('Yedek kaydedildi.'), findsOneWidget);
    expect(_field(tester, 'yedek_parola').controller!.text, isEmpty);
    expect(_field(tester, 'yedek_parola_tekrar').controller!.text, isEmpty);
  });

  testWidgets('konum seçilmezse "yedek alınmadı" der, başarı demez', (tester) async {
    final exporter = _FakeExporter(result: BackupExportResult.cancelled);
    await tester.pumpWidget(_app(exporter));
    await _fill(tester, 'yedek parolam 2026', 'yedek parolam 2026');
    await _submit(tester);

    expect(find.text('Konum seçilmedi; yedek alınmadı.'), findsOneWidget);
    expect(find.text('Yedek kaydedildi.'), findsNothing);
  });

  testWidgets('hata olursa anlaşılır mesaj çıkar ve parola alanı korunur', (tester) async {
    final exporter = _FakeExporter(error: BackupException(BackupFailure.io, 'disk'));
    await tester.pumpWidget(_app(exporter));
    await _fill(tester, 'yedek parolam 2026', 'yedek parolam 2026');
    await _submit(tester);

    expect(find.textContaining('Yedek alınamadı'), findsOneWidget);
    expect(find.text('Yedek kaydedildi.'), findsNothing);
    expect(_field(tester, 'yedek_parola').controller!.text, 'yedek parolam 2026');
  });
}
