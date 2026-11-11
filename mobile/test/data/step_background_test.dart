// Saatlik arka plan okuması: veritabanı açma/kapama, "veri yok" durumunda kendini
// iptal etme, hata dayanıklılığı, kalıcılık.

import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/repositories/step_sample_repository.dart';
import 'package:mobile/data/steps/step_background.dart';
import 'package:mobile/domain/step_source.dart';

import '../support/fake_step_support.dart';
import 'test_support.dart';

/// `close()` çağrılarını sayar (Drift kapatılmış veritabanını yeniden açabildiği
/// için kapanışı sorguyla değil bu sayaçla doğrularız).
class _SpyDb extends AppDatabase {
  _SpyDb(super.executor);
  int closeCalls = 0;

  @override
  Future<void> close() {
    closeCalls++;
    return super.close();
  }
}

void main() {
  late FakeStepSource source;
  late FakeStepScheduler scheduler;
  setUp(() {
    source = FakeStepSource();
    scheduler = FakeStepScheduler();
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  Future<bool> run(Future<AppDatabase?> Function() open, {DateTime? at}) => runStepRoutine(
        openDatabase: open,
        source: source,
        scheduler: scheduler,
        clock: () => at ?? DateTime(2026, 11, 10, 14),
      );

  test('okuma "routine" etiketiyle yazılır, true döner; kapanıştan sonra dosyadan geri okunur', () async {
    final dir = Directory.systemTemp.createTempSync('vitapuls_bg_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/bg.db');
    source.ok(4200, bootCount: 9);

    final ok = await run(() async => AppDatabase(NativeDatabase(file)));
    expect(ok, isTrue);

    // Yeni bir bağlantı (uygulamanın kendi bağlantısı gibi) aynı okumayı görür.
    final reader = AppDatabase(NativeDatabase(file));
    addTearDown(reader.close);
    final sample = (await DriftStepSampleRepository(reader).latest())!;
    expect((sample.counter, sample.bootCount, sample.source), (4200, 9, 'routine'));
    expect(sample.sampledAt, DateTime(2026, 11, 10, 14));
  });

  test('veritabanı her durumda kapatılır (başarı, izin yok, okuma hatası)', () async {
    for (final (name, prepare) in <(String, void Function())>[
      ('başarı', () => source.ok(1)),
      ('izin yok', () => source.fail(StepReadStatus.noPermission)),
      ('okuma hatası', () => source.throwOnRead = StateError('sensör çöktü')),
    ]) {
      source.throwOnRead = null;
      prepare();
      final db = _SpyDb(NativeDatabase.memory());
      expect(await run(() async => db), isTrue, reason: name);
      expect(db.closeCalls, 1, reason: name);
    }
  });

  test('veritabanı yoksa (veri silinmiş) hiçbir şey okunmaz, görev kendini iptal eder', () async {
    source.ok(1);
    final ok = await run(() async => null);
    expect(ok, isTrue);
    expect(scheduler.cancels, 1);
    expect(source.reads, 0);
  });

  test('izin yoksa görev kendini iptal eder ve hiçbir okuma yazılmaz', () async {
    final db = createTestDb();
    addTearDown(db.close);
    source.fail(StepReadStatus.noPermission);
    expect(await run(() async => db), isTrue);
    expect(scheduler.cancels, 1);
    expect(source.reads, 1);
  });

  test('veritabanı açılırken hata olursa istisna sızmaz, true döner, okuma yapılmaz', () async {
    source.ok(1);
    final ok = await run(() async => throw StateError('anahtar yanlış'));
    expect(ok, isTrue);
    expect(source.reads, 0);
  });

  test('görev adı ve benzersiz kimlik sabittir; aralık bir saattir', () {
    expect(stepTaskName, 'vitapuls.steps.read');
    expect(stepUniqueName, 'vitapuls.steps.hourly');
    expect(stepFrequency, const Duration(hours: 1));
  });
}
