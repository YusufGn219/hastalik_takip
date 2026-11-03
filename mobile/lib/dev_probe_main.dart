// GEÇİCİ TEŞHİS DOSYASI — Sprint 1 telefon doğrulaması için. Doğrulamadan
// sonra silinecek, commit'e girmemeli.
//
// Çalıştırma: flutter run -t lib/dev_probe_main.dart -d <cihaz>

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile/data/database/database_opener.dart';
import 'package:mobile/data/database/seed_loader.dart';
import 'package:mobile/data/repositories/symptom_repository.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String> _probe() async {
  final out = StringBuffer();
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, 'vitapuls.db'));
  out.writeln('Dosya: ${file.path}');
  out.writeln('Önceden var mıydı: ${file.existsSync()}');

  // 1) Aç + başlangıç verisi + bir özel kayıt.
  var db = await openAppDatabase();
  final cipher = await db.customSelect('PRAGMA cipher_version;').get();
  out.writeln('cipher_version: ${cipher.map((r) => r.data).toList()}');
  await SeedLoader(db).seedIfNeeded();
  final repo = DriftSymptomRepository(db);
  final countBefore = (await repo.listActive()).length;
  if (!(await repo.listActive()).any((s) => s.name == 'Telefon deneme kaydı')) {
    await repo.createCustom(name: 'Telefon deneme kaydı');
  }
  out.writeln('Semptom sayısı (yazmadan önce → sonra): $countBefore → '
      '${(await repo.listActive()).length}');
  await db.close();

  // 2) Dosya başlığı düz SQLite mı?
  final header = file.readAsBytesSync().sublist(0, 15);
  out.writeln(
    'Dosya başlığı düz SQLite: ${String.fromCharCodes(header) == 'SQLite format 3'}',
  );

  // 3) Aynı anahtarla yeniden aç, veri geliyor mu?
  db = await openAppDatabase();
  final names =
      (await DriftSymptomRepository(db).listActive()).map((s) => s.name);
  out.writeln('Yeniden açıldı, semptom: ${names.length}, '
      'deneme kaydı var: ${names.contains('Telefon deneme kaydı')}');
  await db.close();
  out.writeln('SONUÇ: TAMAM');
  return out.toString();
}

void main() {
  runApp(MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: const Text('DB probe')),
      body: FutureBuilder<String>(
        future: _probe(),
        builder: (context, snap) => Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: SelectableText(
              snap.hasError
                  ? 'HATA: ${snap.error}\n${snap.stackTrace}'
                  : snap.data ?? 'çalışıyor...',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ),
      ),
    ),
  ));
}
