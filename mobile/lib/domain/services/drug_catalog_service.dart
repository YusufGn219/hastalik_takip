// İlaç kataloğu: uygulamayla gelen listeyi veritabanına yükler ve içinde arar.
//
// Katalog dosyası `scripts/catalog/build_drug_catalog.py` ile üretilir
// (`assets/catalog/drugs.json`; dağıtım izni teyit edilene kadar git'te yoktur).
// Dosya yoksa depodaki küçük örnek (`drugs.sample.json`) kullanılır.
//
// Yükleme tembeldir: ilk aramada (ya da dosya sürümü değiştiyse) yapılır, açılışı
// geciktirmez. Sürüm bilgisi içerikle AYNI işlemde yazılır; yarıda kalan yükleme
// eski içeriği bozmaz. Aynı anda gelen çağrılar tek yüklemeyi paylaşır.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../data/database/app_database.dart';
import '../../data/repositories/drug_catalog_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../drug_search.dart';

/// `app_settings` anahtarı: yüklü katalog sürümü.
const drugCatalogVersionKey = 'drug_catalog_version';

const drugCatalogAsset = 'assets/catalog/drugs.json';
const drugCatalogSampleAsset = 'assets/catalog/drugs.sample.json';

/// Arama sonucu satırı.
class DrugSuggestion {
  const DrugSuggestion({required this.name, required this.activeIngredient, required this.atc});

  factory DrugSuggestion.fromEntry(DrugCatalogEntry e) =>
      DrugSuggestion(name: e.name, activeIngredient: e.activeIngredient, atc: e.atc);

  final String name;
  final String activeIngredient;
  final String atc;
}

class DrugCatalogService {
  DrugCatalogService({
    required DrugCatalogRepository catalog,
    required SettingsRepository settings,
    Future<String> Function(String path)? loadAsset,
  })  : _catalog = catalog,
        _settings = settings,
        _loadAsset = loadAsset ?? rootBundle.loadString;

  final DrugCatalogRepository _catalog;
  final SettingsRepository _settings;
  final Future<String> Function(String path) _loadAsset;

  /// En az bu kadar harf yazılınca aranır (tek harf binlerce sonuç verir).
  static const minQueryLength = 2;

  Future<void>? _import;

  /// Katalog yüklü ve güncel değilse yükler. Eşzamanlı çağrılar tek yüklemeyi
  /// paylaşır; hata olursa bir sonraki çağrı yeniden dener.
  Future<void> ensureImported() => _import ??= _guardedImport();

  Future<void> _guardedImport() async {
    try {
      await _importOnce();
    } catch (_) {
      _import = null; // bir sonraki çağrı yeniden denesin
      rethrow;
    }
  }

  Future<void> _importOnce() async {
    final parsed = await _readAsset();
    final version = '${parsed.source}|${parsed.date}|${parsed.rows.length}';
    final loaded = await _settings.get(drugCatalogVersionKey);
    if (loaded == version && await _catalog.count() == parsed.rows.length) return;
    await _catalog.replaceAll(
      parsed.rows,
      onCommitted: () => _settings.set(drugCatalogVersionKey, version),
    );
  }

  Future<({String source, String date, List<DrugCatalogRow> rows})> _readAsset() async {
    String text;
    try {
      text = await _loadAsset(drugCatalogAsset);
    } catch (_) {
      text = await _loadAsset(drugCatalogSampleAsset); // gerçek katalog dosyası yok
    }
    final json = jsonDecode(text) as Map<String, dynamic>;
    final meta = (json['meta'] as Map<String, dynamic>?) ?? const {};
    final rows = <DrugCatalogRow>[];
    for (final item in json['items'] as List) {
      if (item is! List || item.length < 3) continue;
      final name = (item[0] as String).trim();
      if (name.isEmpty) continue;
      final active = (item[1] as String).trim();
      rows.add(DrugCatalogRow(
        name: name,
        activeIngredient: active,
        atc: (item[2] as String).trim(),
        searchKey: drugSearchKey('$name $active'),
      ));
    }
    return (
      source: meta['kaynak'] as String? ?? '?',
      date: meta['liste_tarihi'] as String? ?? '?',
      rows: rows,
    );
  }

  /// [query]'deki tüm sözcükleri (ad ya da etkin maddede, harf ve Türkçe karakter
  /// farkı gözetmeden) içeren ilaçlar. Çok kısa sorguda boş döner. Katalog
  /// yüklenemezse hata fırlatır.
  Future<List<DrugSuggestion>> search(String query, {int limit = 30}) async {
    final tokens = drugSearchTokens(query);
    if (tokens.join().length < minQueryLength) return const [];
    await ensureImported();
    final found = await _catalog.search(tokens, limit: limit);
    return [for (final e in found) DrugSuggestion.fromEntry(e)];
  }
}
