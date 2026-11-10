// Adım servisi: okuma yazma, saatlik/günlük hesap, yeniden başlatma, uzun
// aralıklar, gece yarısı, hata durumları. Gerçek (bellek içi) veritabanı + sahte
// adım kaynağı.

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/enums.dart';
import 'package:mobile/data/repositories/step_sample_repository.dart';
import 'package:mobile/domain/services/step_service.dart';
import 'package:mobile/domain/step_source.dart';

import '../data/test_support.dart';

class _FakeSource implements StepSource {
  StepReading next = const StepReading(status: StepReadStatus.error);
  int reads = 0;

  @override
  Future<StepReading> read() async {
    reads++;
    return next;
  }
}

void main() {
  late AppDatabase db;
  late DriftStepSampleRepository repo;
  late _FakeSource source;
  late StepService service;
  var now = DateTime(2026, 11, 10, 12);

  setUp(() {
    db = createTestDb();
    repo = DriftStepSampleRepository(db, newId: sequentialIds('s'));
    source = _FakeSource();
    now = DateTime(2026, 11, 10, 12);
    service = StepService(source: source, samples: repo, clock: () => now);
  });
  tearDown(() => db.close());

  /// [at] anında sayaç [counter] okunur. Açılış anı [boot] (varsayılan: 9 Kasım
  /// 06:00) ve [bootCount] verilirse açılış sayısı da gelir.
  Future<StepRecordResult> rec(
    DateTime at,
    int counter, {
    int? bootCount = 1,
    DateTime? boot,
    String via = StepSampleSources.routine,
  }) {
    now = at;
    final bootAt = boot ?? DateTime(2026, 11, 9, 6);
    source.next = StepReading(
      status: StepReadStatus.ok,
      counter: counter,
      bootCount: bootCount,
      uptimeMs: at.difference(bootAt).inMilliseconds,
    );
    return service.record(via);
  }

  List<double> hours(DaySteps d) => [for (final h in d.hours) h.steps];

  group('okuma ve yazma', () {
    test('başarılı okuma ham değerle yazılır; yol kaydedilir', () async {
      final r = await rec(DateTime(2026, 11, 10, 10), 1000, via: StepSampleSources.open);
      expect((r.status, r.stored), (StepReadStatus.ok, true));
      final s = (await repo.latest())!;
      expect((s.counter, s.bootCount, s.source, s.sampledAt), (1000, 1, 'open', DateTime(2026, 11, 10, 10)));
      expect(s.uptimeMs, DateTime(2026, 11, 10, 10).difference(DateTime(2026, 11, 9, 6)).inMilliseconds);
    });

    test('iki yol da yazar ve birbirinden bağımsızdır (biri hiç çalışmasa diğeri sonuç verir)', () async {
      await rec(DateTime(2026, 11, 10, 10), 1000, via: StepSampleSources.open);
      await rec(DateTime(2026, 11, 10, 11), 1600, via: StepSampleSources.routine);
      await rec(DateTime(2026, 11, 10, 12), 1900, via: StepSampleSources.open);
      final all = await repo.listBetween(DateTime(2026, 11, 10), DateTime(2026, 11, 11));
      expect(all.map((s) => s.source), ['open', 'routine', 'open']);
      final d = await service.forDay('2026-11-10');
      expect(d.totalRounded, 900);

      // Yalnız açılış yoluyla da hesap çıkar.
      final db2 = createTestDb();
      addTearDown(db2.close);
      final r2 = DriftStepSampleRepository(db2, newId: sequentialIds('t'));
      final s2 = StepService(source: source, samples: r2, clock: () => now);
      now = DateTime(2026, 11, 10, 8);
      source.next = const StepReading(status: StepReadStatus.ok, counter: 100, bootCount: 1, uptimeMs: 100000000);
      await s2.record(StepSampleSources.open);
      now = DateTime(2026, 11, 10, 9);
      source.next = const StepReading(status: StepReadStatus.ok, counter: 400, bootCount: 1, uptimeMs: 103600000);
      await s2.record(StepSampleSources.open);
      expect((await s2.forDay('2026-11-10')).totalRounded, 300);
    });

    test('bir dakikadan kısa aralıkla ikinci okuma yazılmaz; bir dakika sonra yazılır', () async {
      await rec(DateTime(2026, 11, 10, 10), 1000);
      final quick = await rec(DateTime(2026, 11, 10, 10, 0, 30), 1010);
      expect((quick.status, quick.stored), (StepReadStatus.ok, false));
      expect((await repo.latest())!.counter, 1000);
      final later = await rec(DateTime(2026, 11, 10, 10, 1), 1020);
      expect(later.stored, true);
      expect((await repo.latest())!.counter, 1020);
    });

    test('başarısız okumalar (izin yok, sensör yok, zaman aşımı, hata) hiçbir şey yazmaz', () async {
      for (final status in [StepReadStatus.noPermission, StepReadStatus.noSensor, StepReadStatus.timeout, StepReadStatus.error]) {
        source.next = StepReading(status: status);
        final r = await service.record(StepSampleSources.routine);
        expect((r.status, r.stored), (status, false));
      }
      expect(await repo.latest(), isNull);
    });

    test('bilinmeyen okuma yolu reddedilir ve kaynak okunmaz', () async {
      expect(() => service.record('arka'), throwsArgumentError);
      expect(source.reads, 0);
    });
  });

  group('saatlik ve günlük hesap', () {
    test('tam saatler arasında fark o saate yazılır; kısa aralık tahmini sayılmaz', () async {
      await rec(DateTime(2026, 11, 10, 10), 1000);
      await rec(DateTime(2026, 11, 10, 11), 1600);
      final d = await service.forDay('2026-11-10');
      expect(d.hours, hasLength(24));
      expect(d.hours[10].steps, closeTo(600, 1e-6));
      expect(d.hours[11].steps, 0);
      expect(d.total, closeTo(600, 1e-6));
      expect(d.totalRounded, 600);
      expect(d.hasData, isTrue);
      expect(d.hasEstimate, isFalse);
      expect(d.hours[10].estimated, isFalse);
    });

    test('saat sınırını aşan aralık süreye orantılı bölünür', () async {
      await rec(DateTime(2026, 11, 10, 10, 30), 1000);
      await rec(DateTime(2026, 11, 10, 11, 30), 1600);
      final d = await service.forDay('2026-11-10');
      expect(d.hours[10].steps, closeTo(300, 1e-6));
      expect(d.hours[11].steps, closeTo(300, 1e-6));
      expect(d.total, closeTo(600, 1e-6));
    });

    test('tek okuma adım üretmez ama gün "veri var" sayılır; hiç okuma yoksa veri yok', () async {
      expect((await service.forDay('2026-11-10')).hasData, isFalse);
      await rec(DateTime(2026, 11, 10, 10), 5000);
      final d = await service.forDay('2026-11-10');
      expect(d.hasData, isTrue);
      expect(d.total, 0);
      expect((await service.forDay('2026-11-12')).hasData, isFalse);
    });

    test('birden çok okuma: toplam farkların toplamıdır; 90 dakikadan uzun aralık tahmini işaretlenir', () async {
      await rec(DateTime(2026, 11, 10, 8), 0);
      await rec(DateTime(2026, 11, 10, 9), 500);
      await rec(DateTime(2026, 11, 10, 12), 1100); // 3 saatlik aralık: 9,10,11'e 200'er
      final d = await service.forDay('2026-11-10');
      expect(d.hours[8].steps, closeTo(500, 1e-6));
      expect(hours(d).sublist(9, 12).map((v) => v.round()), [200, 200, 200]);
      expect(d.hours[8].estimated, isFalse);
      expect(d.hours[9].estimated && d.hours[10].estimated && d.hours[11].estimated, isTrue);
      expect(d.totalRounded, 1100);
      expect(d.hasEstimate, isTrue);
    });

    test('tam 90 dakikalık aralık tahmini sayılmaz, 91 dakika sayılır', () async {
      await rec(DateTime(2026, 11, 10, 10), 0);
      await rec(DateTime(2026, 11, 10, 11, 30), 900);
      expect((await service.forDay('2026-11-10')).hasEstimate, isFalse);
      await rec(DateTime(2026, 11, 10, 13, 1), 1000);
      expect((await service.forDay('2026-11-10')).hasEstimate, isTrue);
    });

    test('gece yarısını aşan aralık iki güne orantılı bölünür', () async {
      await rec(DateTime(2026, 11, 9, 23), 100);
      await rec(DateTime(2026, 11, 10, 1), 300);
      final nine = await service.forDay('2026-11-09');
      final ten = await service.forDay('2026-11-10');
      expect(nine.hours[23].steps, closeTo(100, 1e-6));
      expect(ten.hours[0].steps, closeTo(100, 1e-6));
      expect(nine.total + ten.total, closeTo(200, 1e-6));
      expect(ten.hours[0].estimated, isTrue, reason: '2 saatlik aralık');
      expect(ten.hasData, isTrue);
    });

    test('günü baştan sona kapsayan uzun aralık o güne orantılı paylanır, her saat tahmini', () async {
      await rec(DateTime(2026, 11, 9, 20), 1000);
      await rec(DateTime(2026, 11, 11, 8), 1780); // 36 saat, 780 adım
      final d = await service.forDay('2026-11-10');
      expect(d.total, closeTo(780 * 24 / 36, 1e-6));
      expect(d.hours.every((h) => h.estimated), isTrue);
      expect(d.hours[5].steps, closeTo(780 / 36, 1e-6));
      expect(d.hasData, isTrue);
    });

    test('today() saatin yerel gününü kullanır', () async {
      await rec(DateTime(2026, 11, 10, 9), 100);
      await rec(DateTime(2026, 11, 10, 10), 400);
      now = DateTime(2026, 11, 10, 23, 59);
      expect((await service.today()).totalRounded, 300);
      now = DateTime(2026, 11, 11, 0, 5);
      expect((await service.today()).day, '2026-11-11');
    });
  });

  group('yeniden başlatma', () {
    test('açılış sayısı değişince yeni sayaç açılıştan beri adımdır, açılıştan itibaren dağıtılır', () async {
      await rec(DateTime(2026, 11, 10, 10), 5000, bootCount: 1);
      // 10:30'da açıldı; 12:00'de sayaç 700.
      await rec(DateTime(2026, 11, 10, 12), 700, bootCount: 2, boot: DateTime(2026, 11, 10, 10, 30));
      final d = await service.forDay('2026-11-10');
      expect(d.hours[10].steps, closeTo(700 * 30 / 90, 1e-6));
      expect(d.hours[11].steps, closeTo(700 * 60 / 90, 1e-6));
      expect(d.total, closeTo(700, 1e-6));
      expect(d.hours[10].estimated && d.hours[11].estimated, isTrue);
    });

    test('sayaç yeniden başlatma sonrası eskisinden BÜYÜK olsa da açılış sayısı sayesinde doğru bulunur', () async {
      await rec(DateTime(2026, 11, 10, 10), 100, bootCount: 1);
      await rec(DateTime(2026, 11, 10, 12), 5000, bootCount: 2, boot: DateTime(2026, 11, 10, 10));
      final d = await service.forDay('2026-11-10');
      expect(d.total, closeTo(5000, 1e-6), reason: '4900 değil: sayaç sıfırdan başlamıştı');
    });

    test('açılış sayısı VARSA o belirler: sayı değiştiyse, açılış anları aynı görünse bile yeniden başlatmadır', () async {
      await rec(DateTime(2026, 11, 10, 10), 100, bootCount: 1);
      await rec(DateTime(2026, 11, 10, 12), 5000, bootCount: 2); // aynı açılış anı, farklı sayı
      expect((await service.forDay('2026-11-10')).total, closeTo(5000, 1e-6));
    });

    test('açılış sayısı aynıysa, saat sıçraması açılış anını kaydırsa da aynı oturumdur', () async {
      await rec(DateTime(2026, 11, 10, 10), 1000, bootCount: 3);
      // Duvar saati 3 saat ileri sıçramış gibi: açılış anı farkı büyük, ama sayı aynı.
      await rec(DateTime(2026, 11, 10, 11), 1500, bootCount: 3, boot: DateTime(2026, 11, 9, 3));
      final d = await service.forDay('2026-11-10');
      expect(d.total, closeTo(500, 1e-6));
      expect(d.hasEstimate, isFalse);
    });

    test('açılış sayısı bilinmiyorsa açılış anı farkından anlaşılır', () async {
      await rec(DateTime(2026, 11, 10, 10), 5000, bootCount: null);
      await rec(DateTime(2026, 11, 10, 12), 700, bootCount: null, boot: DateTime(2026, 11, 10, 10, 30));
      final d = await service.forDay('2026-11-10');
      expect(d.total, closeTo(700, 1e-6));
    });

    test('açılış sayısı bilinmiyor ama açılış anı aynıysa normal fark alınır', () async {
      await rec(DateTime(2026, 11, 10, 10), 1000, bootCount: null);
      await rec(DateTime(2026, 11, 10, 11), 1500, bootCount: null);
      final d = await service.forDay('2026-11-10');
      expect(d.hours[10].steps, closeTo(500, 1e-6));
      expect(d.hasEstimate, isFalse);
    });

    test('aynı açılışta sayaç düştüyse (sensör sıfırlaması) yeni oturum sayılır', () async {
      await rec(DateTime(2026, 11, 10, 10), 5000, bootCount: 1);
      await rec(DateTime(2026, 11, 10, 11), 40, bootCount: 1);
      final d = await service.forDay('2026-11-10');
      expect(d.total, closeTo(40, 1e-6), reason: 'eksi adım olmaz');
      expect(d.hours.every((h) => h.steps >= 0), isTrue);
    });

    test('açılıştan hemen sonra okuma (süre sıfır): adım okuma anının saatine yazılır', () async {
      await rec(DateTime(2026, 11, 10, 10), 5000, bootCount: 1);
      await rec(DateTime(2026, 11, 10, 12), 12, bootCount: 2, boot: DateTime(2026, 11, 10, 12));
      final d = await service.forDay('2026-11-10');
      expect(d.hours[12].steps, 12);
      expect(d.hours[12].estimated, isTrue);
    });
  });
}
