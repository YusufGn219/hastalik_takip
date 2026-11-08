import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/backup/backup_service.dart';
import 'package:mobile/data/database/database_opener.dart';
import 'package:mobile/data/repositories/symptom_repository.dart';
import 'package:mobile/features/backup/backup_exporter.dart';
import 'package:mobile/features/backup/backup_platform.dart';
import 'package:sqlite3/sqlite3.dart';

import 'test_support.dart';

const _key = 'a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1';
const _pass = 'yedek parolam 2026';

class _Storage implements BackupStorage {
  _Storage(this.db, this.scratch, {this.key = _key});
  final File db;
  final Directory scratch;
  final String key;

  @override
  Future<File> databaseFile() async => db;
  @override
  Future<String> databaseKey() async => key;
  @override
  Future<Directory> scratchDirectory() async => scratch;
}

class _Saver implements BackupFileSaver {
  _Saver({this.accept = true, this.error});
  final bool accept;
  final Object? error;
  String? name;
  Uint8List? bytes;
  int calls = 0;

  @override
  Future<bool> save({required String fileName, required Uint8List bytes}) async {
    calls++;
    if (error != null) throw error!;
    name = fileName;
    this.bytes = bytes;
    return accept;
  }
}

void main() {
  late Directory dir;
  late Directory scratch;
  late File dbFile;
  late BackupService service;
  final now = DateTime(2026, 11, 8, 9, 5);

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('vitapuls_exp_');
    scratch = Directory('${dir.path}/gecici')..createSync();
    dbFile = File('${dir.path}/vitapuls.db');
    service = BackupService(currentSchemaVersion: createTestDb().schemaVersion);
    final db = openEncryptedDatabase(dbFile, _key);
    await seedLoaderFor(db).seedIfNeeded();
    await DriftSymptomRepository(db).createCustom(name: 'Yedeklenecek');
    await db.close();
  });
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  BackupExporter exporter(BackupFileSaver saver, {String key = _key}) => BackupExporter(
        service: service,
        storage: _Storage(dbFile, scratch, key: key),
        saver: saver,
        clock: () => now,
      );

  test('dosya adı tarih ve saati taşır', () {
    expect(BackupExporter.fileNameFor(now), 'vitapuls-yedek-2026-11-08-0905.vpbak');
  });

  test('yedek seçilen yere şifreli yazılır, geçici dosya silinir', () async {
    final saver = _Saver();
    final result = await exporter(saver).run(_pass);

    expect(result, BackupExportResult.saved);
    expect(saver.name, 'vitapuls-yedek-2026-11-08-0905.vpbak');
    expect(scratch.listSync(), isEmpty);

    // Kaydedilen baytlar parolayla açılan, veriyi içeren bir yedek.
    final copy = File('${dir.path}/kontrol.vpbak')..writeAsBytesSync(saver.bytes!);
    expect(String.fromCharCodes(saver.bytes!).contains('Yedeklenecek'), isFalse);
    final raw = sqlite3.open(copy.path)..execute("PRAGMA key = '$_pass';");
    final n = raw.select("SELECT count(*) AS n FROM symptoms WHERE name = 'Yedeklenecek';").first['n'];
    raw.close();
    expect(n, 1);
  });

  test('kullanıcı konum seçmekten vazgeçerse sonuç "cancelled", geçici dosya silinir', () async {
    final saver = _Saver(accept: false);
    final result = await exporter(saver).run(_pass);

    expect(result, BackupExportResult.cancelled);
    expect(saver.calls, 1);
    expect(scratch.listSync(), isEmpty);
  });

  test('şifreleme başarısız olursa kaydetme penceresi hiç açılmaz', () async {
    final saver = _Saver();
    const wrongKey = 'b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2';
    await expectLater(exporter(saver, key: wrongKey).run(_pass), throwsA(isA<BackupException>()));

    expect(saver.calls, 0);
    expect(scratch.listSync(), isEmpty);
  });

  test('kaydetme hata verirse geçici dosya yine silinir', () async {
    final saver = _Saver(error: const FileSystemException('disk dolu'));
    await expectLater(exporter(saver).run(_pass), throwsA(isA<FileSystemException>()));

    expect(scratch.listSync(), isEmpty);
  });
}
