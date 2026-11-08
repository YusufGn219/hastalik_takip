import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/enums.dart';
import 'support.dart';

/// Ad ve soyadın en çok uzunluğu (kırpıldıktan sonra).
const maxProfileNameLength = 60;

/// Profil fotoğrafının en çok boyutu (bayt). Arayüz fotoğrafı bundan çok daha
/// küçük (yaklaşık 512 piksel JPEG) kaydeder; bu sınır koruma içindir.
const maxProfilePhotoBytes = 1024 * 1024;

/// En eski kabul edilen doğum yılı.
const minBirthYear = 1900;

/// Tek satırlık yerel profil. Satır yoksa ilk okumada varsayılanlarla açılır.
abstract class ProfileRepository {
  Future<Profile> get();

  /// Yalnız dolu (`Value`) alanları yazar; `updatedAt` otomatik güncellenir.
  /// Ad ve soyad kırpılarak saklanır. Geçersiz değerde [ArgumentError] fırlatır
  /// ve hiçbir şey yazılmaz.
  Future<Profile> save(ProfilesCompanion changes);

  /// Yerel KVKK onayını kaydeder.
  Future<void> recordConsent(DateTime at);
}

class DriftProfileRepository implements ProfileRepository {
  DriftProfileRepository(this._db, {Clock? clock, IdGenerator? newId})
      : _clock = clock ?? DateTime.now,
        _newId = newId ?? newUuid;

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _newId;

  Future<Profile?> _find() {
    return (_db.select(_db.profiles)
          ..where((t) => t.deletedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
  }

  @override
  Future<Profile> get() {
    return _db.transaction(() async {
      final existing = await _find();
      if (existing != null) return existing;
      final now = _clock();
      return _db.into(_db.profiles).insertReturning(
            ProfilesCompanion.insert(id: _newId(), createdAt: now, updatedAt: now),
          );
    });
  }

  @override
  Future<Profile> save(ProfilesCompanion changes) async {
    final clean = _validated(changes);
    return _db.transaction(() async {
      final current = await get();
      await (_db.update(_db.profiles)..where((t) => t.id.equals(current.id)))
          .write(clean.copyWith(updatedAt: Value(_clock())));
      return (await _find())!;
    });
  }

  @override
  Future<void> recordConsent(DateTime at) async {
    await save(ProfilesCompanion(consentAt: Value(at)));
  }

  /// Verilen alanları denetler; ad ve soyadı kırpar. Verilmeyen alana dokunmaz.
  ProfilesCompanion _validated(ProfilesCompanion c) {
    var out = c;

    String name(String field, String value) {
      final trimmed = value.trim();
      if (trimmed.length > maxProfileNameLength) {
        throw ArgumentError.value(
            value, field, 'en çok $maxProfileNameLength karakter olabilir');
      }
      return trimmed;
    }

    if (c.firstName.present) {
      out = out.copyWith(firstName: Value(name('firstName', c.firstName.value)));
    }
    if (c.lastName.present) {
      out = out.copyWith(lastName: Value(name('lastName', c.lastName.value)));
    }

    if (c.birthDate.present) {
      final day = c.birthDate.value;
      if (day != null && !_isValidBirthDay(day)) {
        throw ArgumentError.value(day, 'birthDate',
            'geçerli bir YYYY-MM-DD günü olmalı, gelecekte olmamalı');
      }
    }

    if (c.gender.present) {
      final gender = c.gender.value;
      if (gender != null && !Genders.all.contains(gender)) {
        throw ArgumentError.value(gender, 'gender', 'bilinmeyen değer');
      }
    }

    if (c.photo.present) {
      final photo = c.photo.value;
      if (photo != null && !_isAcceptablePhoto(photo)) {
        throw ArgumentError.value(photo.length, 'photo',
            'boş olamaz, en çok $maxProfilePhotoBytes bayt');
      }
    }
    return out;
  }

  bool _isAcceptablePhoto(Uint8List bytes) =>
      bytes.isNotEmpty && bytes.length <= maxProfilePhotoBytes;

  bool _isValidBirthDay(String day) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(day);
    if (m == null) return false;
    final y = int.parse(m[1]!);
    final mo = int.parse(m[2]!);
    final d = int.parse(m[3]!);
    if (y < minBirthYear) return false;
    final parsed = DateTime.utc(y, mo, d);
    // 30 Şubat gibi günler bir sonraki aya kayar; gidiş-dönüş denetimi.
    if (parsed.year != y || parsed.month != mo || parsed.day != d) return false;
    return day.compareTo(dayKey(_clock())) <= 0;
  }
}
