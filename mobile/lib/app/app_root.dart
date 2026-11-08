// Uygulamanın kökü: veritabanını ve kilidin ihtiyaç duyduğu parçaları sağlar.
//
// "Tüm veriyi sil" son çaresinden sonra uygulamanın boş bir veritabanıyla baştan
// kurulması gerekir; bunu kök yapar (`appRestartProvider`): eski ProviderScope
// atılır, yenisi yeni veritabanıyla kurulur.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database/app_database.dart';
import '../features/lock/app_lock_platform.dart';
import '../features/lock/app_lock_store.dart';
import 'database_error_app.dart';
import 'database_swapper.dart';
import 'providers.dart';

/// "Tüm veriyi sil" uygulaması: açık veritabanını kapatır, dosyaları ve anahtarı
/// siler, sonra boş yeni bir veritabanı açtırır.
class AppDataWiper implements DataWiper {
  AppDataWiper({
    required this.closeCurrent,
    required this.erase,
    required this.openFresh,
  });

  final Future<void> Function() closeCurrent;
  final Future<void> Function() erase;
  final Future<void> Function() openFresh;

  @override
  Future<void> wipe() async {
    await closeCurrent();
    await erase();
    await openFresh();
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({
    super.key,
    required this.database,
    required this.prefs,
    required this.openDatabase,
    required this.eraseStorage,
    required this.child,
    this.overrides = const [],
    this.onDatabaseReplaced,
  });

  /// Açılışta açılmış veritabanı.
  final AppDatabase database;
  final SharedPreferences prefs;

  /// Boş (ve tohum verisi yüklenmiş) yeni veritabanı açar.
  final Future<AppDatabase> Function() openDatabase;

  /// Veritabanı dosyalarını ve anahtarı siler.
  final Future<void> Function() eraseStorage;

  final Widget child;

  /// Ek geçersiz kılmalar (parmak izi, ekran güvenliği gibi platform parçaları).
  final List<Override> overrides;

  /// Yedekten geri yükleme sonrası, yeni veritabanı açılınca çağrılır (ör. planlı
  /// bildirimleri yeni veriye göre baştan kurmak). Hatası geri yüklemeyi bozmaz.
  final Future<void> Function(AppDatabase db)? onDatabaseReplaced;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  late AppDatabase _db = widget.database;
  int _generation = 0;

  /// Geri yükleme sonrası veritabanı yeniden açılamadıysa true: uygulama devam
  /// edemez, hata ekranı gösterilir.
  bool _openFailed = false;
  late final AppDataWiper _wiper = AppDataWiper(
    closeCurrent: () => _db.close(),
    erase: () => widget.eraseStorage(),
    openFresh: () async => _db = await widget.openDatabase(),
  );

  late final AppDatabaseSwapper _swapper = AppDatabaseSwapper(
    closeCurrent: () => _db.close(),
    openFresh: () async {
      try {
        _db = await widget.openDatabase();
      } catch (_) {
        if (mounted) setState(() => _openFailed = true);
        rethrow;
      }
    },
    afterReplaced: () async {
      try {
        await widget.onDatabaseReplaced?.call(_db);
      } catch (_) {
        // Bildirimlerin kurulamaması geri yüklemeyi geri almaz.
      }
    },
  );

  Future<void> _restart() async {
    if (!mounted) return;
    setState(() => _generation++);
  }

  @override
  void dispose() {
    _db.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_openFailed) return const DatabaseErrorApp();
    return ProviderScope(
      key: ValueKey(_generation),
      overrides: [
        databaseProvider.overrideWithValue(_db),
        sharedPreferencesProvider.overrideWithValue(widget.prefs),
        dataWiperProvider.overrideWithValue(_wiper),
        databaseSwapperProvider.overrideWithValue(_swapper),
        appRestartProvider.overrideWithValue(_restart),
        ...widget.overrides,
      ],
      child: widget.child,
    );
  }
}
