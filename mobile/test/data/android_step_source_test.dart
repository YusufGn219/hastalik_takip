// Android adım kaynağı: eklentinin kanal sözleşmesi ve alan dönüşümü. Kotlin
// tarafı telefonda denenir; burada kanaldan gelen yanıtların doğru yorumlandığı
// ve hiçbir durumda istisna sızmadığı doğrulanır.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/steps/android_step_source.dart';
import 'package:mobile/domain/step_source.dart';
import 'package:vitapuls_steps/vitapuls_steps.dart' as plugin;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('vitapuls/steps');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void answer(Object? Function(MethodCall call) handler) =>
      messenger.setMockMethodCallHandler(channel, (call) async => handler(call));

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('başarılı yanıt alanlara çevrilir; istek zaman aşımını iletir', () async {
    MethodCall? seen;
    answer((call) {
      seen = call;
      return {'status': 'ok', 'counter': 12345, 'bootCount': 7, 'uptimeMs': 99000};
    });
    final r = await const AndroidStepSource().read();
    expect(r.status, StepReadStatus.ok);
    expect((r.counter, r.bootCount, r.uptimeMs), (12345, 7, 99000));
    expect(seen!.method, 'read');
    expect((seen!.arguments as Map)['timeoutMs'], 8000);
  });

  test('açılış sayısı yoksa null gelir; sayılar double olarak gelse de çevrilir', () async {
    answer((_) => {'status': 'ok', 'counter': 10.0, 'bootCount': null, 'uptimeMs': 5.0});
    final r = await const AndroidStepSource().read();
    expect((r.status, r.counter, r.bootCount, r.uptimeMs), (StepReadStatus.ok, 10, null, 5));
  });

  test('her durum karşılığına çevrilir', () async {
    for (final (code, expected) in [
      ('noPermission', StepReadStatus.noPermission),
      ('noSensor', StepReadStatus.noSensor),
      ('timeout', StepReadStatus.timeout),
      ('error', StepReadStatus.error),
      ('bilinmeyen', StepReadStatus.error),
    ]) {
      answer((_) => {'status': code});
      final r = await const AndroidStepSource().read();
      expect(r.status, expected, reason: code);
      expect(r.counter, isNull);
    }
  });

  test('eksik ya da bozuk ok yanıtı hata sayılır', () async {
    for (final bad in [
      <String, Object?>{'status': 'ok'},
      {'status': 'ok', 'counter': -1, 'uptimeMs': 5},
      {'status': 'ok', 'counter': 5},
      {'status': 'ok', 'counter': 'çok', 'uptimeMs': 5},
    ]) {
      answer((_) => bad);
      expect((await const AndroidStepSource().read()).status, StepReadStatus.error, reason: '$bad');
    }
  });

  test('kanal hatası ya da boş yanıtta istisna sızmaz', () async {
    answer((_) => throw PlatformException(code: 'x'));
    expect((await const AndroidStepSource().read()).status, StepReadStatus.error);
    answer((_) => null);
    expect((await const AndroidStepSource().read()).status, StepReadStatus.error);
  });

  test('eklenti çağrısında uygulanmamış kanal (MissingPlugin) hataya döner', () async {
    messenger.setMockMethodCallHandler(channel, null);
    expect((await plugin.VitapulsSteps.read()).status, plugin.StepReadStatus.error);
  });
}
