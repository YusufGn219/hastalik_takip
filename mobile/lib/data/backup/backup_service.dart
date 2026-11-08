// Şifreli yedek: veritabanının, kullanıcının verdiği yedek parolasıyla şifrelenmiş
// tek dosyalık kopyası.
//
// Neden yeniden şifreleme: uygulamanın veritabanı anahtarı telefonun güvenli
// deposunda (Keystore) durur ve başka cihaza geçmez. Yedek dosyası ise tek başına,
// yalnız parolayla açılabilmelidir. Bu yüzden dışa aktarırken veri SQLCipher'in
// `sqlcipher_export` işleviyle parolalı yeni bir dosyaya kopyalanır; içe
// aktarırken bunun tersi yapılır: yedek parolayla açılır, bu cihazın anahtarıyla
// yeni bir veritabanı dosyasına kopyalanır, sonra eskisinin yerine geçirilir.
//
// Biçim kararı (2026-11-08): yedek, SQLCipher dosyasının kendisidir; ayrı bir kap
// biçimi yoktur. Şema sürümü dosyadaki `user_version` değeridir. İçe aktarma
// **birleştirmez, değiştirir**.
//
// Parola unutulursa yedek açılamaz; kurtarma yolu yoktur.
//
// Ağır iş (parola türetme ~yüz binlerce tur) ayrı bir isolate'ta çalışır.

import 'dart:io';
import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart';

/// Yedek işleminin neden başarısız olduğu.
enum BackupFailure {
  /// Parola yanlış ya da dosya bozuk/şifresiz (ikisi birbirinden ayırt edilemez).
  wrongPassphraseOrCorrupt,

  /// Yedek, bu uygulamanın bildiğinden daha yeni bir şema sürümünden.
  newerVersion,

  /// Dosya açıldı ama Vitapuls yedeği değil (beklenen tablolar yok).
  notABackup,

  /// Dosya okunamadı/yazılamadı ya da doğrulama tutmadı.
  io,
}

class BackupException implements Exception {
  BackupException(this.failure, [this.detail = '']);

  final BackupFailure failure;
  final String detail;

  @override
  String toString() => 'BackupException(${failure.name}): $detail';
}

class BackupService {
  BackupService({required this.currentSchemaVersion});

  /// Bu uygulamanın veritabanı şema sürümü (`AppDatabase.schemaVersion`).
  final int currentSchemaVersion;

  /// Yedek parolasının en kısa uzunluğu.
  static const int minPassphraseLength = 8;

  /// Dışa aktarma: [database] dosyasını (anahtarı [hexKey]) [passphrase] ile
  /// şifreli olarak [target] dosyasına yazar. Veritabanı açık olabilir.
  /// Hedef ancak tamamen yazılıp doğrulandıktan sonra yerine konur; hata olursa
  /// hedefte yarım dosya kalmaz.
  Future<void> export({
    required File database,
    required String hexKey,
    required File target,
    required String passphrase,
  }) {
    _checkPassphrase(passphrase);
    _checkHexKey(hexKey);
    final src = database.path;
    final dst = target.path;
    return Isolate.run(() => _exportSync(src, hexKey, dst, passphrase));
  }

  /// İçe aktarma: [backup] dosyasını [passphrase] ile açar, doğrular ve
  /// [database] dosyasının **yerine** koyar (bu cihazın [hexKey] anahtarıyla).
  /// Veritabanı çağrıdan önce kapatılmış olmalıdır. Hata olursa eski veritabanı
  /// olduğu gibi kalır.
  Future<void> restore({
    required File backup,
    required String passphrase,
    required File database,
    required String hexKey,
  }) {
    _checkHexKey(hexKey);
    final src = backup.path;
    final dst = database.path;
    final version = currentSchemaVersion;
    return Isolate.run(() => _restoreSync(src, passphrase, dst, hexKey, version));
  }
}

void _checkPassphrase(String passphrase) {
  if (passphrase.runes.length < BackupService.minPassphraseLength) {
    throw ArgumentError(
      'Yedek parolası en az ${BackupService.minPassphraseLength} karakter olmalı.',
    );
  }
}

void _checkHexKey(String hexKey) {
  if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(hexKey)) {
    throw ArgumentError('Anahtar 64 onaltılık karakter olmalı.');
  }
}

/// Yedekte bulunması gereken tablolar (Vitapuls yedeği mi, kaba kontrol).
const _requiredTables = {
  'app_settings',
  'symptoms',
  'episodes',
  'daily_logs',
  'medications',
  'medication_logs',
};

String _quoted(String value) => "'${value.replaceAll("'", "''")}'";

/// Ham 32 baytlık anahtar (parola türetme yok): SQLCipher'in `x'..'` biçimi.
String _rawKeyText(String hexKey) => "x'$hexKey'";

/// Şifreli dosyayı açar ve anahtarın doğru olduğunu bir sorguyla sınar.
/// Anahtar yanlışsa ya da dosya şifreli değilse [SqliteException] fırlar.
Database _openKeyed(String path, String keySqlLiteral) {
  final db = sqlite3.open(path);
  try {
    if (db.select('PRAGMA cipher_version;').isEmpty) {
      throw BackupException(BackupFailure.io, 'SQLCipher yüklenmedi.');
    }
    db.execute('PRAGMA key = $keySqlLiteral;');
    db.select('SELECT count(*) FROM sqlite_master;');
    return db;
  } catch (_) {
    db.close();
    rethrow;
  }
}

