import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:uuid/uuid.dart';

import 'app_database.dart';

/// Uygulamanın içindeki başlangıç dosyalarından (assets/seed/) semptom ve ilaç
/// kataloğunu veritabanına yükler.
///
/// * Kimlikler dosyadaki `key`'den türetilir (UUID v5), böylece aynı kayıt her
///   cihazda ve her yüklemede aynı kimliği taşır.
/// * Yükleme tekrarlanabilir: var olan kayıtlara dokunmaz (kullanıcı bir
///   kataloğu silerse geri gelmez), yalnızca eksikleri ekler.
class SeedLoader {
  SeedLoader(
    this._db, {
    Future<String> Function(String path)? loadAsset,
    DateTime Function()? clock,
  })  : _loadAsset = loadAsset ?? rootBundle.loadString,
        _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final Future<String> Function(String path) _loadAsset;
  final DateTime Function() _clock;

  static const _uuid = Uuid();

  /// Katalog kimliklerinin türetildiği ad alanı. DEĞİŞTİRİLMEMELİ.
  static const _namespace = 'a1b2c3d4-5e6f-4a7b-8c9d-0e1f2a3b4c5d';

  static String symptomId(String key) =>
      _uuid.v5(_namespace, 'vitapuls:symptom:$key');
  static String medicationId(String key) =>
      _uuid.v5(_namespace, 'vitapuls:medication:$key');

  Future<void> seedIfNeeded() async {
    final now = _clock();
    final symptoms = _decode(await _loadAsset('assets/seed/symptoms.json'));
    final medications =
        _decode(await _loadAsset('assets/seed/medications.json'));

    await _db.transaction(() async {
      for (final s in symptoms) {
        await _db.into(_db.symptoms).insert(
              SymptomsCompanion.insert(
                id: symptomId(s['key'] as String),
                createdAt: now,
                updatedAt: now,
                name: s['name'] as String,
                category: Value(s['category'] as String? ?? 'genel'),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
      for (final m in medications) {
        await _db.into(_db.medications).insert(
              MedicationsCompanion.insert(
                id: medicationId(m['key'] as String),
                createdAt: now,
                updatedAt: now,
                name: m['name'] as String,
                isCatalog: const Value(true),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    });
  }

  List<Map<String, dynamic>> _decode(String json) =>
      (jsonDecode(json) as List).cast<Map<String, dynamic>>();
}
