import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'support.dart';

/// Ek günlük alanlarının tanımları. Doğrulama servisin işidir; depo yazar ve
/// okur. Değerler burada değil `measurements` içinde tutulur.
abstract class DailyFieldRepository {
  /// Silinmemiş tüm alanlar (kapalılar dahil), sıraya göre.
  Future<List<DailyField>> listAll();

  Future<DailyField?> getById(String id);

  Future<DailyField> insert({
    required String name,
    required String kind,
    required String unit,
    required double minValue,
    required double maxValue,
    required bool isActive,
    required int sortOrder,
    String? builtinKey,
  });

  /// Verilen sütunları yazar, `updatedAt`'i tazeler; güncel satırı döner.
  Future<DailyField> update(String id, DailyFieldsCompanion changes);
}

class DriftDailyFieldRepository implements DailyFieldRepository {
  DriftDailyFieldRepository(this._db, {Clock? clock, IdGenerator? newId})
      : _clock = clock ?? DateTime.now,
        _newId = newId ?? newUuid;

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _newId;

  @override
  Future<List<DailyField>> listAll() {
    return (_db.select(_db.dailyFields)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .get();
  }

  @override
  Future<DailyField?> getById(String id) {
    return (_db.select(_db.dailyFields)
          ..where((t) => t.deletedAt.isNull() & t.id.equals(id)))
        .getSingleOrNull();
  }

  @override
  Future<DailyField> insert({
    required String name,
    required String kind,
    required String unit,
    required double minValue,
    required double maxValue,
    required bool isActive,
    required int sortOrder,
    String? builtinKey,
  }) {
    final now = _clock();
    return _db.into(_db.dailyFields).insertReturning(
          DailyFieldsCompanion.insert(
            id: _newId(),
            createdAt: now,
            updatedAt: now,
            name: name,
            kind: kind,
            unit: Value(unit),
            minValue: minValue,
            maxValue: maxValue,
            isActive: Value(isActive),
            sortOrder: Value(sortOrder),
            builtinKey: Value(builtinKey),
          ),
        );
  }

  @override
  Future<DailyField> update(String id, DailyFieldsCompanion changes) async {
    await (_db.update(_db.dailyFields)..where((t) => t.id.equals(id))).write(
      changes.copyWith(updatedAt: Value(_clock())),
    );
    return (_db.select(_db.dailyFields)..where((t) => t.id.equals(id)))
        .getSingle();
  }
}
