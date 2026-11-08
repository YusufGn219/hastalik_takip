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

/// Alerji metninin en çok uzunluğu (satırlar kırpılıp boş satırlar atıldıktan sonra).
const maxAllergiesLength = 1000;

/// Acil durum telefonundaki rakam sayısı sınırları.
const minPhoneDigits = 7;
const maxPhoneDigits = 15;

/// Tek satırlık yerel profil. Satır yoksa ilk okumada varsayılanlarla açılır.
abstract class ProfileRepository {
  Future<Profile> get();

  /// Yalnız dolu (`Value`) alanları yazar; `updatedAt` otomatik güncellenir.
  /// Ad, soyad, alerjiler (satır satır) ve acil durum kişisi kırpılarak saklanır;
  /// boş acil durum adı/telefonu "yok" (null) olur. Geçersiz değerde
  /// [ArgumentError] fırlatır ve hiçbir şey yazılmaz; hatanın `name` alanı
  /// sorunlu alanın adını verir.
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
      return _db
          .into(_db.profiles)
          .insertReturning(
            ProfilesCompanion.insert(
              id: _newId(),
              createdAt: now,
              updatedAt: now,
            ),
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
          value,
          field,
          'en çok $maxProfileNameLength karakter olabilir',
        );
      }
      return trimmed;
    }

    if (c.firstName.present) {
      out = out.copyWith(
        firstName: Value(name('firstName', c.firstName.value)),
      );
    }
    if (c.lastName.present) {
      out = out.copyWith(lastName: Value(name('lastName', c.lastName.value)));
    }

    if (c.birthDate.present) {
      final day = c.birthDate.value;
      if (day != null && !_isValidBirthDay(day)) {
        throw ArgumentError.value(
          day,
          'birthDate',
          'geçerli bir YYYY-MM-DD günü olmalı, gelecekte olmamalı',
        );
      }
    }

    if (c.gender.present) {
      final gender = c.gender.value;
      if (gender != null && !Genders.all.contains(gender)) {
        throw ArgumentError.value(gender, 'gender', 'bilinmeyen değer');
      }
    }

    if (c.bloodType.present) {
      final blood = c.bloodType.value;
      if (blood != null && !BloodTypes.all.contains(blood)) {
        throw ArgumentError.value(blood, 'bloodType', 'bilinmeyen değer');
      }
    }

    if (c.allergies.present) {
      // Her satır bir alerji: satırlar kırpılır, boş satırlar atılır.
      final lines = c.allergies.value
          .split(RegExp(r'\r?\n'))
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      final text = lines.join('\n');

      if (text.length > maxAllergiesLength) {
        throw ArgumentError.value(
          text.length,
          'allergies',
          'en çok $maxAllergiesLength karakter olabilir',
        );
      }
      out = out.copyWith(allergies: Value(text));
    }

    if (c.emergencyContactName.present) {
      final raw = c.emergencyContactName.value?.trim() ?? '';
      if (raw.length > maxProfileNameLength) {
        throw ArgumentError.value(
          raw.length,
          'emergencyContactName',
          'en çok $maxProfileNameLength karakter olabilir',
        );
      }
      out = out.copyWith(emergencyContactName: Value(raw.isEmpty ? null : raw));
    }

    if (c.emergencyContactPhone.present) {
      final raw = c.emergencyContactPhone.value?.trim() ?? '';
      if (raw.isNotEmpty && !_isValidPhone(raw)) {
        throw ArgumentError.value(
          raw,
          'emergencyContactPhone',
          'rakam, boşluk, -, ( ) ve baştaki + olabilir; $minPhoneDigits-$maxPhoneDigits rakam',
        );
      }
      out = out.copyWith(
        emergencyContactPhone: Value(raw.isEmpty ? null : raw),
      );
    }

    if (c.photo.present) {
      final photo = c.photo.value;
      if (photo != null && !_isAcceptablePhoto(photo)) {
        throw ArgumentError.value(
          photo.length,
          'photo',
          'boş olamaz, en çok $maxProfilePhotoBytes bayt',
        );
      }
    }
    return out;
  }

  /// Yalnız rakam, boşluk, '-', '(' ')' ve en baştaki '+'; rakam sayısı sınırlı.
  bool _isValidPhone(String phone) {
    if (!RegExp(r'^\+?[0-9 ()\-]+$').hasMatch(phone)) return false;
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '').length;
    return digits >= minPhoneDigits && digits <= maxPhoneDigits;
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
