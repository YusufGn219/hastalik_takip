import 'package:mobile/domain/services/step_tracking.dart';
import 'package:mobile/domain/step_source.dart';

/// Ayarlanabilir sahte adım kaynağı. [next] her okumada döner; [throwOnRead]
/// doluysa okuma istisna fırlatır.
class FakeStepSource implements StepSource {
  FakeStepSource({this.next = const StepReading(status: StepReadStatus.error)});

  StepReading next;
  Object? throwOnRead;
  int reads = 0;

  /// Sayaç [counter], açılış sayısı [bootCount], açılıştan beri [uptime].
  void ok(int counter, {int? bootCount = 1, Duration uptime = const Duration(hours: 5)}) {
    next = StepReading(
      status: StepReadStatus.ok,
      counter: counter,
      bootCount: bootCount,
      uptimeMs: uptime.inMilliseconds,
    );
  }

  void fail(StepReadStatus status) => next = StepReading(status: status);

  @override
  Future<StepReading> read() async {
    reads++;
    final e = throwOnRead;
    if (e != null) throw e;
    return next;
  }
}

/// Çağrıları sayan sahte zamanlayıcı; istenirse her çağrıda hata verir.
class FakeStepScheduler implements StepScheduler {
  int ensures = 0;
  int cancels = 0;
  int batteryOpens = 0;
  bool throws = false;

  @override
  Future<void> ensureScheduled() async {
    ensures++;
    if (throws) throw StateError('zamanlayıcı hatası');
  }

  @override
  Future<void> cancel() async {
    cancels++;
    if (throws) throw StateError('zamanlayıcı hatası');
  }

  @override
  Future<void> openBatterySettings() async {
    batteryOpens++;
  }
}
