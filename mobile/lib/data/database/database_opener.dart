import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';

/// Şifreleme anahtarının saklandığı yer. Üretimde `flutter_secure_storage`
/// (Android Keystore); testlerde bellek içi bir uygulama kullanılabilir.
abstract class DatabaseKeyStore {
  /// Kayıtlı anahtarı (64 onaltılı karakter = 32 bayt) döndürür; yoksa
  /// üretip kaydeder.
  Future<String> readOrCreateKey();
}

class SecureStorageKeyStore implements DatabaseKeyStore {
  SecureStorageKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _keyName = 'vitapuls_db_key_v1';
  final FlutterSecureStorage _storage;

  @override
  Future<String> readOrCreateKey() async {
    final existing = await _storage.read(key: _keyName);
    if (existing != null && existing.length == 64) return existing;
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final key =
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await _storage.write(key: _keyName, value: key);
    return key;
  }

  /// Anahtarı Keystore'dan siler ("tüm veriyi sil" son çaresi). Anahtar gidince
  /// kalan şifreli dosya zaten okunamaz.
  Future<void> deleteKey() => _storage.delete(key: _keyName);
}

/// Veritabanı dosyası SQLCipher ile açılamazsa (şifreleme yok ya da anahtar
/// yanlış) fırlatılır. Şifresiz açılıp sessizce devam edilmez.
class DatabaseOpenException implements Exception {
  DatabaseOpenException(this.message);
  final String message;

  @override
  String toString() => 'DatabaseOpenException: $message';
}

/// [file] dosyasını verilen onaltılık anahtarla şifreli açar.
///
/// Anahtar ham biçimde (`x'..'`) verilir, parola türetme (KDF) atlanır; anahtar
/// zaten rastgele 32 bayttır.
AppDatabase openEncryptedDatabase(File file, String hexKey) {
  if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(hexKey)) {
    throw ArgumentError('Anahtar 64 onaltılık karakter olmalı.');
  }
  final executor = NativeDatabase.createInBackground(
    file,
    setup: (raw) {
      // SQLCipher yüklü mü? Düz SQLite'ta bu sorgu boş döner.
      final version = raw.select('PRAGMA cipher_version;');
      if (version.isEmpty) {
        throw DatabaseOpenException(
          'SQLCipher yüklenmedi; şifresiz veritabanı açılmayacak.',
        );
      }
      raw.execute("PRAGMA key = \"x'$hexKey'\";");
      // Anahtar yanlışsa (ya da dosya şifresizse) bu satır hata verir.
      try {
        raw.select('SELECT count(*) FROM sqlite_master;');
      } catch (e) {
        throw DatabaseOpenException('Veritabanı anahtarla açılamadı: $e');
      }
    },
  );
  return AppDatabase(executor);
}

const String databaseFileName = 'vitapuls.db';

/// Üretimde kullanılan açılış: uygulama belgeler klasöründe `vitapuls.db`.
Future<AppDatabase> openAppDatabase({DatabaseKeyStore? keyStore}) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, databaseFileName));
  final key = await (keyStore ?? SecureStorageKeyStore()).readOrCreateKey();
  return openEncryptedDatabase(file, key);
}

/// "Tüm veriyi sil": veritabanı dosyasını (ve `-wal`, `-shm`, `-journal` yan
/// dosyalarını) siler, sonra şifreleme anahtarını siler. Veritabanı önceden
/// kapatılmış olmalıdır. Dosyalar önce gider: anahtar silinip dosya kalırsa
/// ikisi de işe yaramaz hâle gelir, ama dosya silinemezse anahtar yerinde kalsın
/// ki hata görülüp tekrar denenebilsin.
Future<void> eraseDatabaseStorage({
  Directory? directory,
  Future<void> Function()? deleteKey,
}) async {
  final dir = directory ?? await getApplicationDocumentsDirectory();
  for (final suffix in const ['', '-wal', '-shm', '-journal']) {
    final file = File(p.join(dir.path, '$databaseFileName$suffix'));
    if (await file.exists()) await file.delete();
  }
  await (deleteKey ?? SecureStorageKeyStore().deleteKey)();
}
