// "Yedekten geri yükle" işi: yedeği önce **veritabanına dokunmadan** denetler
// (parola, sürüm, bütünlük); sorun yoksa veritabanını kapatıp değiştirir ve yeniden
// açar. Ekrandan bağımsızdır (test için).

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../app/database_swapper.dart';
import '../../data/backup/backup_service.dart';
import 'backup_platform.dart';

class BackupRestorer {
  BackupRestorer({
    required this.service,
    required this.storage,
    required this.swapper,
  });

  final BackupService service;
  final BackupStorage storage;
  final DatabaseSwapper swapper;

  /// Yedeği veritabanına dokunmadan denetler (parola, sürüm, bütünlük). Ekran,
  /// "silinecek" uyarısını göstermeden önce yanlış parolayı yakalamak için kullanır.
  Future<void> verify({required File backup, required String passphrase}) =>
      service.verify(backup: backup, passphrase: passphrase);

  /// Hata olursa [BackupException] fırlatır; denetim aşamasında olursa mevcut
  /// veritabanı hiç kapatılmaz. Başarıda veritabanı yeni içerikle açıktır;
  /// uygulamanın baştan kurulması çağırana kalır.
  Future<void> run({required File backup, required String passphrase}) async {
    await service.verify(backup: backup, passphrase: passphrase);
    final database = await storage.databaseFile();
    final key = await storage.databaseKey();
    await swapper.swap(
      () => service.restore(
        backup: backup,
        passphrase: passphrase,
        database: database,
        hexKey: key,
      ),
    );
  }

  /// Dosya seçici Android'de seçilen dosyayı uygulama önbelleğine kopyalar; iş
  /// bitince o kopyayı siler. Kullanıcının kendi dosyasına (önbellek dışı)
  /// dokunmaz.
  Future<void> discardPickedCopy(File file) async {
    final scratch = await storage.scratchDirectory();
    if (p.isWithin(scratch.path, file.path) && await file.exists()) {
      await file.delete();
    }
  }
}
