// Yedek akışının cihaza bağlanan parçaları: veritabanı dosyası ve anahtarı,
// geçici klasör, kaydetme penceresi. Testlerde sahtesi verilir.

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app/providers.dart';
import '../../data/backup/backup_service.dart';
import '../../data/database/database_opener.dart';
import 'backup_exporter.dart';

/// Yedeğin alınacağı veritabanı: dosyası, anahtarı ve geçici dosyaların yeri.
abstract class BackupStorage {
  Future<File> databaseFile();

  /// Veritabanının onaltılık anahtarı (Keystore'dan).
  Future<String> databaseKey();

  /// Yarım iş dosyaları için geçici klasör.
  Future<Directory> scratchDirectory();
}

class DeviceBackupStorage implements BackupStorage {
  const DeviceBackupStorage();

  @override
  Future<File> databaseFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, databaseFileName));
  }

  @override
  Future<String> databaseKey() => SecureStorageKeyStore().readOrCreateKey();

  @override
  Future<Directory> scratchDirectory() => getTemporaryDirectory();
}

/// Yedek dosyasını kullanıcının seçtiği yere yazar.
abstract class BackupFileSaver {
  /// Kullanıcı konumu seçip dosya yazıldıysa `true`; vazgeçtiyse `false`.
  Future<bool> save({required String fileName, required Uint8List bytes});
}

/// Android'in "farklı kaydet" penceresini açar (telefon, Drive, SD kart...).
class FilePickerBackupFileSaver implements BackupFileSaver {
  const FilePickerBackupFileSaver();

  @override
  Future<bool> save({required String fileName, required Uint8List bytes}) async {
    final path = await FilePicker.saveFile(fileName: fileName, bytes: bytes);
    return path != null;
  }
}

final backupStorageProvider = Provider<BackupStorage>((ref) => const DeviceBackupStorage());

final backupFileSaverProvider = Provider<BackupFileSaver>((ref) => const FilePickerBackupFileSaver());

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(currentSchemaVersion: ref.watch(databaseProvider).schemaVersion),
);

/// "Yedek al" işi; testlerde sahtesiyle değiştirilir.
final backupExporterProvider = Provider<BackupExporter>(
  (ref) => BackupExporter(
    service: ref.watch(backupServiceProvider),
    storage: ref.watch(backupStorageProvider),
    saver: ref.watch(backupFileSaverProvider),
    clock: ref.watch(clockProvider),
  ),
);
