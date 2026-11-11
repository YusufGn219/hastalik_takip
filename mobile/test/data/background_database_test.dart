// Arka plan için veritabanı açılışı: yalnızca var olanı açar, hiçbir şey
// oluşturmaz; iki bağlantı aynı dosyaya aynı anda yazabilir.

import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/database/database_opener.dart';
import 'package:mobile/data/database/enums.dart';
import 'package:mobile/data/repositories/step_sample_repository.dart';

const _key = 'c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3';

class _MemoryKeyStore implements DatabaseKeyStore {
  _MemoryKeyStore([this.key]);
  String? key;
  int creates = 0;

  @override
  Future<String> readOrCreateKey() async {
    creates++;
    return key ??= _key;
  }

  @override
  Future<String?> readExistingKey() async => key;
}

void main() {
  late Directory dir;
  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    dir = Directory.systemTemp.createTempSync('vitapuls_bgdb_');
  });
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  File dbFile() => File('${dir.path}/$databaseFileName');

  test('dosya yoksa null döner ve dosya OLUŞTURULMAZ', () async {
    final store = _MemoryKeyStore(_key);
    expect(await openExistingAppDatabase(keyStore: store, directory: dir), isNull);
    expect(dbFile().existsSync(), isFalse);
    expect(store.creates, 0);
  });

  test('dosya var ama anahtar yoksa null döner; anahtar ÜRETİLMEZ, dosya değişmez', () async {
    final created = openEncryptedDatabase(dbFile(), _key);
    await DriftStepSampleRepository(created).latest(); // dosyayı oluştur
    await created.close();
    final before = dbFile().readAsBytesSync();

    final store = _MemoryKeyStore(null);
    expect(await openExistingAppDatabase(keyStore: store, directory: dir), isNull);
    expect(store.key, isNull, reason: 'anahtar üretilmedi');
    expect(store.creates, 0);
    expect(dbFile().readAsBytesSync(), before);
  });

  test('dosya ve anahtar varsa mevcut veritabanını açar; veri korunur', () async {
    final created = openEncryptedDatabase(dbFile(), _key);
    await DriftStepSampleRepository(created).add(
      counter: 321, bootCount: 4, uptimeMs: 1000, sampledAt: DateTime(2026, 11, 10, 9), source: StepSampleSources.open,
    );
    await created.close();

    final db = (await openExistingAppDatabase(keyStore: _MemoryKeyStore(_key), directory: dir))!;
    addTearDown(db.close);
    expect((await DriftStepSampleRepository(db).latest())!.counter, 321);
  });

  test('yanlış anahtarla açılış hata verir (şifresiz ya da boş veritabanı açılmaz)', () async {
    final created = openEncryptedDatabase(dbFile(), _key);
    await DriftStepSampleRepository(created).latest();
    await created.close();
    final wrong = 'd4' * 32;
    final db = await openExistingAppDatabase(keyStore: _MemoryKeyStore(wrong), directory: dir);
    await expectLater(DriftStepSampleRepository(db!).latest(), throwsA(anything));
  });

  test('bağlantıya bekleme süresi (busy_timeout) ayarlanır', () async {
    final db = openEncryptedDatabase(dbFile(), _key);
    addTearDown(db.close);
    final row = await db.customSelect('PRAGMA busy_timeout').getSingle();
    expect(row.read<int>('timeout'), 5000);
  });

  test('yazan bir bağlantı varken yeni bağlantılar AÇILIRKEN de kilit hatası çıkmaz', () async {
    final app = openEncryptedDatabase(dbFile(), _key);
    addTearDown(app.close);
    final appRepo = DriftStepSampleRepository(app);
    await appRepo.latest(); // şemayı kur

    // Uygulama bağlantısı sürekli yazar; bu sırada arka plan görevi gibi yeni
    // bağlantılar açılır (anahtar doğrulama sorgusu kilitle karşılaşabilir).
    var writing = true;
    final writer = () async {
      var i = 0;
      while (writing) {
        await appRepo.add(
          counter: i, bootCount: 1, uptimeMs: i, sampledAt: DateTime(2026, 11, 10, 9, i % 60), source: StepSampleSources.open,
        );
        i++;
      }
    }();

    for (var n = 0; n < 15; n++) {
      final bg = openEncryptedDatabase(dbFile(), _key);
      await DriftStepSampleRepository(bg).latest(); // açılış + ilk sorgu: hata atmamalı
      await bg.close();
    }
    writing = false;
    await writer;
  });

  test('uygulama ve arka plan bağlantısı aynı dosyaya iç içe yazarken kilit hatası çıkmaz', () async {
    final app = openEncryptedDatabase(dbFile(), _key);
    final bg = openEncryptedDatabase(dbFile(), _key);
    addTearDown(app.close);
    addTearDown(bg.close);
    final appRepo = DriftStepSampleRepository(app);
    final bgRepo = DriftStepSampleRepository(bg);
    await appRepo.latest(); // şemayı kur

    Future<void> writer(StepSampleRepository repo, String source, int base) async {
      for (var i = 0; i < 40; i++) {
        await repo.add(
          counter: base + i, bootCount: 1, uptimeMs: i, sampledAt: DateTime(2026, 11, 10, 9, i), source: source,
        );
      }
    }

    await Future.wait([
      writer(appRepo, StepSampleSources.open, 0),
      writer(bgRepo, StepSampleSources.routine, 1000),
    ]);
    final all = await appRepo.listBetween(DateTime(2026, 11, 10), DateTime(2026, 11, 11));
    expect(all, hasLength(80));
    expect(all.where((s) => s.source == 'open'), hasLength(40));
    expect(all.where((s) => s.source == 'routine'), hasLength(40));
  });
}
