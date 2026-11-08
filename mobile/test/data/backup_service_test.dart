import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/backup/backup_service.dart';
import 'package:mobile/data/database/database_opener.dart';
import 'package:mobile/data/repositories/symptom_repository.dart';
import 'package:sqlite3/sqlite3.dart';

import 'test_support.dart';

const _keyA = 'a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1';
const _keyB = 'b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2';
const _pass = 'yedek parolam 2026';

void main() {
  late Directory dir;
  late File main;
  late File backup;
  late BackupService service;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('vitapuls_backup_');
    main = File('${dir.path}/vitapuls.db');
    backup = File('${dir.path}/yedek.vpbak');
    service = BackupService(currentSchemaVersion: createTestDb().schemaVersion);
  });
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  /// Tohumlu şifreli veritabanı kurar, [names] adlı özel semptomları ekler ve kapatır.
  Future<void> makeDb(File file, String key, List<String> names) async {
    final db = openEncryptedDatabase(file, key);
    await seedLoaderFor(db).seedIfNeeded();
    for (final n in names) {
      await DriftSymptomRepository(db).createCustom(name: n);
    }
    await db.close();
  }

  Future<List<String>> symptomNames(File file, String key) async {
    final db = openEncryptedDatabase(file, key);
    final names = (await DriftSymptomRepository(db).listActive()).map((s) => s.name).toList();
    await db.close();
    return names;
  }

  test('dışa aktarılan dosya şifreli: düz başlık ve açık metin yok', () async {
    await makeDb(main, _keyA, ['Gizli semptom']);
    await service.export(database: main, hexKey: _keyA, target: backup, passphrase: _pass);

    final bytes = backup.readAsBytesSync();
    expect(String.fromCharCodes(bytes.sublist(0, 15)), isNot('SQLite format 3'));
    expect(String.fromCharCodes(bytes).contains('Gizli semptom'), isFalse);
    // Ana dosya ve geçici dosyalar dışında kalıntı yok.
    expect(dir.listSync().map((e) => e.uri.pathSegments.last).toSet(), {'vitapuls.db', 'yedek.vpbak'});
  });

  test('veritabanı açıkken (uygulama çalışırken) de dışa aktarılır', () async {
    final db = openEncryptedDatabase(main, _keyA);
    await seedLoaderFor(db).seedIfNeeded();
    await DriftSymptomRepository(db).createCustom(name: 'Açıkken eklendi');

    await service.export(database: main, hexKey: _keyA, target: backup, passphrase: _pass);
    await db.close();

    final raw = sqlite3.open(backup.path)..execute("PRAGMA key = '$_pass';");
    final count = raw.select("SELECT count(*) AS n FROM symptoms WHERE name = 'Açıkken eklendi';").first['n'];
    raw.close();
    expect(count, 1);
  });

  test('şema sürümü yedeğe geçer', () async {
    await makeDb(main, _keyA, []);
    await service.export(database: main, hexKey: _keyA, target: backup, passphrase: _pass);

    final raw = sqlite3.open(backup.path)..execute("PRAGMA key = '$_pass';");
    final version = raw.select('PRAGMA user_version;').first.values.first;
    raw.close();
    expect(version, service.currentSchemaVersion);
  });

  test('başka bir cihazda (başka anahtarla) geri yüklenir ve o anahtarla açılır', () async {
    await makeDb(main, _keyA, ['Eski telefondan']);
    await service.export(database: main, hexKey: _keyA, target: backup, passphrase: _pass);

    final fresh = File('${dir.path}/yeni_telefon.db');
    await service.restore(backup: backup, passphrase: _pass, database: fresh, hexKey: _keyB);

    expect(await symptomNames(fresh, _keyB), contains('Eski telefondan'));
    // Eski cihazın anahtarı yeni dosyayı açmaz.
    final wrong = openEncryptedDatabase(fresh, _keyA);
    await expectLater(DriftSymptomRepository(wrong).listActive(), throwsA(anything));
    await wrong.close().catchError((_) {});
  });

  test('geri yükleme birleştirmez, değiştirir', () async {
    await makeDb(main, _keyA, ['Yedekteki']);
    await service.export(database: main, hexKey: _keyA, target: backup, passphrase: _pass);

    // Yedekten sonra eklenen kayıt, geri yüklemeyle gider.
    final db = openEncryptedDatabase(main, _keyA);
    await DriftSymptomRepository(db).createCustom(name: 'Yedekten sonra');
    await db.close();

    await service.restore(backup: backup, passphrase: _pass, database: main, hexKey: _keyA);

    final names = await symptomNames(main, _keyA);
    expect(names, contains('Yedekteki'));
    expect(names, isNot(contains('Yedekten sonra')));
    expect(dir.listSync().map((e) => e.uri.pathSegments.last).toSet(), {'vitapuls.db', 'yedek.vpbak'});
  });

  test('yanlış parola: hata verir ve mevcut veritabanı olduğu gibi kalır', () async {
    await makeDb(main, _keyA, ['Mevcut']);
    await service.export(database: main, hexKey: _keyA, target: backup, passphrase: _pass);
    final before = main.readAsBytesSync();

    await expectLater(
      service.restore(backup: backup, passphrase: 'yanlış parola', database: main, hexKey: _keyA),
      throwsA(isA<BackupException>().having((e) => e.failure, 'failure', BackupFailure.wrongPassphraseOrCorrupt)),
    );

    expect(main.readAsBytesSync(), before);
    expect(dir.listSync().map((e) => e.uri.pathSegments.last).toSet(), {'vitapuls.db', 'yedek.vpbak'});
  });

  test('bozuk (şifreli olmayan) dosya yedek sayılmaz, veritabanı korunur', () async {
    await makeDb(main, _keyA, ['Mevcut']);
    backup.writeAsBytesSync(List.filled(4096, 7));
    final before = main.readAsBytesSync();

    await expectLater(
      service.restore(backup: backup, passphrase: _pass, database: main, hexKey: _keyA),
      throwsA(isA<BackupException>().having((e) => e.failure, 'failure', BackupFailure.wrongPassphraseOrCorrupt)),
    );
    expect(main.readAsBytesSync(), before);
  });

  test('ortasından bozulmuş yedek reddedilir ve veritabanı korunur', () async {
    await makeDb(main, _keyA, ['Mevcut']);
    await service.export(database: main, hexKey: _keyA, target: backup, passphrase: _pass);
    final bytes = backup.readAsBytesSync();
    // İlk sayfa sağlam (parola doğru çıksın), gövdesi bozuk.
    for (var i = bytes.length ~/ 2; i < bytes.length ~/ 2 + 64; i++) {
      bytes[i] ^= 0xFF;
    }
    backup.writeAsBytesSync(bytes);
    final before = main.readAsBytesSync();

    await expectLater(
      service.restore(backup: backup, passphrase: _pass, database: main, hexKey: _keyA),
      throwsA(isA<BackupException>()),
    );
    expect(main.readAsBytesSync(), before);
    expect(dir.listSync().map((e) => e.uri.pathSegments.last).toSet(), {'vitapuls.db', 'yedek.vpbak'});
  });

  test('daha yeni şema sürümünden yedek reddedilir', () async {
    await makeDb(main, _keyA, ['Mevcut']);
    await service.export(database: main, hexKey: _keyA, target: backup, passphrase: _pass);
    final raw = sqlite3.open(backup.path)
      ..execute("PRAGMA key = '$_pass';")
      ..execute('PRAGMA user_version = ${service.currentSchemaVersion + 1};');
    raw.close();
    final before = main.readAsBytesSync();

    await expectLater(
      service.restore(backup: backup, passphrase: _pass, database: main, hexKey: _keyA),
      throwsA(isA<BackupException>().having((e) => e.failure, 'failure', BackupFailure.newerVersion)),
    );
    expect(main.readAsBytesSync(), before);
  });

  test('parolayla açılan ama Vitapuls olmayan veritabanı reddedilir', () async {
    final raw = sqlite3.open(backup.path)
      ..execute("PRAGMA key = '$_pass';")
      ..execute('CREATE TABLE baska (x INTEGER);')
      ..execute('PRAGMA user_version = 1;');
    raw.close();
    await makeDb(main, _keyA, ['Mevcut']);

    await expectLater(
      service.restore(backup: backup, passphrase: _pass, database: main, hexKey: _keyA),
      throwsA(isA<BackupException>().having((e) => e.failure, 'failure', BackupFailure.notABackup)),
    );
  });

  test('kısa parola ve geçersiz anahtar daha başlamadan reddedilir', () async {
    await makeDb(main, _keyA, []);
    expect(
      () => service.export(database: main, hexKey: _keyA, target: backup, passphrase: 'kısa'),
      throwsArgumentError,
    );
    expect(
      () => service.export(database: main, hexKey: 'kısa', target: backup, passphrase: _pass),
      throwsArgumentError,
    );
    expect(backup.existsSync(), isFalse);
  });

  test('yanlış veritabanı anahtarıyla dışa aktarma hata verir, hedefte dosya kalmaz', () async {
    await makeDb(main, _keyA, []);
    await expectLater(
      service.export(database: main, hexKey: _keyB, target: backup, passphrase: _pass),
      throwsA(isA<BackupException>().having((e) => e.failure, 'failure', BackupFailure.io)),
    );
    expect(backup.existsSync(), isFalse);
    expect(dir.listSync().map((e) => e.uri.pathSegments.last).toSet(), {'vitapuls.db'});
  });

  test('var olan yedek dosyasının üzerine yazılır', () async {
    await makeDb(main, _keyA, ['Birinci']);
    await service.export(database: main, hexKey: _keyA, target: backup, passphrase: _pass);

    final db = openEncryptedDatabase(main, _keyA);
    await DriftSymptomRepository(db).createCustom(name: 'İkinci');
    await db.close();
    await service.export(database: main, hexKey: _keyA, target: backup, passphrase: _pass);

    final fresh = File('${dir.path}/kontrol.db');
    await service.restore(backup: backup, passphrase: _pass, database: fresh, hexKey: _keyB);
    expect(await symptomNames(fresh, _keyB), containsAll(['Birinci', 'İkinci']));
  });

  test('tırnak, boşluk ve Türkçe karakterli parola çalışır', () async {
    const odd = "şifre'm \"ğüş\" 12'";
    await makeDb(main, _keyA, ['Tırnaklı']);
    await service.export(database: main, hexKey: _keyA, target: backup, passphrase: odd);

    final fresh = File('${dir.path}/kontrol.db');
    await service.restore(backup: backup, passphrase: odd, database: fresh, hexKey: _keyB);
    expect(await symptomNames(fresh, _keyB), contains('Tırnaklı'));
  });

  test('geri yükleme, eski veritabanının yan dosyalarını yeni dosyaya bırakmaz', () async {
    await makeDb(main, _keyA, ['Yedekteki']);
    await service.export(database: main, hexKey: _keyA, target: backup, passphrase: _pass);
    File('${main.path}-wal').writeAsBytesSync([1, 2, 3]);
    File('${main.path}-shm').writeAsBytesSync([4, 5, 6]);

    await service.restore(backup: backup, passphrase: _pass, database: main, hexKey: _keyA);

    expect(File('${main.path}-wal').existsSync(), isFalse);
    expect(File('${main.path}-shm').existsSync(), isFalse);
    expect(await symptomNames(main, _keyA), contains('Yedekteki'));
  });

  test('yarım kalmış takas (ana dosya yok, .restore.old var) bir sonraki işlemde toparlanır', () async {
    await makeDb(main, _keyA, ['Kurtarılan']);
    final stranded = File('${main.path}.restore.old');
    main.renameSync(stranded.path);
    // Başka bir yedekle geri yükleme çağrısı: önce eski dosya yerine konur.
    final other = File('${dir.path}/diger.db');
    await makeDb(other, _keyB, ['Diger']);
    await service.export(database: other, hexKey: _keyB, target: backup, passphrase: _pass);
    // Yanlış parola ile başarısız olsun: ana dosya yine de geri gelmiş olmalı.
    await expectLater(
      service.restore(backup: backup, passphrase: 'yanlış parola', database: main, hexKey: _keyA),
      throwsA(isA<BackupException>()),
    );
    expect(main.existsSync(), isTrue);
    expect(await symptomNames(main, _keyA), contains('Kurtarılan'));
  });
}
