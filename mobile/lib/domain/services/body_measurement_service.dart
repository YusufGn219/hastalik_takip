// Vücut ölçüleri: boy ve kilo. Genel `measurements` tablosunu kullanır
// (tür: `MeasurementTypes.height` / `weight`). Kilo her girişte tarihli bir
// kayıttır (geçmiş ve grafik); boy nadiren değişir, her değişiklik yeni bir kayıt
// olur ve "güncel boy" en sonuncusudur. Hesaplanan değer (VKİ vb.) yazılmaz.

import '../../data/database/app_database.dart';
import '../../data/database/enums.dart';
import '../../data/repositories/measurement_repository.dart';
import '../../data/repositories/support.dart';
import '../errors.dart';
import '../local_day.dart';

/// Ekranın tek seferde okuduğu görünüm.
class BodyMeasurements {
  const BodyMeasurements({required this.height, required this.weights});

  /// Güncel boy (cm); hiç girilmediyse null.
  final Measurement? height;

  /// Kilo kayıtları, en yeni önce.
  final List<Measurement> weights;

  Measurement? get latestWeight => weights.isEmpty ? null : weights.first;
}

class BodyMeasurementService {
  BodyMeasurementService({
    required MeasurementRepository measurements,
    required Clock clock,
  })  : _measurements = measurements,
        _clock = clock;

  final MeasurementRepository _measurements;
  final Clock _clock;

  static const minHeightCm = 50.0;
  static const maxHeightCm = 250.0;
  static const minWeightKg = 2.0;
  static const maxWeightKg = 500.0;

  /// En eski kabul edilen ölçüm yılı.
  static const minYear = 1900;

  Future<BodyMeasurements> overview() async {
    final height = await _measurements.latest(MeasurementTypes.height);
    final weights = await _measurements.listByType(MeasurementTypes.weight);
    return BodyMeasurements(height: height, weights: weights.reversed.toList());
  }

  /// Boyu (cm) kaydeder. Güncel boyla aynıysa yeni kayıt açılmaz. Aralık dışıysa
  /// [RuleViolation] ([RuleCodes.heightOutOfRange]).
  Future<void> saveHeight(double cm) async {
    final value = _round(cm);
    if (!value.isFinite || value < minHeightCm || value > maxHeightCm) {
      throw RuleViolation(RuleCodes.heightOutOfRange,
          'Boy $minHeightCm-$maxHeightCm cm arasında olmalı: $cm');
    }
    final current = await _measurements.latest(MeasurementTypes.height);
    if (current != null && current.value == value) return;
    await _measurements.add(
      type: MeasurementTypes.height,
      value: value,
      unit: 'cm',
      measuredAt: _clock(),
    );
  }

  /// Kilo (kg) ekler. [day] 'YYYY-MM-DD'; boşsa bugün. Gün gelecekteyse ya da
  /// geçersizse, kilo aralık dışıysa [RuleViolation].
  Future<Measurement> addWeight({required double kg, String? day}) async {
    final value = _round(kg);
    if (!value.isFinite || value < minWeightKg || value > maxWeightKg) {
      throw RuleViolation(RuleCodes.weightOutOfRange,
          'Kilo $minWeightKg-$maxWeightKg kg arasında olmalı: $kg');
    }
    final now = _clock();
    final today = formatDay(now.year, now.month, now.day);
    final chosen = day ?? today;
    final parsed = _parseDay(chosen);
    if (parsed == null) {
      throw RuleViolation(RuleCodes.measurementDayInvalid, 'Geçersiz gün: $chosen');
    }
    if (chosen.compareTo(today) > 0) {
      throw RuleViolation(RuleCodes.measurementDayInFuture, 'Gelecek gün: $chosen');
    }
    // Bugünse şimdiki an; geçmiş gün için yerel öğlen (saat bilgisi yok).
    final measuredAt = chosen == today ? now : DateTime(parsed.year, parsed.month, parsed.day, 12);
    return _measurements.add(
      type: MeasurementTypes.weight,
      value: value,
      unit: 'kg',
      measuredAt: measuredAt,
    );
  }

  Future<void> deleteWeight(String id) => _measurements.softDelete(id);

  double _round(double v) => (v * 10).roundToDouble() / 10;

  DateTime? _parseDay(String day) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(day);
    if (m == null) return null;
    final y = int.parse(m[1]!);
    final mo = int.parse(m[2]!);
    final d = int.parse(m[3]!);
    if (y < minYear) return null;
    final dt = DateTime(y, mo, d);
    if (dt.year != y || dt.month != mo || dt.day != d) return null;
    return dt;
  }
}
