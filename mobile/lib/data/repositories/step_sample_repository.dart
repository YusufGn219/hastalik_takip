import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'support.dart';

/// Adım sayacı okumaları (ham sayaç değeri + zaman). Bkz. `StepSamples`.
abstract class StepSampleRepository {
  Future<StepSample> add({
    required int counter,
    required int? bootCount,
    required int uptimeMs,
    required DateTime sampledAt,
    required String source,
  });

  /// [from] dahil, [to] hariç aralıktaki okumalar, eskiden yeniye.
  Future<List<StepSample>> listBetween(DateTime from, DateTime to);

  /// [instant]'tan KESİN önceki en son okuma (yoksa null).
  Future<StepSample?> latestBefore(DateTime instant);

  /// [instant] ve sonrasındaki ilk okuma (yoksa null).
  Future<StepSample?> firstAtOrAfter(DateTime instant);

  /// En son okuma (yoksa null).
  Future<StepSample?> latest();
}

class DriftStepSampleRepository implements StepSampleRepository {
  DriftStepSampleRepository(this._db, {Clock? clock, IdGenerator? newId})
      : _clock = clock ?? DateTime.now,
        _newId = newId ?? newUuid;

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _newId;

  @override
  Future<StepSample> add({
    required int counter,
    required int? bootCount,
    required int uptimeMs,
    required DateTime sampledAt,
    required String source,
  }) {
    final now = _clock();
    return _db.into(_db.stepSamples).insertReturning(
          StepSamplesCompanion.insert(
            id: _newId(),
            createdAt: now,
            updatedAt: now,
            counter: counter,
            bootCount: Value(bootCount),
            uptimeMs: uptimeMs,
            sampledAt: sampledAt,
            utcOffsetMinutes: utcOffsetOf(sampledAt),
            logDate: dayKey(sampledAt),
            source: source,
          ),
        );
  }

  @override
  Future<List<StepSample>> listBetween(DateTime from, DateTime to) {
    return (_db.select(_db.stepSamples)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.sampledAt.isBiggerOrEqualValue(from) &
              t.sampledAt.isSmallerThanValue(to))
          ..orderBy([(t) => OrderingTerm.asc(t.sampledAt)]))
        .get();
  }

  @override
  Future<StepSample?> latestBefore(DateTime instant) {
    return (_db.select(_db.stepSamples)
          ..where((t) => t.deletedAt.isNull() & t.sampledAt.isSmallerThanValue(instant))
          ..orderBy([(t) => OrderingTerm.desc(t.sampledAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  @override
  Future<StepSample?> firstAtOrAfter(DateTime instant) {
    return (_db.select(_db.stepSamples)
          ..where((t) => t.deletedAt.isNull() & t.sampledAt.isBiggerOrEqualValue(instant))
          ..orderBy([(t) => OrderingTerm.asc(t.sampledAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  @override
  Future<StepSample?> latest() {
    return (_db.select(_db.stepSamples)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.sampledAt)])
          ..limit(1))
        .getSingleOrNull();
  }
}
