import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/repositories/profile_repository.dart';

/// Bellek içi profil; ekran testlerinde gerçek veritabanı gerekmez. Kaydedilen
/// her istek [saves] listesine girer. `failLoads` / `failSaves` hata yollarını
/// dener.
class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository({Profile? initial, this.failLoads = 0, this.failSaves = false})
      : current = initial ?? emptyProfile();

  Profile current;

  /// Sıradaki bu kadar `get` çağrısı hata verir.
  int failLoads;
  bool failSaves;

  /// Doluysa `save` bu hatayı fırlatır (ör. alan adlı [ArgumentError]).
  Object? saveError;
  final saves = <ProfilesCompanion>[];

  static Profile emptyProfile() => Profile(
        id: 'p1',
        createdAt: DateTime.utc(2026, 11, 8),
        updatedAt: DateTime.utc(2026, 11, 8),
        firstName: '',
        lastName: '',
        allergies: '',
        cycleTrackingEnabled: false,
      );

  @override
  Future<Profile> get() async {
    if (failLoads > 0) {
      failLoads--;
      throw StateError('okunamadı');
    }
    return current;
  }

  @override
  Future<Profile> save(ProfilesCompanion changes) async {
    if (failSaves) throw StateError('yazılamadı');
    if (saveError != null) throw saveError!;
    saves.add(changes);
    current = current.copyWith(
      firstName: changes.firstName.present ? changes.firstName.value : null,
      lastName: changes.lastName.present ? changes.lastName.value : null,
      birthDate: changes.birthDate,
      gender: changes.gender,
      photo: changes.photo,
      bloodType: changes.bloodType,
      allergies: changes.allergies.present ? changes.allergies.value : null,
      emergencyContactName: changes.emergencyContactName,
      emergencyContactPhone: changes.emergencyContactPhone,
    );
    return current;
  }

  @override
  Future<void> recordConsent(DateTime at) => throw UnimplementedError();
}
