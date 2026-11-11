// Ayarlar'daki "Adım takibi" kartı: anahtar, izin akışı, izin geri alınma uyarısı.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/providers.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/domain/services/step_control.dart';
import 'package:mobile/domain/services/step_tracking.dart';
import 'package:mobile/domain/step_permission.dart';
import 'package:mobile/domain/step_source.dart';
import 'package:mobile/features/steps/step_settings_card.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../support/fake_settings_repository.dart';
import '../support/fake_step_support.dart';

class _Tracking implements StepTracking {
  int refreshes = 0;

  @override
  Future<StepReadStatus> refresh() async {
    refreshes++;
    return StepReadStatus.ok;
  }

  @override
  Future<StepReadStatus> onAppOpen() => refresh();

  @override
  Future<StepReadStatus> onRoutine() => throw UnimplementedError();
}

void main() {
  late FakeSettingsRepository settings;
  late FakeStepPermission permission;
  late FakeStepScheduler scheduler;
  late _Tracking tracking;

  Future<void> open(WidgetTester tester, {Map<String, String>? initial, bool failWrites = false}) async {
    settings = FakeSettingsRepository(initial: initial, failWrites: failWrites);
    scheduler = FakeStepScheduler();
    tracking = _Tracking();
    final control = StepControl(
      settings: settings,
      permission: permission,
      tracking: tracking,
      scheduler: scheduler,
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [stepControlProvider.overrideWithValue(control)],
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SingleChildScrollView(child: StepSettingsCard())),
      ),
    ));
    await tester.pumpAndSettle();
  }

  bool switchValue(WidgetTester tester) =>
      tester.widget<SwitchListTile>(find.byKey(const Key('ayar_adim_takibi'))).value;

  setUp(() => permission = FakeStepPermission());

  testWidgets('varsayılan kapalı; başlık ve açıklama görünür, uyarı yok', (tester) async {
    await open(tester);
    expect(find.text('Adım takibi'), findsOneWidget);
    expect(find.textContaining('yalnız bu telefonda'), findsOneWidget);
    expect(switchValue(tester), isFalse);
    expect(find.byKey(const Key('adim_izin_uyari')), findsNothing);
  });

  testWidgets('açınca izin istenir; verilirse anahtar açık, bayrak yazılır, okuma yapılır', (tester) async {
    permission.onRequest = StepPermissionState.granted;
    await open(tester);
    await tester.tap(find.byKey(const Key('ayar_adim_takibi')));
    await tester.pumpAndSettle();
    expect(permission.requests, 1);
    expect(switchValue(tester), isTrue);
    expect(settings.values[stepTrackingEnabledKey], '1');
    expect(tracking.refreshes, 1);
  });

  testWidgets('izin reddedilirse anahtar kapalı kalır ve ileti çıkar', (tester) async {
    permission.onRequest = StepPermissionState.denied;
    await open(tester);
    await tester.tap(find.byKey(const Key('ayar_adim_takibi')));
    await tester.pumpAndSettle();
    expect(switchValue(tester), isFalse);
    expect(find.text('İzin verilmedi; adım takibi açılmadı.'), findsOneWidget);
    expect(settings.values.containsKey(stepTrackingEnabledKey), isFalse);
    expect(tracking.refreshes, 0);
  });

  testWidgets('izin kalıcı reddedilmişse ileti çıkar ve telefon ayarları açılır', (tester) async {
    permission.current = StepPermissionState.permanentlyDenied;
    await open(tester);
    await tester.tap(find.byKey(const Key('ayar_adim_takibi')));
    await tester.pumpAndSettle();
    expect(switchValue(tester), isFalse);
    expect(find.text('İzin telefon ayarlarından açılmalı.'), findsOneWidget);
    expect(permission.settingsOpens, 1);
  });

  testWidgets('bayrak yazılamazsa "açılamadı" iletisi, anahtar kapalı', (tester) async {
    permission.current = StepPermissionState.granted;
    await open(tester, failWrites: true);
    await tester.tap(find.byKey(const Key('ayar_adim_takibi')));
    await tester.pumpAndSettle();
    expect(switchValue(tester), isFalse);
    expect(find.text('Adım takibi açılamadı.'), findsOneWidget);
  });

  testWidgets('açıkken kapatınca bayrak 0, görev iptal, anahtar kapalı', (tester) async {
    permission.current = StepPermissionState.granted;
    await open(tester, initial: {stepTrackingEnabledKey: '1'});
    expect(switchValue(tester), isTrue);
    await tester.tap(find.byKey(const Key('ayar_adim_takibi')));
    await tester.pumpAndSettle();
    expect(switchValue(tester), isFalse);
    expect(settings.values[stepTrackingEnabledKey], '0');
    expect(scheduler.cancels, 1);
  });

  testWidgets('açık ama izin telefon ayarlarından geri alınmışsa uyarı ve "Ayarları aç" çıkar', (tester) async {
    permission.current = StepPermissionState.denied;
    await open(tester, initial: {stepTrackingEnabledKey: '1'});
    expect(find.text('Fiziksel aktivite izni kapalı; adımlar okunamıyor.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('adim_izin_ayarlari')));
    await tester.pump();
    expect(permission.settingsOpens, 1);
  });

  testWidgets('telefon ayarlarından dönüşte (resumed) uyarı yeniden hesaplanır', (tester) async {
    permission.current = StepPermissionState.granted;
    await open(tester, initial: {stepTrackingEnabledKey: '1'});
    expect(find.byKey(const Key('adim_izin_uyari')), findsNothing);

    permission.current = StepPermissionState.denied;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('adim_izin_uyari')), findsOneWidget);

    permission.current = StepPermissionState.granted;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('adim_izin_uyari')), findsNothing);
  });

  testWidgets('kapalıyken izin olmaması uyarı göstermez', (tester) async {
    permission.current = StepPermissionState.denied;
    await open(tester);
    expect(find.byKey(const Key('adim_izin_uyari')), findsNothing);
  });
}
