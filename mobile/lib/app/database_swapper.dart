// Veritabanı dosyasını uygulama açıkken değiştirmek gerekince (yedekten geri
// yükleme): açık veritabanı kapatılır, iş yapılır, veritabanı yeniden açılır.
// Gerçeğini `AppRoot` verir; `appRestartProvider` ile birlikte kullanılır.

import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class DatabaseSwapper {
  /// Veritabanını kapatır, [action]'ı çalıştırır, veritabanını (başarılı olsa da
  /// olmasa da) yeniden açar. [action] hata verirse hata yukarı çıkar; eski
  /// dosya yerindedir ve yeniden açılır. Yalnız başarıda "veritabanı değişti"
  /// bildirimi çalışır.
  Future<void> swap(Future<void> Function() action);
}

class UnconfiguredDatabaseSwapper implements DatabaseSwapper {
  const UnconfiguredDatabaseSwapper();

  @override
  Future<void> swap(Future<void> Function() action) =>
      throw StateError('databaseSwapperProvider geçersiz kılınmadı.');
}

final databaseSwapperProvider = Provider<DatabaseSwapper>((ref) => const UnconfiguredDatabaseSwapper());

class AppDatabaseSwapper implements DatabaseSwapper {
  AppDatabaseSwapper({
    required this.closeCurrent,
    required this.openFresh,
    this.afterReplaced,
  });

  final Future<void> Function() closeCurrent;
  final Future<void> Function() openFresh;

  /// Yalnız [swap] başarılıysa, yeni veritabanı açıldıktan sonra çalışır
  /// (ör. hatırlatmaları yeniden kurmak).
  final Future<void> Function()? afterReplaced;

  @override
  Future<void> swap(Future<void> Function() action) async {
    await closeCurrent();
    var succeeded = false;
    try {
      await action();
      succeeded = true;
    } finally {
      await openFresh();
    }
    if (succeeded) await afterReplaced?.call();
  }
}
