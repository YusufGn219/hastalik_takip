import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/enums.dart';
import 'support.dart';

/// Döngü takibi: adet dönemleri, günlük akış ve isteğe bağlı durum bilgisi.
/// Döngü günü, ortalama uzunluk ve tahmin burada saklanmaz; Sprint 8'de
/// hesaplanır.
abstract class CycleRepository {
  /// [startDate] 'YYYY-MM-DD'.
  Future<CyclePeriod> startPeriod({required String startDate, String? notes});
  Future<void> endPeriod(String id, String endDate);

  /// Başlangıç tarihine göre yeni olan önce.
  Future<List<CyclePeriod>> listPeriods();

  /// Gün için akışı ekler ya da değiştirir (günde tek kayıt).
  Future<CycleFlow> setFlow({
    required String flowDate,
    required FlowIntensity intensity,
    String? periodId,
  });

  /// [fromDate] ve [toDate] dahil, tarihe göre artan.
  Future<List<CycleFlow>> listFlows(String fromDate, String toDate);

  Future<CycleStatusRecord> addStatus({
    required CycleStatusKind kind,
    required String startDate,
    String? endDate,
  });
  Future<void> endStatus(String id, String endDate);
  Future<List<CycleStatusRecord>> listStatuses();

  Future<void> softDeletePeriod(String id);
}

class DriftCycleRepository implements CycleRepository {
  DriftCycleRepository(this._db, {Clock? clock, IdGenerator? newId})
      : _clock = clock ?? DateTime.now,
        _newId = newId ?? newUuid;

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _newId;

  @override
  Future<CyclePeriod> startPeriod({
    required String startDate,
    String? notes,
  }) {
    final now = _clock();
    return _db.into(_db.cyclePeriods).insertReturning(
          CyclePeriodsCompanion.insert(
            id: _newId(),
            createdAt: now,
            updatedAt: now,
            startDate: startDate,
            notes: Value(notes),
          ),
        );
  }

  @override
  Future<void> endPeriod(String id, String endDate) async {
    await (_db.update(_db.cyclePeriods)..where((t) => t.id.equals(id))).write(
      CyclePeriodsCompanion(
        endDate: Value(endDate),
        updatedAt: Value(_clock()),
      ),
    );
  }

  @override
  Future<List<CyclePeriod>> listPeriods() {
    return (_db.select(_db.cyclePeriods)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.startDate)]))
        .get();
  }

  @override
  Future<CycleFlow> setFlow({
    required String flowDate,
    required FlowIntensity intensity,
    String? periodId,
  }) {
    return _db.transaction(() async {
      final now = _clock();
      final existing = await (_db.select(_db.cycleFlows)
            ..where((t) => t.deletedAt.isNull() & t.flowDate.equals(flowDate)))
          .getSingleOrNull();
      if (existing == null) {
        return _db.into(_db.cycleFlows).insertReturning(
              CycleFlowsCompanion.insert(
                id: _newId(),
                createdAt: now,
                updatedAt: now,
                flowDate: flowDate,
                intensity: intensity,
                periodId: Value(periodId),
              ),
            );
      }
      await (_db.update(_db.cycleFlows)..where((t) => t.id.equals(existing.id)))
          .write(
        CycleFlowsCompanion(
          intensity: Value(intensity),
          periodId: Value(periodId),
          updatedAt: Value(now),
        ),
      );
      return (await (_db.select(_db.cycleFlows)
            ..where((t) => t.id.equals(existing.id)))
          .getSingle());
    });
  }

  @override
  Future<List<CycleFlow>> listFlows(String fromDate, String toDate) {
    return (_db.select(_db.cycleFlows)
          ..where(
            (t) =>
                t.deletedAt.isNull() &
                t.flowDate.isBiggerOrEqualValue(fromDate) &
                t.flowDate.isSmallerOrEqualValue(toDate),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.flowDate)]))
        .get();
  }

  @override
  Future<CycleStatusRecord> addStatus({
    required CycleStatusKind kind,
    required String startDate,
    String? endDate,
  }) {
    final now = _clock();
    return _db.into(_db.cycleStatuses).insertReturning(
          CycleStatusesCompanion.insert(
            id: _newId(),
            createdAt: now,
            updatedAt: now,
            kind: kind,
            startDate: startDate,
            endDate: Value(endDate),
          ),
        );
  }

  @override
  Future<void> endStatus(String id, String endDate) async {
    await (_db.update(_db.cycleStatuses)..where((t) => t.id.equals(id))).write(
      CycleStatusesCompanion(
        endDate: Value(endDate),
        updatedAt: Value(_clock()),
      ),
    );
  }

  @override
  Future<List<CycleStatusRecord>> listStatuses() {
    return (_db.select(_db.cycleStatuses)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.startDate)]))
        .get();
  }

  @override
  Future<void> softDeletePeriod(String id) async {
    final now = _clock();
    await (_db.update(_db.cyclePeriods)..where((t) => t.id.equals(id))).write(
      CyclePeriodsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }
}
