import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'support.dart';

/// Tek satırlık yerel profil. Satır yoksa ilk okumada varsayılanlarla açılır.
abstract class ProfileRepository {
  Future<Profile> get();

  /// Yalnız dolu (`Value`) alanları yazar; `updatedAt` otomatik güncellenir.
  Future<Profile> save(ProfilesCompanion changes);

  /// Yerel KVKK onayını kaydeder.
  Future<void> recordConsent(DateTime at);
}

class DriftProfileRepository implements ProfileRepository {
  DriftProfileRepository(this._db, {Clock? clock, IdGenerator? newId})
      : _clock = clock ?? DateTime.now,
        _newId = newId ?? newUuid;

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _newId;

  Future<Profile?> _find() {
    return (_db.select(_db.profiles)
          ..where((t) => t.deletedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
  }

  @override
  Future<Profile> get() {
    return _db.transaction(() async {
      final existing = await _find();
      if (existing != null) return existing;
      final now = _clock();
      return _db.into(_db.profiles).insertReturning(
            ProfilesCompanion.insert(id: _newId(), createdAt: now, updatedAt: now),
          );
    });
  }

  @override
  Future<Profile> save(ProfilesCompanion changes) {
    return _db.transaction(() async {
      final current = await get();
      await (_db.update(_db.profiles)..where((t) => t.id.equals(current.id)))
          .write(changes.copyWith(updatedAt: Value(_clock())));
      return (await _find())!;
    });
  }

  @override
  Future<void> recordConsent(DateTime at) async {
    await save(ProfilesCompanion(consentAt: Value(at)));
  }
}
