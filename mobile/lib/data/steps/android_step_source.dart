import 'package:vitapuls_steps/vitapuls_steps.dart' as plugin;

import '../../domain/step_source.dart';

/// Android'in adım sayacı (`STEP_COUNTER`); eklentiyi (`packages/vitapuls_steps`)
/// kullanır. Arka plan görevinde de çalışır.
class AndroidStepSource implements StepSource {
  const AndroidStepSource();

  @override
  Future<StepReading> read() async {
    final r = await plugin.VitapulsSteps.read();
    return StepReading(
      status: switch (r.status) {
        plugin.StepReadStatus.ok => StepReadStatus.ok,
        plugin.StepReadStatus.noPermission => StepReadStatus.noPermission,
        plugin.StepReadStatus.noSensor => StepReadStatus.noSensor,
        plugin.StepReadStatus.timeout => StepReadStatus.timeout,
        plugin.StepReadStatus.error => StepReadStatus.error,
      },
      counter: r.counter,
      bootCount: r.bootCount,
      uptimeMs: r.uptimeMs,
    );
  }
}
