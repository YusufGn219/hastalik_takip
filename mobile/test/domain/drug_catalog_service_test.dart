// İlaç kataloğu servisi: yükleme (tembel, tek sefer, sürüme bağlı, atomik),
// dosya yoksa örneğe düşme ve arama kuralları. Gerçek (bellek içi) veritabanı.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/repositories/drug_catalog_repository.dart';
import 'package:mobile/data/repositories/settings_repository.dart';
import 'package:mobile/domain/services/drug_catalog_service.dart';

import '../data/test_support.dart';

String _catalog(List<List<String>> items, {String date = '2026-11-06', String source = 'TEST'}) => jsonEncode({
      'meta': {'kaynak': source, 'liste_tarihi': date},
      'items': items,
    });

/// Kaç kez yüklendiğini sayan depo.
class _CountingRepository extends DriftDrugCatalogRepository {
  _CountingRepository(super.db);
  int replaces = 0;
  bool failCommit = false;

  @override
  Future<void> replaceAll(
    List<DrugCatalogRow> rows, {
    Future<void> Function()? onCommitted,
    int chunkSize = 1000,
  }) {
    replaces++;
    return super.replaceAll(
      rows,
      chunkSize: chunkSize,
      onCommitted: () async {
        if (failCommit) throw StateError('yazılamadı');
        await onCommitted?.call();
      },
    );
  }
}

const _items = [
  ['PAROL 500 MG TABLET', 'parasetamol', 'N02BE01'],
  ['PAROL 120 MG/5 ML ORAL SÜSPANSİYON', 'parasetamol', 'N02BE01'],
  ['CALPOL 250 MG/5 ML ŞURUP', 'parasetamol', 'N02BE01'],
  ['ÇAY AĞACI YAĞI % 100 SIVI', 'çay ağacı yağı', ''],
  ['NUROFEN 200 MG DRAJE', 'ibuprofen', 'M01AE01'],
  ['% 0,4 LIDODEKS ÇÖZELTİ', 'lidokain', 'C01BB01'],
  ['X_Y 5 MG TABLET', 'madde', ''],
  ['XAY 5 MG TABLET', 'madde', ''],
];

