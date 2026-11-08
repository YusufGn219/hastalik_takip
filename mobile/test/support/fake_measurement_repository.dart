import 'package:drift/drift.dart' show Value;
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/repositories/measurement_repository.dart';
import 'package:mobile/data/repositories/support.dart';

/// Bellek içi ölçüm deposu; ekran testlerinde gerçek veritabanı gerekmez.
/// `failLoads` / `failAdds` / `failDeletes` hata yollarını dener.
class FakeMeasurementRepository implements MeasurementRepository {
  FakeMeasurementRepository({this.failLoads = 0, this.failAdds = false, this.failDeletes = false});

  /// Sıradaki bu kadar okuma hata verir.
  int failLoads;
  bool failAdds;
  bool failDeletes;

  final rows = <Measurement>[];
  var _next = 0;

  /// Testte hazır kayıt eklemek için.
  Measurement seed(String type, double value, DateTime at, {String unit = ''}) {
    final m = Measurement(
      id: 'm${++_next}',
      createdAt: at,
      updatedAt: at,
      type: type,
      value: value,
      unit: unit,
      logDate: dayKey(at),
      measuredAt: at,
      utcOffsetMinutes: utcOffsetOf(at),
    );
    rows.add(m);
    return m;
  }

  void _maybeFailLoad() {
    if (failLoads > 0) {
      failLoads--;
      throw StateError('okunamadı');
    }
  }

  @override
  Future<Measurement> add({
    required String type,
    required double value,
    required DateTime measuredAt,
    String unit = '',
    String? notes,
  }) async {
    if (failAdds) throw StateError('yazılamadı');
    return seed(type, value, measuredAt, unit: unit);
  }

  @override
  Future<List<Measurement>> listByType(String type, {String? fromDate, String? toDate}) async {
    _maybeFailLoad();
    final list = rows.where((m) => m.deletedAt == null && m.type == type).toList()
      ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    return list;
  }

  @override
  Future<Measurement?> latest(String type) async {
    _maybeFailLoad();
    final list = rows.where((m) => m.deletedAt == null && m.type == type).toList()
      ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    return list.isEmpty ? null : list.first;
  }

  @override
  Future<void> softDelete(String id) async {
    if (failDeletes) throw StateError('silinemedi');
    final i = rows.indexWhere((m) => m.id == id);
    if (i >= 0) rows[i] = rows[i].copyWith(deletedAt: Value(DateTime(2026, 11, 8)));
  }
}
