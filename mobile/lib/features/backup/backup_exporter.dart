// "Yedek al" işi: veritabanını parolayla şifreli geçici dosyaya yazar, kullanıcının
// seçtiği yere kaydettirir, geçici dosyayı siler. Ekrandan bağımsızdır (test için).

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../data/backup/backup_service.dart';
import 'backup_platform.dart';

enum BackupExportResult {
  /// Dosya kullanıcının seçtiği yere yazıldı.
  saved,

  /// Kullanıcı konum seçmekten vazgeçti; yedek alınmadı.
  cancelled,
}

class BackupExporter {
  BackupExporter({
    required this.service,
    required this.storage,
    required this.saver,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final BackupService service;
  final BackupStorage storage;
  final BackupFileSaver saver;
  final DateTime Function() _clock;

  /// Yedek dosyasının önerilen adı: `vitapuls-yedek-2026-11-08-1155.vpbak`.
  static String fileNameFor(DateTime now) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'vitapuls-yedek-${now.year}-${two(now.month)}-${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}.vpbak';
  }

  /// Hata olursa [BackupException] ya da [FileSystemException] fırlatır; geçici
  /// dosya her durumda silinir.
  Future<BackupExportResult> run(String passphrase) async {
    final database = await storage.databaseFile();
    final key = await storage.databaseKey();
    final scratch = await storage.scratchDirectory();
    final name = fileNameFor(_clock());
    final temp = File(p.join(scratch.path, name));
    try {
      await service.export(database: database, hexKey: key, target: temp, passphrase: passphrase);
      final bytes = await temp.readAsBytes();
      final saved = await saver.save(fileName: name, bytes: bytes);
      return saved ? BackupExportResult.saved : BackupExportResult.cancelled;
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }
}
