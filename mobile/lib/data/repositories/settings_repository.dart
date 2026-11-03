import '../database/app_database.dart';
import 'support.dart';

/// Anahtar-değer ayarlar (ör. hangi günlük alanların açık olduğu).
abstract class SettingsRepository {
  Future<String?> get(String key);
  Future<void> set(String key, String value);
  Future<Map<String, String>> getAll();
}

class DriftSettingsRepository implements SettingsRepository {
  DriftSettingsRepository(this._db, {Clock? clock})
      : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final Clock _clock;

  @override
  Future<String?> get(String key) async {
    final row = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  @override
  Future<void> set(String key, String value) async {
    await _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: key,
            value: value,
            updatedAt: _clock(),
          ),
        );
  }

  @override
  Future<Map<String, String>> getAll() async {
    final rows = await _db.select(_db.appSettings).get();
    return {for (final r in rows) r.key: r.value};
  }
}
