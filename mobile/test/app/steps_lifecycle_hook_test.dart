// Açılış okuma yolu: ilk çizimden sonra ve her öne gelişte bir kez çalışır;
// çakışmaz, hata vermez, arayüzü engellemez.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/domain/services/step_control.dart';
import 'package:mobile/domain/services/step_service.dart';
import 'package:mobile/domain/services/step_tracking.dart';
import 'package:mobile/domain/step_permission.dart';
import 'package:mobile/domain/step_source.dart';
import 'package:mobile/features/steps/steps_lifecycle_hook.dart';

import '../support/fake_settings_repository.dart';
import '../support/fake_step_support.dart';

/// Takip açık/kapalı bayrağıyla gerçek [StepControl]; izleyici/gerçek izleme içeride.
StepControl _control(StepTracking tracking, {bool enabled = true}) => StepControl(
      settings: FakeSettingsRepository(
        initial: enabled ? {stepTrackingEnabledKey: '1'} : null,
      ),
      permission: FakeStepPermission(current: StepPermissionState.granted),
      tracking: tracking,
      scheduler: FakeStepScheduler(),
    );

class _SpyTracking implements StepTracking {
  int opens = 0;
  Completer<StepReadStatus>? hold;
  Object? error;

  @override
  Future<StepReadStatus> onAppOpen() async {
    opens++;
    if (error != null) throw error!;
    return hold?.future ?? StepReadStatus.ok;
  }

  @override
  Future<StepReadStatus> onRoutine() => throw UnimplementedError();

  @override
  Future<StepReadStatus> refresh() => onAppOpen();
}

void main() {
  late _SpyTracking spy;
  setUp(() => spy = _SpyTracking());

  Future<void> pump(WidgetTester tester, {bool enabled = true}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [stepControlProvider.overrideWithValue(_control(spy, enabled: enabled))],
      child: const MaterialApp(
        home: StepsLifecycleHook(child: Scaffold(body: Text('ana ekran'))),
      ),
    ));
  }

  testWidgets('ilk çizimden sonra bir kez okur; arayüz hemen görünür', (tester) async {
    await pump(tester);
    await tester.pump();
    expect(find.text('ana ekran'), findsOneWidget);
    expect(spy.opens, 1);
  });

  testWidgets('arka plandan öne gelince yeniden okur; diğer durumlarda okumaz', (tester) async {
    await pump(tester);
    await tester.pump();
    expect(spy.opens, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(spy.opens, 1, reason: 'arka plana giderken okunmaz');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(spy.opens, 2);
  });

  testWidgets('önceki okuma bitmeden gelen ikinci tetik yeni okuma başlatmaz', (tester) async {
    spy.hold = Completer<StepReadStatus>();
    await pump(tester);
    await tester.pump();
    expect(spy.opens, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(spy.opens, 1, reason: 'ilki hâlâ sürüyor');

    spy.hold!.complete(StepReadStatus.ok);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(spy.opens, 2, reason: 'ilki bitince yeni okuma başlayabilir');
  });

  testWidgets('okuma hata verse de uygulama etkilenmez ve sonraki tetik yine okur', (tester) async {
    spy.error = StateError('sensör çöktü');
    await pump(tester);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('ana ekran'), findsOneWidget);

    spy.error = null;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(spy.opens, 2);
  });

  testWidgets('ekran kapanınca gözlemci kaldırılır (sonraki yaşam döngüsü olayı okumaz)', (tester) async {
    await pump(tester);
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(spy.opens, 1);
  });

  testWidgets('takip kapalıysa açılışta da öne gelişte de okumaz', (tester) async {
    await pump(tester, enabled: false);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(spy.opens, 0);
    expect(find.text('ana ekran'), findsOneWidget);
  });

  testWidgets('gerçek StepTracking ile: izin varsa açılışta "open" okuması yazılır ve görev kurulur', (tester) async {
    // Sahteler: gerçek servis zinciri, ama sensör ve zamanlayıcı sahte.
    final source = FakeStepSource()..ok(1234);
    final scheduler = FakeStepScheduler();
    final reads = <String>[];
    final tracking = StepTracking(
      service: _RecordingService(source, reads),
      scheduler: scheduler,
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [stepControlProvider.overrideWithValue(_control(tracking))],
      child: const MaterialApp(home: StepsLifecycleHook(child: Scaffold(body: Text('x')))),
    ));
    await tester.pump();
    expect(reads, ['open']);
    expect(scheduler.ensures, 1);
  });
}

/// `StepService` yerine geçen minimal servis: yazmaz, hangi yolun okuduğunu not eder.
class _RecordingService implements StepService {
  _RecordingService(this.source, this.log);
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