int _userVersion(Database db, [String schema = 'main']) =>
    db.select('PRAGMA $schema.user_version;').first.values.first as int;

Set<String> _tableNames(Database db) => {
      for (final row in db.select("SELECT name FROM sqlite_master WHERE type = 'table';"))
        row['name'] as String,
    };

void _deleteIfExists(String path) {
  final file = File(path);
  if (file.existsSync()) file.deleteSync();
}

void _deleteSidecars(String dbPath) {
  for (final suffix in const ['-wal', '-shm', '-journal']) {
    _deleteIfExists('$dbPath$suffix');
  }
}

void _exportSync(String sourcePath, String hexKey, String targetPath, String passphrase) {
  final tmp = '$targetPath.tmp';
  _deleteIfExists(tmp);
  Database? source;
  try {
    if (!File(sourcePath).existsSync()) {
      throw BackupException(BackupFailure.io, 'Veritabanı dosyası yok.');
    }
    source = _openKeyed(sourcePath, '"${_rawKeyText(hexKey)}"');
    final version = _userVersion(source);
    source.execute('ATTACH DATABASE ? AS backup KEY ?;', [tmp, passphrase]);
    source.select("SELECT sqlcipher_export('backup');");
    // `sqlcipher_export` şema sürümünü kopyalamaz.
    source.execute('PRAGMA backup.user_version = $version;');
    source.execute('DETACH DATABASE backup;');
    source.close();
    source = null;

    // Yazılan dosya gerçekten parolayla açılıyor ve aynı sürümde mi?
    final check = _openKeyed(tmp, _quoted(passphrase));
    try {
      if (_userVersion(check) != version || !_tableNames(check).containsAll(_requiredTables)) {
        throw BackupException(BackupFailure.io, 'Yedek doğrulaması tutmadı.');
      }
    } finally {
      check.close();
    }

    _deleteIfExists(targetPath);
    File(tmp).renameSync(targetPath);
  } on SqliteException catch (e) {
    throw BackupException(BackupFailure.io, e.message);
  } on FileSystemException catch (e) {
    throw BackupException(BackupFailure.io, e.message);
  } finally {
    source?.close();
    _deleteIfExists(tmp);
    _deleteSidecars(tmp);
  }
}

void _restoreSync(
  String backupPath,
  String passphrase,
  String dbPath,
  String hexKey,
  int currentVersion,
) {
  final tmp = '$dbPath.restore.tmp';
  final old = '$dbPath.restore.old';

  // Önceki bir geri yükleme takasın ortasında kesildiyse: ana dosya yok, eskisi
  // duruyor; önce onu yerine koy.
  if (!File(dbPath).existsSync() && File(old).existsSync()) {
    File(old).renameSync(dbPath);
  }
  _deleteIfExists(old);
  _deleteIfExists(tmp);
  _deleteSidecars(tmp);

  Database? backup;
  try {
    if (!File(backupPath).existsSync()) {
      throw BackupException(BackupFailure.io, 'Yedek dosyası yok.');
    }
    try {
      backup = _openKeyed(backupPath, _quoted(passphrase));
    } on SqliteException catch (e) {
      throw BackupException(BackupFailure.wrongPassphraseOrCorrupt, e.message);
    }

    final version = _userVersion(backup);
    if (version > currentVersion) {
      throw BackupException(
        BackupFailure.newerVersion,
        'Yedek sürümü $version, uygulama sürümü $currentVersion.',
      );
    }
    if (version < 1 || !_tableNames(backup).containsAll(_requiredTables)) {
      throw BackupException(BackupFailure.notABackup, 'Beklenen tablolar yok.');
    }
    final integrity = backup.select('PRAGMA integrity_check;');
    if (integrity.isEmpty || integrity.first.values.first != 'ok') {
      throw BackupException(BackupFailure.wrongPassphraseOrCorrupt, 'Bütünlük denetimi başarısız.');
    }

    backup.execute('ATTACH DATABASE ? AS target KEY ?;', [tmp, _rawKeyText(hexKey)]);
    backup.select("SELECT sqlcipher_export('target');");
    backup.execute('PRAGMA target.user_version = $version;');
    backup.execute('DETACH DATABASE target;');
    backup.close();
    backup = null;

    // Yeni dosya bu cihazın anahtarıyla açılıyor mu?
    final check = _openKeyed(tmp, '"${_rawKeyText(hexKey)}"');
    try {
      if (_userVersion(check) != version || !_tableNames(check).containsAll(_requiredTables)) {
        throw BackupException(BackupFailure.io, 'Geri yükleme doğrulaması tutmadı.');
      }
    } finally {
      check.close();
    }

    // Takas: eski dosya kenara, yenisi yerine; olmazsa eskisi geri.
    final hadOld = File(dbPath).existsSync();
    if (hadOld) File(dbPath).renameSync(old);
    try {
      File(tmp).renameSync(dbPath);
    } catch (e) {
      if (hadOld) File(old).renameSync(dbPath);
      throw BackupException(BackupFailure.io, 'Dosya yerine konamadı: $e');
    }
    // Eski veritabanının artık anlamsız yan dosyaları yeni dosyayı bozmasın.
    _deleteSidecars(dbPath);
    _deleteIfExists(old);
  } on SqliteException catch (e) {
    throw BackupException(BackupFailure.io, e.message);
  } on FileSystemException catch (e) {
    throw BackupException(BackupFailure.io, e.message);
  } finally {
    backup?.close();
    _deleteIfExists(tmp);
    _deleteSidecars(tmp);
  }
}
