import 'package:mobile/data/repositories/settings_repository.dart';

/// Bellek içi ayarlar; ekran testlerinde gerçek veritabanı gerekmez.
/// `failReads` / `failWrites` ile hata yolları denenir.
class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository({
    Map<String, String>? initial,
    this.failReads = false,
    this.failWrites = false,
  }) : values = {...?initial};

  final Map<String, String> values;
  final bool failReads;
  final bool failWrites;

  @override
  Future<String?> get(String key) async {
    if (failReads) throw StateError('okunamadı');
    return values[key];
  }

  @override
  Future<void> set(String key, String value) async {
    if (failWrites) throw StateError('yazılamadı');
    values[key] = value;
  }

  @override
  Future<Map<String, String>> getAll() async {
    if (failReads) throw StateError('okunamadı');
    return {...values};
  }
}
