import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/enums.dart';
import 'package:mobile/data/repositories/daily_field_repository.dart';
import 'package:mobile/data/repositories/measurement_repository.dart';

/// Eski kurulumdan kalma elle "Adım sayısı" alanı (artık sunulmuyor): hazır alan
/// satırı [active] durumunda eklenir; [valueOn] verilirse o günlerin değeri yazılır.
Future<DailyField> seedLegacyStepsField(
  AppDatabase db, {
  bool active = true,
  Map<DateTime, double> valueOn = const {},
}) async {
  final field = await DriftDailyFieldRepository(db).insert(
    name: 'Adım sayısı',
    kind: DailyFieldKinds.number,
    unit: 'adım',
    minValue: 0,
    maxValue: 100000,
    isActive: active,
    sortOrder: 99,
    builtinKey: MeasurementTypes.steps,
  );
  final measurements = DriftMeasurementRepository(db);
  for (final e in valueOn.entries) {
    await measurements.add(
      type: MeasurementTypes.steps,
      value: e.value,
      unit: 'adım',
      measuredAt: e.key,
    );
  }
  return field;
}