void main() {
  late AppDatabase db;
  late _CountingRepository repo;
  late DriftSettingsRepository settings;
  late List<String> loaded; // istenen varlık yolları
  late Map<String, String> assets; // yol -> içerik; olmayan yol hata verir

  DrugCatalogService build() => DrugCatalogService(
        catalog: repo,
        settings: settings,
        loadAsset: (path) async {
          loaded.add(path);
          final text = assets[path];
          if (text == null) throw StateError('varlık yok: $path');
          return text;
        },
      );

  setUp(() {
    db = createTestDb();
    repo = _CountingRepository(db);
    settings = DriftSettingsRepository(db);
    loaded = [];
    assets = {drugCatalogAsset: _catalog(_items)};
  });
  tearDown(() => db.close());

  group('yükleme', () {
    test('ilk aramaya kadar yüklenmez (tembel); ilk aramada yüklenir', () async {
      final service = build();
      expect(loaded, isEmpty);
      expect(await repo.count(), 0);
      await service.search('parol');
      expect(await repo.count(), _items.length);
      expect(repo.replaces, 1);
    });

    test('çok kısa sorguda ne arar ne yükler', () async {
      final service = build();
      expect(await service.search('p'), isEmpty);
      expect(await service.search('  '), isEmpty);
      expect(loaded, isEmpty);
      expect(repo.replaces, 0);
    });

    test('aynı sürüm ikinci kez yüklenmez (yeni servis örneği, aynı veritabanı)', () async {
      await build().search('parol');
      await build().search('nurofen');
      expect(repo.replaces, 1, reason: 'sürüm ve satır sayısı tutuyor');
    });

    test('eşzamanlı çağrılar tek yüklemeyi paylaşır', () async {
      final service = build();
      await Future.wait([service.search('parol'), service.search('nurofen'), service.ensureImported()]);
      expect(repo.replaces, 1);
      expect(loaded.where((p) => p == drugCatalogAsset), hasLength(1));
    });

    test('dosya sürümü değişirse içerik tümden yenilenir (eski satırlar kalmaz)', () async {
      await build().search('parol');
      assets[drugCatalogAsset] = _catalog([
        ['YENİ İLAÇ 10 MG TABLET', 'yenimadde', 'A01'],
      ], date: '2026-12-01');
      final service = build();
      expect(await service.search('parol'), isEmpty, reason: 'eski içerik gitti');
      expect((await service.search('yeni')).single.name, 'YENİ İLAÇ 10 MG TABLET');
      expect(repo.replaces, 2);
      expect(await repo.count(), 1);
    });

    test('satır sayısı tutmuyorsa (tablo boşalmış) sürüm aynı olsa da yeniden yüklenir', () async {
      await build().search('parol');
      await db.delete(db.drugCatalogEntries).go();
      await build().search('parol');
      expect(repo.replaces, 2);
      expect(await repo.count(), _items.length);
    });

    test('gerçek katalog yoksa örnek katalog kullanılır', () async {
      assets
        ..remove(drugCatalogAsset)
        ..[drugCatalogSampleAsset] = _catalog([
          ['ÖRNEK 5 MG TABLET', 'örnekmadde', 'X01'],
        ], source: 'ÖRNEK');
      final service = build();
      expect((await service.search('örnek')).single.name, 'ÖRNEK 5 MG TABLET');
      expect(loaded, [drugCatalogAsset, drugCatalogSampleAsset]);
    });

    test('gerçek katalog varsa örneğe hiç bakılmaz', () async {
      assets[drugCatalogSampleAsset] = _catalog([
        ['ÖRNEK 5 MG TABLET', 'x', ''],
      ]);
      await build().search('parol');
      expect(loaded, [drugCatalogAsset]);
    });

    test('yazma yarıda kalırsa eski içerik ve sürüm korunur, sonraki çağrı yeniden dener', () async {
      await build().search('parol');
      assets[drugCatalogAsset] = _catalog([
        ['BAŞKA İLAÇ 1 MG', 'b', ''],
      ], date: '2026-12-01');
      repo.failCommit = true;
      final service = build();
      await expectLater(service.search('parol'), throwsA(isA<StateError>()));
      expect(await repo.count(), _items.length, reason: 'eski içerik aynen');
      expect(await settings.get(drugCatalogVersionKey), contains('2026-11-06'));

      repo.failCommit = false;
      expect((await service.search('başka')).single.name, 'BAŞKA İLAÇ 1 MG');
    });

    test('bozuk JSON hata verir, veriye dokunmaz', () async {
      await build().search('parol');
      assets[drugCatalogAsset] = 'bozuk{';
      await expectLater(build().search('parol'), throwsA(isA<FormatException>()));
      expect(await repo.count(), _items.length);
    });

    test('geçersiz satırlar (kısa, adsız) atlanır, kalanlar yüklenir', () async {
      assets[drugCatalogAsset] = jsonEncode({
        'meta': {'kaynak': 'T', 'liste_tarihi': 'd'},
        'items': [
          ['TAMAM 1 MG', 'm', 'A'],
          ['EKSİK'],
          ['', 'm', 'A'],
          ['   ', 'm', 'A'],
          'metin',
        ],
      });
      await build().search('tamam');
      expect(await repo.count(), 1);
    });
  });

  group('arama', () {
    late DrugCatalogService service;
    setUp(() => service = build());

    Future<List<String>> names(String q, {int limit = 30}) async =>
        [for (final s in await service.search(q, limit: limit)) s.name];

    test('tüm sözcükler eşleşmeli (VE)', () async {
      expect(await names('parol süspansiyon'), ['PAROL 120 MG/5 ML ORAL SÜSPANSİYON']);
      expect(await names('parol nurofen'), isEmpty);
    });

    test('Türkçe karakter ve harf boyutu önemsiz', () async {
      expect(await names('cay agaci'), ['ÇAY AĞACI YAĞI % 100 SIVI']);
      expect(await names('ÇAY'), ['ÇAY AĞACI YAĞI % 100 SIVI']);
      expect(await names('suspansiyon'), ['PAROL 120 MG/5 ML ORAL SÜSPANSİYON']);
    });

    test('etkin maddeyle de bulunur', () async {
      expect(await names('parasetamol'), hasLength(3));
      expect(await names('ibuprofen'), ['NUROFEN 200 MG DRAJE']);
    });

    test('adı sözcükle başlayanlar öne, sonra kısa adlılar gelir', () async {
      // "parasetamol" etkin maddesi üçünde de var; adı "para" ile başlayan yok, kısa ad önce.
      final r = await names('parasetamol');
      expect(r.first, 'PAROL 500 MG TABLET');
      expect(r.last, 'PAROL 120 MG/5 ML ORAL SÜSPANSİYON');
      // Ad başlangıcı: "calpol" dışındakiler "pa..." ile başlar; "ol" her ikisinde de geçer.
      final r2 = await names('calpol');
      expect(r2.single, 'CALPOL 250 MG/5 ML ŞURUP');
    });

    test('ad başlangıcı olan sonuç, ortasında geçenden önce gelir', () async {
      assets[drugCatalogAsset] = _catalog([
        ['ZZ SERUM FİZYOLOJİK', 'tuz', ''],
        ['FİZYOLOJİK SERUM', 'tuz', ''],
        ['AA FİZYOLOJİK UZUN ADLI İLAÇ SERUM', 'tuz', ''],
      ], date: 'yeni');
      final s = build();
      final r = [for (final x in await s.search('fizyolojik')) x.name];
      expect(r.first, 'FİZYOLOJİK SERUM', reason: 'ad "fizyolojik" ile başlıyor');
    });

    test('limit uygulanır', () async {
      expect(await names('mg', limit: 2), hasLength(2));
    });

    test('% ve _ LIKE joker karakteri değil, düz karakterdir', () async {
      expect(await names('% 100'), ['ÇAY AĞACI YAĞI % 100 SIVI']);
      expect(await names('x_y'), ['X_Y 5 MG TABLET'], reason: '_ joker olsaydı XAY de gelirdi');
      expect(await names('%%'), isEmpty);
    });

    test('ondalık virgüllü ad bulunur', () async {
      expect(await names('0,4 lidodeks'), ['% 0,4 LIDODEKS ÇÖZELTİ']);
    });

    test('sonuç alanları (etkin madde, ATC) taşınır', () async {
      final s = (await service.search('nurofen')).single;
      expect((s.name, s.activeIngredient, s.atc), ('NUROFEN 200 MG DRAJE', 'ibuprofen', 'M01AE01'));
    });
  });
}
