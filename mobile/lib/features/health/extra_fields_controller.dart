// Günlük ekranındaki "Ek alanlar" bölümünün durumu: açık alanlar, kullanıcının
// yazdığı/seçtiği değerler, doğrulama ve kaydetme. Çekirdek dört alandan (uyku,
// su, ruh hali, enerji) bağımsızdır; onlar `daily_logs`'a kendi akışıyla yazılır.

import 'package:flutter/material.dart';

import '../../data/database/app_database.dart';
import '../../data/database/enums.dart';
import '../../domain/services/daily_field_service.dart';

enum ExtraFieldsStatus { loading, ready, failed }

class ExtraFieldsController extends ChangeNotifier {
  ExtraFieldsController({
    required this.service,
    required this.day,
    required this.formatNumber,
  });

  final DailyFieldService service;

  /// Değerlerin yazılacağı ve okunacağı gün ('YYYY-MM-DD').
  final String day;

  /// Sayıyı alanda gösterilecek metne çevirir (yerel ondalık ayracıyla).
  final String Function(double) formatNumber;

  ExtraFieldsStatus status = ExtraFieldsStatus.loading;

  /// Açık alanlar, sıraya göre.
  List<DailyField> fields = const [];

  final _texts = <String, TextEditingController>{};
  final _picked = <String, double?>{};

  /// Veritabanından okunan (ya da son kaydedilen) değerler; değişmeyen alana
  /// yazılmaz.
  final _initial = <String, double?>{};

  TextEditingController textOf(String id) => _texts[id]!;

  /// Ölçek ve evet/hayır alanlarında seçili değer (yoksa null).
  double? pickedOf(String id) => _picked[id];

  /// Seçili değere yeniden dokunmak seçimi kaldırır.
  void pick(String id, double value) {
    _picked[id] = _picked[id] == value ? null : value;
    notifyListeners();
  }

  /// Hazır alanları (yoksa) ekler ve açık alanlarla bugünkü değerleri okur.
  /// Okunamazsa bölüm gizlenir ve günlük kaydı yine de kaydedilebilir.
  Future<void> load() async {
    try {
      await service.ensurePresets();
      await _sync();
      status = ExtraFieldsStatus.ready;
    } catch (_) {
      status = ExtraFieldsStatus.failed;
    }
    notifyListeners();
  }

  /// Alan yönetiminden dönünce: yazılmış değerleri koruyarak açık alan listesini
  /// yeniler.
  Future<void> reloadFields() async {
    try {
      await _sync();
      status = ExtraFieldsStatus.ready;
    } catch (_) {
      // Yenilenemezse eldeki liste kalır.
    }
    notifyListeners();
  }

  Future<void> _sync() async {
    final active = await service.listActive();
    final values = await service.valuesForDay(day);
    final byId = {for (final v in values) v.field.id: v.value};
    final ids = active.map((f) => f.id).toSet();

    for (final id in _texts.keys.toList()) {
      if (!ids.contains(id)) _texts.remove(id)?.dispose();
    }
    _picked.removeWhere((id, _) => !ids.contains(id));
    _initial.removeWhere((id, _) => !ids.contains(id));

    for (final f in active) {
      if (_initial.containsKey(f.id)) continue; // kullanıcının yazdığı kalır
      final v = byId[f.id];
      _initial[f.id] = v;
      if (f.kind == DailyFieldKinds.number) {
        _texts[f.id] = TextEditingController(
          text: v == null ? '' : formatNumber(v),
        );
      } else {
        _picked[f.id] = v;
      }
    }
    fields = active;
  }

  /// Alanın şimdiki değeri: boşsa null, okunamayan metinse NaN.
  double? _current(DailyField f) {
    if (f.kind != DailyFieldKinds.number) return _picked[f.id];
    final t = _texts[f.id]?.text.trim() ?? '';
    if (t.isEmpty) return null;
    return double.tryParse(t.replaceAll(',', '.')) ?? double.nan;
  }

  /// Geçersiz değeri olan ilk alan; hepsi geçerliyse null.
  DailyField? firstInvalid() {
    if (status != ExtraFieldsStatus.ready) return null;
    for (final f in fields) {
      final v = _current(f);
      if (v == null) continue;
      if (!v.isFinite || v < f.minValue || v > f.maxValue) return f;
    }
    return null;
  }

  double _round(double v) => (v * 10).roundToDouble() / 10;

  /// Değişen alanları yazar: dolu ve farklıysa değer yazılır, boşaltılmışsa o
  /// günün değeri silinir. Bölüm yüklenmediyse hiçbir şey yapmaz. Hata olursa
  /// fırlatır; o ana kadar yazılanlar kalır, yazılamayanlar bir sonraki
  /// denemede yeniden denenir.
  Future<void> save() async {
    if (status != ExtraFieldsStatus.ready) return;
    for (final f in fields) {
      final cur = _current(f);
      final now = cur == null ? null : _round(cur);
      final before = _initial[f.id];
      if (now == before) continue;
      if (now == null) {
        await service.clearValue(f.id, day);
      } else {
        await service.setValue(f.id, day, now);
      }
      _initial[f.id] = now;
    }
  }

  @override
  void dispose() {
    for (final c in _texts.values) {
      c.dispose();
    }
    super.dispose();
  }
}
