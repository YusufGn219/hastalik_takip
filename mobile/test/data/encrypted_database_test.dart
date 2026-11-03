import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/database_opener.dart';
import 'package:mobile/data/repositories/symptom_repository.dart';

import 'test_support.dart';

const _keyA =
    'a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1';
const _keyB =
    'b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2';

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('vitapuls_enc_');
    file = File('${dir.path}/test.db');
  });
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('dosya şifreli: düz SQLite başlığı yok, veri anahtarla geri okunur',
      () async {
    var db = openEncryptedDatabase(file, _keyA);
    await seedLoaderFor(db).seedIfNeeded();
    await DriftSymptomRepository(db).createCustom(name: 'Gizli semptom');
    await db.close();

    // Düz SQLite dosyaları "SQLite format 3\0" ile başlar; şifreli dosyada yok.
    final header = file.readAsBytesSync().sublist(0, 15);
    expect(String.fromCharCodes(header), isNot('SQLite format 3'));
    // Metin dosyada açık okunamaz.
    expect(
      String.fromCharCodes(file.readAsBytesSync()).contains('Gizli semptom'),
      isFalse,
    );

    db = openEncryptedDatabase(file, _keyA);
    final names =
        (await DriftSymptomRepository(db).listActive()).map((s) => s.name);
    expect(names, contains('Gizli semptom'));
    expect(names.length, 9);
    await db.close();
  });

  test('yanlış anahtarla açılamaz', () async {
    final db = openEncryptedDatabase(file, _keyA);
    await seedLoaderFor(db).seedIfNeeded();
    await db.close();

    final wrong = openEncryptedDatabase(file, _keyB);
    await expectLater(
      DriftSymptomRepository(wrong).listActive(),
      throwsA(anything),
    );
    await wrong.close().catchError((_) {});
  });

  test('geçersiz biçimli anahtar reddedilir', () {
    expect(() => openEncryptedDatabase(file, 'kısa'), throwsArgumentError);
    expect(
      () => openEncryptedDatabase(file, 'z' * 64),
      throwsArgumentError,
    );
  });

  test('AppDatabase türü döner', () async {
    final db = openEncryptedDatabase(file, _keyA);
    expect(db, isA<AppDatabase>());
    await db.close();
  });
}
