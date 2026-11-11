import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// Yüklenecek katalog satırı (arama anahtarı çağıran tarafından üretilir).
class DrugCatalogRow {
  const DrugCatalogRow({
    required this.name,
    required this.activeIngredient,
    required this.atc,
    required this.searchKey,
  });

  final String name;
  final String activeIngredient;
  final String atc;
  final String searchKey;
}

/// İlaç kataloğu (salt-okunur başvuru verisi). Kullanıcı verisi değildir; bkz.
/// `DrugCatalogEntries`.
abstract class DrugCatalogRepository {
  Future<int> count();

  /// Tüm içeriği tek işlemde [rows] ile değiştirir; [onCommitted] aynı işlemde
  /// çalışır (sürüm bilgisini içerikle birlikte yazmak için). Hata olursa eski
  /// içerik aynen kalır.
  Future<void> replaceAll(
    List<DrugCatalogRow> rows, {
    Future<void> Function()? onCommitted,
    int chunkSize = 1000,
  });

  /// [tokens]'ın HEPSİNİ içeren (arama anahtarında geçen) kayıtlar. Sıra: adı
  /// ilk sözcükle başlayanlar, sonra kısa adlılar, sonra ada göre.
  Future<List<DrugCatalogEntry>> search(List<String> tokens, {int limit = 30});
}

class DriftDrugCatalogRepository implements DrugCatalogRepository {
  DriftDrugCatalogRepository(this._db);

  final AppDatabase _db;

  @override
  Future<int> count() async {
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS c FROM drug_catalog',
          readsFrom: {_db.drugCatalogEntries},
        )
        .getSingle();
    return row.read<int>('c');
  }

  @override
  Future<void> replaceAll(
    List<DrugCatalogRow> rows, {
    Future<void> Function()? onCommitted,
    int chunkSize = 1000,
  }) {
    return _db.transaction(() async {
      await _db.delete(_db.drugCatalogEntries).go();
      for (var i = 0; i < rows.length; i += chunkSize) {
        final end = i + chunkSize < rows.length ? i + chunkSize : rows.length;
        await _db.batch((b) {
          b.insertAll(_db.drugCatalogEntries, [
            for (final r in rows.sublist(i, end))
              DrugCatalogEntriesCompanion.insert(
                name: r.name,
                activeIngredient: r.activeIngredient,
                atc: r.atc,
                searchKey: r.searchKey,
              ),
          ]);
        });
        // Arayüz iş parçacığına nefes aldır (uzun yüklemede donma olmasın).
        await Future<void>.delayed(Duration.zero);
      }
      await onCommitted?.call();
    });
  }

  @override
  Future<List<DrugCatalogEntry>> search(List<String> tokens, {int limit = 30}) async {
    if (tokens.isEmpty) return const [];
    final where = List.filled(tokens.length, "search_key LIKE ? ESCAPE '\\'").join(' AND ');
    final variables = [
      for (final t in tokens) Variable<String>('%${_escape(t)}%'),
      Variable<String>('${_escape(tokens.first)}%'),
      Variable<int>(limit),
    ];
    final rows = await _db
        .customSelect(
          'SELECT * FROM drug_catalog WHERE $where '
          "ORDER BY CASE WHEN search_key LIKE ? ESCAPE '\\' THEN 0 ELSE 1 END, "
          'LENGTH(name), name LIMIT ?',
          variables: variables,
          readsFrom: {_db.drugCatalogEntries},
        )
        .get();
    return [for (final r in rows) _db.drugCatalogEntries.map(r.data)];
  }

  /// LIKE özel karakterlerini (% _ \) kaçırır.
  String _escape(String s) =>
      s.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
}
