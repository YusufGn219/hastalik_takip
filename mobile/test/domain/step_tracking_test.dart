// Adım takibi: açılış ve rutin yolları birbirinden bağımsızdır; zamanlama izin
// durumuna bağlanır; hiçbir hata dışarı sızmaz.

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/enums.dart';
import 'package:mobile/data/repositories/step_sample_repository.dart';
import 'package:mobile/domain/services/step_service.dart';
import 'package:mobile/domain/services/step_tracking.dart';
import 'package:mobile/domain/step_source.dart';

import '../data/test_support.dart';
import '../support/fake_step_support.dart';

void main() {
  late AppDatabase db;
  late DriftStepSampleRepository repo;
  late FakeStepSource source;
  late FakeStepScheduler scheduler;
  late StepTracking tracking;
  var now = DateTime(2026, 11, 10, 12);

  setUp(() {
    db = createTestDb();
    repo = DriftStepSampleRepository(db, newId: sequentialIds('s'));
    source = FakeStepSource();
    scheduler = FakeStepScheduler();
    now = DateTime(2026, 11, 10, 12);
    tracking = StepTracking(
      service: StepService(source: source, samples: repo, clock: () => now),
      scheduler: scheduler,
    );
  });
  tearDown(() => db.close());

  Future<List<String>> sources() async =>
      (await repo.listBetween(DateTime(2026, 11, 10), DateTime(2026, 11, 11))).map((s) => s.source).toList();

  group('açılış yolu', () {
    test('okur, "open" etiketiyle yazar ve saatlik görevin kurulu olmasını sağlar', () async {
      source.ok(1000);
      expect(await tracking.onAppOpen(), StepReadStatus.ok);
      expect(await sources(), ['open']);
      expect(scheduler.ensures, 1);
      expect(scheduler.cancels, 0);
    });

    test('izin yoksa ya da sensör yoksa hiçbir şey yazılmaz ve saatlik görev iptal edilir', () async {
      for (final status in [StepReadStatus.noPermission, StepReadStatus.noSensor]) {
        source.fail(status);
        expect(await tracking.onAppOpen(), status);
      }
      expect(await sources(), isEmpty);
      expect(scheduler.cancels, 2);
      expect(scheduler.ensures, 0);
    });

    test('geçici sorunlarda (zaman aşımı, hata) mevcut zamanlamaya dokunulmaz', () async {
      for (final status in [StepReadStatus.timeout, StepReadStatus.error]) {
        source.fail(status);
        expect(await tracking.onAppOpen(), status);
      }
      expect((scheduler.ensures, scheduler.cancels), (0, 0));
    });

    test('kaynak istisna fırlatsa da hata sızmaz, durum "error" döner', () async {
      source.throwOnRead = StateError('sensör çöktü');
      expect(await tracking.onAppOpen(), StepReadStatus.error);
      expect(await tracking.onRoutine(), StepReadStatus.error);
    });

    test('zamanlayıcı hata verse de okuma yazılmış olur ve hata sızmaz', () async {
      scheduler.throws = true;
      source.ok(500);
      expect(await tracking.onAppOpen(), StepReadStatus.ok);
      expect(await sources(), ['open']);
    });

    test('refresh() açılış yoluyla aynıdır (izin yeni verilince çağrılır)', () async {
      source.ok(10);
      expect(await tracking.refresh(), StepReadStatus.ok);
      expect(await sources(), ['open']);
      expect(scheduler.ensures, 1);
    });
  });

  group('rutin yolu', () {
    test('"routine" etiketiyle yazar; zamanlamaya dokunmaz (görev zaten çalışıyor)', () async {
      source.ok(1000);
      expect(await tracking.onRoutine(), StepReadStatus.ok);
      expect(await sources(), ['routine']);
      expect((scheduler.ensures, scheduler.cancels), (0, 0));
    });

    test('izin geri alınmışsa ya da sensör yoksa kendini iptal eder', () async {
      source.fail(StepReadStatus.noPermission);
      await tracking.onRoutine();
      source.fail(StepReadStatus.noSensor);
      await tracking.onRoutine();
      expect(scheduler.cancels, 2);
      expect(await sources(), isEmpty);
    });

    test('zaman aşımında iptal etmez (sonraki saatte yeniden dener)', () async {
      source.fail(StepReadStatus.timeout);
      await tracking.onRoutine();
      expect(scheduler.cancels, 0);
    });

    test('iptal sırasında zamanlayıcı hata verse de sızmaz', () async {
      scheduler.throws = true;
      source.fail(StepReadStatus.noPermission);
      expect(await tracking.onRoutine(), StepReadStatus.noPermission);
    });
  });

  group('iki yolun bağımsızlığı', () {
    test('rutin hiç çalışmasa açılış yolu tek başına saatlik veri üretir', () async {
      now = DateTime(2026, 11, 10, 9);
      source.ok(100);
      await tracking.onAppOpen();
      now = DateTime(2026, 11, 10, 10);
      source.ok(700);
      await tracking.onAppOpen();
      expect(await sources(), ['open', 'open']);
      final svc = StepService(source: source, samples: repo, clock: () => now);
      expect((await svc.forDay('2026-11-10')).hours[9].steps, closeTo(600, 1e-6));
    });

    test('açılış yolu çökse bile rutin kendi okumasını yapar', () async {
      source.throwOnRead = StateError('açılış anında sensör hatası');
      await tracking.onAppOpen();
      source.throwOnRead = null;
      now = DateTime(2026, 11, 10, 13);
      source.ok(900);
      await tracking.onRoutine();
      expect(await sources(), ['routine']);
    });

    test('iki yol karışık çalışır; toplam, hangi yolla okunduğundan bağımsızdır', () async {
      now = DateTime(2026, 11, 10, 9);
      source.ok(0);
      await tracking.onAppOpen();
      now = DateTime(2026, 11, 10, 10);
      source.ok(300);
      await tracking.onRoutine();
      now = DateTime(2026, 11, 10, 11);
      source.ok(900);
      await tracking.onAppOpen();
      expect(await sources(), ['open', 'routine', 'open']);
      final svc = StepService(source: source, samples: repo, clock: () => now);
      expect((await svc.forDay('2026-11-10')).totalRounded, 900);
    });

    test('aynı anda iki yol (bir dakikadan kısa arayla) tek okuma bırakır', () async {
      source.ok(100);
      await tracking.onAppOpen();
      source.ok(105);
      await tracking.onRoutine();
      expect((await sources()).length, 1);
    });
  });

  test('StepSampleSources yalnız iki yol içerir', () {
    expect(StepSampleSources.all, ['routine', 'open']);
  });
}
