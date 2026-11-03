import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/seed_loader.dart';

/// Bellek içi (şifresiz) veritabanı; her test kendi kopyasını açar.
AppDatabase createTestDb() => AppDatabase(NativeDatabase.memory());

/// Test sırasında `assets/seed/` dosyalarını doğrudan diskten okur.
Future<String> readSeedFromDisk(String path) => File(path).readAsString();

SeedLoader seedLoaderFor(AppDatabase db) =>
    SeedLoader(db, loadAsset: readSeedFromDisk);

/// Sabit kimlikler üretir: id-1, id-2, ...
String Function() sequentialIds([String prefix = 'id']) {
  var i = 0;
  return () => '$prefix-${++i}';
}

/// Drift zamanları saniye hassasiyetinde saklar; testlerde tam saniye kullan.
DateTime utc(int y, int mo, int d, [int h = 0, int mi = 0, int s = 0]) =>
    DateTime.utc(y, mo, d, h, mi, s);

/// `Value` kısaltması (testlerde okunurluk için).
Value<T> v<T extends Object>(T x) => Value(x);
