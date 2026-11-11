// Adım takibini açma/kapatma: izin akışı, bayrak, ilk okuma, görev kurma/iptal,
// açılış okumasının bayrağa bağlanması.

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/domain/services/step_control.dart';
import 'package:mobile/domain/services/step_service.dart';
import 'package:mobile/domain/services/step_tracking.dart';
import 'package:mobile/domain/step_permission.dart';
import 'package:mobile/domain/step_source.dart';

import '../support/fake_settings_repository.dart';
import '../support/fake_step_support.dart';

/// Hangi yolun okuduğunu not eden minimal servis (yazmaz).
class _Service implements StepService {
  _Service(this.source, this.log);
  final FakeStepSource source;
  final List<String> log;

  @override
  Future<StepRecordResult> record(String sourceName) async {
    log.add(sourceName);
    final r = await source.read();
    return StepRecordResult(r.status, stored: r.isOk);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late FakeSettingsRepository settings;
  late FakeStepPermission permission;
  late FakeStepScheduler scheduler;
  late FakeStepSource source;
  late List<String> reads;
  late StepControl control;

  StepControl build({FakeSettingsRepository? s}) {
    settings = s ?? FakeSettingsRepository();
    reads = [];
    source = FakeStepSource()..ok(1000);
    scheduler = FakeStepScheduler();
    return StepControl(
      settings: settings,
      permission: permission,
      tracking: StepTracking(service: _Service(source, reads), scheduler: scheduler),
      scheduler: scheduler,
    );
  }

  setUp(() {
    permission = FakeStepPermission();
    control = build();
  });

  test('varsayılan kapalı; kapalıyken açılış okuması hiç okumaz', () async {
    expect(await control.isEnabled(), isFalse);
    await control.onAppOpen();
    expect(reads, isEmpty);
    expect(scheduler.ensures, 0);
  });

  test('izin verilirse açılır: bayrak yazılır, "open" okuması yapılır, görev kurulur', () async {
    permission.onRequest = StepPermissionState.granted;
    expect(await control.enable(), StepEnableResult.enabled);
    expect(permission.requests, 1);
    expect(settings.values[stepTrackingEnabledKey], '1');
    expect(reads, ['open']);
    expect(scheduler.ensures, 1);
    expect(await control.isEnabled(), isTrue);
  });

  test('izin zaten varsa izin penceresi açılmaz', () async {
    permission.current = StepPermissionState.granted;
    expect(await control.enable(), StepEnableResult.enabled);
    expect(permission.requests, 0);
  });

  test('izin reddedilirse açılmaz: bayrak yok, okuma yok, görev yok', () async {
    permission.onRequest = StepPermissionState.denied;
    expect(await control.enable(), StepEnableResult.denied);
    expect(settings.values.containsKey(stepTrackingEnabledKey), isFalse);
    expect(reads, isEmpty);
    expect(scheduler.ensures, 0);
  });

  test('kalıcı reddedilmişse pencere açılmaz, sonuç permanentlyDenied', () async {
    permission.current = StepPermissionState.permanentlyDenied;
    expect(await control.enable(), StepEnableResult.permanentlyDenied);
    expect(permission.requests, 0);
    expect(settings.values.containsKey(stepTrackingEnabledKey), isFalse);
  });

  test('bayrak yazılamazsa açılmaz ve okuma yapılmaz (failed)', () async {
    control = build(s: FakeSettingsRepository(failWrites: true));
    permission.current = StepPermissionState.granted;
    expect(await control.enable(), StepEnableResult.failed);
    expect(reads, isEmpty);
    expect(scheduler.ensures, 0);
  });

  test('ilk okuma hata verse de açma başarılı sayılır', () async {
    permission.current = StepPermissionState.granted;
    source.throwOnRead = StateError('sensör');
    expect(await control.enable(), StepEnableResult.enabled);
    expect(settings.values[stepTrackingEnabledKey], '1');
  });

  test('açıkken açılış okuması okur; kapatınca bayrak 0 olur ve görev iptal edilir', () async {
    permission.current = StepPermissionState.granted;
    await control.enable();
    reads.clear();
    await control.onAppOpen();
    expect(reads, ['open']);

    await control.disable();
    expect(settings.values[stepTrackingEnabledKey], '0');
    expect(scheduler.cancels, 1);
    reads.clear();
    await control.onAppOpen();
    expect(reads, isEmpty, reason: 'kapalıyken izin olsa da okunmaz');
  });

  test('kapatırken görev iptali hata verse de bayrak yazılır', () async {
    permission.current = StepPermissionState.granted;
    await control.enable();
    scheduler.throws = true;
    await control.disable();
    expect(settings.values[stepTrackingEnabledKey], '0');
  });

  test('kapatırken bayrak yazılamazsa hata yukarı çıkar', () async {
    control = build(s: FakeSettingsRepository(failWrites: true));
    expect(control.disable(), throwsA(isA<StateError>()));
  });

  test('onAppOpen hiçbir durumda istisna fırlatmaz (ayar okunamazsa da)', () async {
    control = build(s: FakeSettingsRepository(failReads: true));
    await control.onAppOpen();
    expect(reads, isEmpty);
  });

  test('state: izin sonradan geri alınmışsa permissionLost doğru', () async {
    permission.current = StepPermissionState.granted;
    await control.enable();
    expect((await control.state()).permissionLost, isFalse);
    permission.current = StepPermissionState.denied;
    final s = await control.state();
    expect(s.enabled, isTrue);
    expect(s.permissionLost, isTrue);
  });

  test('state: kapalıyken izin olmaması "kayıp" sayılmaz', () async {
    final s = await control.state();
    expect(s.enabled, isFalse);
    expect(s.permissionLost, isFalse);
  });

  test('openPermissionSettings izin servisine iletilir', () async {
    await control.openPermissionSettings();
    expect(permission.settingsOpens, 1);
  });

  test('izin yokken açılış okuması görevi iptal eder (açık ama izin geri alınmış)', () async {
    permission.current = StepPermissionState.granted;
    await control.enable();
    source.fail(StepReadStatus.noPermission);
    scheduler.cancels = 0;
    await control.onAppOpen();
    expect(scheduler.cancels, 1);
  });
}
