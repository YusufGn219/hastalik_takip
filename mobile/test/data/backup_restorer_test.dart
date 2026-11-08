import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/database_swapper.dart';
import 'package:mobile/data/backup/backup_service.dart';
import 'package:mobile/data/database/database_opener.dart';
import 'package:mobile/data/repositories/symptom_repository.dart';
import 'package:mobile/features/backup/backup_platform.dart';
import 'package:mobile/features/backup/backup_restorer.dart';

import 'test_support.dart';

const _key = 'a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1';
const _pass = 'yedek parolam 2026';

class _Storage implements BackupStorage {
  _Storage(this.db, this.scratch);
  final File db;
  final Directory scratch;

  @override
  Future<File> databaseFile() async => db;
  @override
  Future<String> databaseKey() async => _key;
  @override
  Future<Directory> scratchDirectory() async => scratch;
}

/// Veritabanını kapatıp açmaz; yalnız işi çalıştırır ve sayar.
class _Swapper implements DatabaseSwapper {
  int calls = 0;

  @override
  Future<void> swap(Future<void> Function() action) async {
    calls++;
    await action();
  }
}

void main() {
  late Directory dir;
  late Directory scratch;
  late File dbFile;
  late File backup;
  late BackupService service;
  late _Swapper swapper;
  late BackupRestorer restorer;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('vitapuls_rst_');
    scratch = Directory('${dir.path}/gecici')..createSync();
    dbFile = File('${dir.path}/vitapuls.db');
    backup = File('${dir.path}/yedek.vpbak');
    service = BackupService(currentSchemaVersion: createTestDb().schemaVersion);
    swapper = _Swapper();
    restorer = BackupRestorer(service: service, storage: _Storage(dbFile, scratch), swapper: swapper);

    final db = openEncryptedDatabase(dbFile, _key);
    await seedLoaderFor(db).seedIfNeeded();
    await DriftSymptomRepository(db).createCustom(name: 'Yedekteki');
    await db.close();
    await service.export(database: dbFile, hexKey: _key, target: backup, passphrase: _pass);

    // Yedekten sonra eklenen kayıt, geri yüklemeyle gitmeli.
    final db2 = openEncryptedDatabase(dbFile, _key);
    await DriftSymptomRepository(db2).createCustom(name: 'Yedekten sonra');
    await db2.close();
  });
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<List<String>> names() async {
    final db = openEncryptedDatabase(dbFile, _key);
    final n = (await DriftSymptomRepository(db).listActive()).map((s) => s.name).toList();
    await db.close();
    return n;
  }

  test('doğru parolayla veritabanı yedektekiyle değişir', () async {
    await restorer.run(backup: backup, passphrase: _pass);

    expect(swapper.calls, 1);
    final n = await names();
    expect(n, contains('Yedekteki'));
    expect(n, isNot(contains('Yedekten sonra')));
  });

  test('yanlış parolada veritabanı HİÇ kapatılmaz (swap çağrılmaz) ve veri değişmez', () async {
    final before = dbFile.readAsBytesSync();
    await expectLater(
      restorer.run(backup: backup, passphrase: 'yanlış parola'),
      throwsA(isA<BackupException>().having((e) => e.failure, 'failure', BackupFailure.wrongPassphraseOrCorrupt)),
    );

    expect(swapper.calls, 0);
    expect(dbFile.readAsBytesSync(), before);
  });

  test('Vitapuls olmayan dosyada da swap çağrılmaz', () async {
    backup.writeAsBytesSync(List.filled(4096, 9));
    await expectLater(restorer.run(backup: backup, passphrase: _pass), throwsA(isA<BackupException>()));
    expect(swapper.calls, 0);
  });

  test('geçici klasördeki seçici kopyası silinir, klasör dışındaki dosyaya dokunulmaz', () async {
    final cached = File('${scratch.path}/file_picker/yedek.vpbak')
      ..createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3]);
    final users = File('${dir.path}/kullanicinin_dosyasi.vpbak')..writeAsBytesSync([4, 5, 6]);

    await restorer.discardPickedCopy(cached);
    await restorer.discardPickedCopy(users);

    expect(cached.existsSync(), isFalse);
    expect(users.existsSync(), isTrue);
  });
}
