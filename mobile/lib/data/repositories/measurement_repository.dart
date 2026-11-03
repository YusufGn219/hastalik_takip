import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'support.dart';

/// Genel ölçümler: günlük tetikleyiciler (stres, kafein...) ve vücut ölçüleri.
abstract class MeasurementRepository {
  /// [type] için bkz. `MeasurementTypes`. Ölçümün günü [measuredAt]'in yerel
  /// gününden türetilir.
  Future<Measurement> add({
    required String type,
    required double value,
    required DateTime measuredAt,
    String unit = '',
    String? notes,
  });

  /// Tür için ölçümler, zamana göre artan. [fromDate]/[toDate] dahil ('YYYY-MM-DD').
  Future<List<Measurement>> listByType(
    String type, {
    String? fromDate,
    String? toDate,
  });

  /// Türün en son ölçümü (yoksa null).
  Future<Measurement?> latest(String type);

  Future<void> softDelete(String id);
}

class DriftMeasurementRepository implements MeasurementRepository {
  DriftMeasurementRepository(this._db, {Clock? clock, IdGenerator? newId})
      : _clock = clock ?? DateTime.now,
        _newId = newId ?? newUuid;

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _newId;

  @override
  Future<Measurement> add({
    required String type,
    required double value,
    required DateTime measuredAt,
    String unit = '',
    String? notes,
  }) {
    final now = _clock();
    return _db.into(_db.measurements).insertReturning(
          MeasurementsCompanion.insert(
            id: _newId(),
            createdAt: now,
            updatedAt: now,
            type: type,
            value: value,
            unit: Value(unit),
            logDate: dayKey(measuredAt),
            measuredAt: measuredAt,
            utcOffsetMinutes: utcOffsetOf(measuredAt),
            notes: Value(notes),
          ),
        );
  }

  @override
  Future<List<Measurement>> listByType(
    String type, {
    String? fromDate,
    String? toDate,
  }) {
    return (_db.select(_db.measurements)
          ..where((t) {
            var condition = t.deletedAt.isNull() & t.type.equals(type);
            if (fromDate != null) {
              condition = condition & t.logDate.isBiggerOrEqualValue(fromDate);
            }
            if (toDate != null) {
              condition = condition & t.logDate.isSmallerOrEqualValue(toDate);
            }
            return condition;
          })
          ..orderBy([(t) => OrderingTerm.asc(t.measuredAt)]))
        .get();
  }

  @override
  Future<Measurement?> latest(String type) {
    return (_db.select(_db.measurements)
          ..where((t) => t.deletedAt.isNull() & t.type.equals(type))
          ..orderBy([(t) => OrderingTerm.desc(t.measuredAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  @override
  Future<void> softDelete(String id) async {
    final now = _clock();
    await (_db.update(_db.measurements)..where((t) => t.id.equals(id))).write(
      MeasurementsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }
}
