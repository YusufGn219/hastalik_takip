import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'support.dart';

abstract class SymptomRepository {
  /// Silinmemiş semptomlar, ada göre.
  Future<List<Symptom>> listActive();
  Future<Symptom?> getById(String id);

  /// Kullanıcının kendi semptomunu ekler.
  Future<Symptom> createCustom({
    required String name,
    String category = 'genel',
    String description = '',
  });

  Future<void> softDelete(String id);
}

class DriftSymptomRepository implements SymptomRepository {
  DriftSymptomRepository(this._db, {Clock? clock, IdGenerator? newId})
      : _clock = clock ?? DateTime.now,
        _newId = newId ?? newUuid;

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _newId;

  @override
  Future<List<Symptom>> listActive() {
    return (_db.select(_db.symptoms)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  @override
  Future<Symptom?> getById(String id) {
    return (_db.select(_db.symptoms)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<Symptom> createCustom({
    required String name,
    String category = 'genel',
    String description = '',
  }) {
    final now = _clock();
    return _db.into(_db.symptoms).insertReturning(
          SymptomsCompanion.insert(
            id: _newId(),
            createdAt: now,
            updatedAt: now,
            name: name,
            category: Value(category),
            description: Value(description),
            isCustom: const Value(true),
          ),
        );
  }

  @override
  Future<void> softDelete(String id) async {
    final now = _clock();
    await (_db.update(_db.symptoms)..where((t) => t.id.equals(id))).write(
      SymptomsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }
}
