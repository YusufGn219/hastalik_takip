import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'support.dart';

/// Kullanıcı tanımlı etiketler ve zaman damgalı etiket kayıtları.
abstract class TagRepository {
  Future<Tag> createTag({required String name, String kind = 'trigger'});

  /// Aktif ve silinmemiş etiketler, ada göre.
  Future<List<Tag>> listActive();

  Future<void> setActive(String tagId, bool isActive);

  Future<TagEntry> addEntry({
    required String tagId,
    required DateTime occurredAt,
    String? notes,
  });

  /// [from] ve [to] dahil, zamana göre artan.
  Future<List<TagEntry>> listEntries(DateTime from, DateTime to);

  Future<void> softDeleteEntry(String id);
}

class DriftTagRepository implements TagRepository {
  DriftTagRepository(this._db, {Clock? clock, IdGenerator? newId})
      : _clock = clock ?? DateTime.now,
        _newId = newId ?? newUuid;

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _newId;

  @override
  Future<Tag> createTag({required String name, String kind = 'trigger'}) {
    final now = _clock();
    return _db.into(_db.tags).insertReturning(
          TagsCompanion.insert(
            id: _newId(),
            createdAt: now,
            updatedAt: now,
            name: name,
            kind: Value(kind),
          ),
        );
  }

  @override
  Future<List<Tag>> listActive() {
    return (_db.select(_db.tags)
          ..where((t) => t.deletedAt.isNull() & t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  @override
  Future<void> setActive(String tagId, bool isActive) async {
    await (_db.update(_db.tags)..where((t) => t.id.equals(tagId))).write(
      TagsCompanion(isActive: Value(isActive), updatedAt: Value(_clock())),
    );
  }

  @override
  Future<TagEntry> addEntry({
    required String tagId,
    required DateTime occurredAt,
    String? notes,
  }) {
    final now = _clock();
    return _db.into(_db.tagEntries).insertReturning(
          TagEntriesCompanion.insert(
            id: _newId(),
            createdAt: now,
            updatedAt: now,
            tagId: tagId,
            occurredAt: occurredAt,
            utcOffsetMinutes: utcOffsetOf(occurredAt),
            notes: Value(notes),
          ),
        );
  }

  @override
  Future<List<TagEntry>> listEntries(DateTime from, DateTime to) {
    return (_db.select(_db.tagEntries)
          ..where(
            (t) =>
                t.deletedAt.isNull() &
                t.occurredAt.isBiggerOrEqualValue(from) &
                t.occurredAt.isSmallerOrEqualValue(to),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]))
        .get();
  }

  @override
  Future<void> softDeleteEntry(String id) async {
    final now = _clock();
    await (_db.update(_db.tagEntries)..where((t) => t.id.equals(id))).write(
      TagEntriesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }
}
