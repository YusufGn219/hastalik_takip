// Sağlık kartı: kan grubu, alerjiler, acil durum kişisi (ad + telefon).

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/enums.dart';
import 'package:mobile/data/repositories/profile_repository.dart';

import 'test_support.dart';

/// Hata, sorunlu alanın adını `name` ile verir.
Matcher invalidField(String name) =>
    throwsA(isA<ArgumentError>().having((e) => e.name, 'name', name));

void main() {
  late AppDatabase db;
  late DriftProfileRepository repo;

  setUp(() {
    db = createTestDb();
    repo = DriftProfileRepository(db, clock: () => DateTime(2026, 11, 8, 12));
  });
  tearDown(() => db.close());

  test('yeni profilde sağlık kartı boş', () async {
    final p = await repo.get();
    expect(p.bloodType, isNull);
    expect(p.allergies, '');
    expect(p.emergencyContactName, isNull);
    expect(p.emergencyContactPhone, isNull);
  });

  group('kan grubu', () {
    test('sekiz grubun hepsi kabul edilir; null ile temizlenir', () async {
      for (final b in BloodTypes.all) {
        expect((await repo.save(ProfilesCompanion(bloodType: Value(b)))).bloodType, b);
      }
      expect(BloodTypes.all, hasLength(8));
      expect((await repo.save(const ProfilesCompanion(bloodType: Value(null)))).bloodType, isNull);
    });

    test('bilinmeyen değer reddedilir ve hiçbir şey yazılmaz', () async {
      await repo.save(const ProfilesCompanion(bloodType: Value('A+')));
      for (final bad in ['C+', 'a+', '0 Rh+', 'AB', '']) {
        expect(() => repo.save(ProfilesCompanion(bloodType: Value(bad))), invalidField('bloodType'),
            reason: bad);
      }
      expect((await repo.get()).bloodType, 'A+');
    });
  });

  group('alerjiler', () {
    test('satırlar kırpılır, boş satırlar atılır, satır sonları tek tip olur', () async {
      final saved = await repo.save(const ProfilesCompanion(
        allergies: Value('  penisilin \r\n\r\n fıstık\n   \n polen  '),
      ));
      expect(saved.allergies, 'penisilin\nfıstık\npolen');
    });

    test('boş metin kabul edilir (alerji yok)', () async {
      await repo.save(const ProfilesCompanion(allergies: Value('penisilin')));
      expect((await repo.save(const ProfilesCompanion(allergies: Value('  \n '))) ).allergies, '');
    });

    test('1000 karaktere kadar kabul edilir, fazlası reddedilir', () async {
      final ok = 'a' * maxAllergiesLength;
      expect((await repo.save(ProfilesCompanion(allergies: Value(ok)))).allergies, ok);
      expect(() => repo.save(ProfilesCompanion(allergies: Value('a' * (maxAllergiesLength + 1)))),
          invalidField('allergies'));
      expect((await repo.get()).allergies, ok);
    });

    test('sınır kırpıldıktan sonra ölçülür: boşluklar sayılmaz', () async {
      final padded = '${' ' * 50}${'a' * maxAllergiesLength}${' ' * 50}';
      expect((await repo.save(ProfilesCompanion(allergies: Value(padded)))).allergies.length,
          maxAllergiesLength);
    });
  });

  group('acil durum kişisi', () {
    test('ad kırpılır; boş ad "yok" (null) olur', () async {
      expect((await repo.save(const ProfilesCompanion(emergencyContactName: Value('  Ayşe  '))))
          .emergencyContactName, 'Ayşe');
      expect((await repo.save(const ProfilesCompanion(emergencyContactName: Value('   '))))
          .emergencyContactName, isNull);
      await repo.save(const ProfilesCompanion(emergencyContactName: Value('Ayşe')));
      expect((await repo.save(const ProfilesCompanion(emergencyContactName: Value(null))))
          .emergencyContactName, isNull);
    });

    test('ad 60 karaktere kadar kabul edilir, fazlası reddedilir', () async {
      final ok = 'a' * maxProfileNameLength;
      expect((await repo.save(ProfilesCompanion(emergencyContactName: Value(ok)))).emergencyContactName, ok);
      expect(
        () => repo.save(ProfilesCompanion(emergencyContactName: Value('a' * (maxProfileNameLength + 1)))),
        invalidField('emergencyContactName'),
      );
    });

    test('telefon: geçerli yazımlar kabul edilir, kırpılır', () async {
      for (final ok in ['0532 123 45 67', '+90 (532) 123-45-67', '1234567', '+123456789012345', '  05321234567  ']) {
        final saved = await repo.save(ProfilesCompanion(emergencyContactPhone: Value(ok)));
        expect(saved.emergencyContactPhone, ok.trim(), reason: ok);
      }
    });

    test('telefon: boş ya da null "yok" olur', () async {
      await repo.save(const ProfilesCompanion(emergencyContactPhone: Value('05321234567')));
      expect((await repo.save(const ProfilesCompanion(emergencyContactPhone: Value('  ')))).emergencyContactPhone,
          isNull);
      await repo.save(const ProfilesCompanion(emergencyContactPhone: Value('05321234567')));
      expect((await repo.save(const ProfilesCompanion(emergencyContactPhone: Value(null)))).emergencyContactPhone,
          isNull);
    });

    test('telefon: harf, kısa, uzun ve yanlış yerdeki + reddedilir; hiçbir şey yazılmaz', () async {
      await repo.save(const ProfilesCompanion(emergencyContactPhone: Value('05321234567')));
      for (final bad in ['abc', '053212', '+1234567890123456', '0532-abc-4567', '0532+1234567', '++905321234567', '0532.123.4567']) {
        expect(() => repo.save(ProfilesCompanion(emergencyContactPhone: Value(bad))),
            invalidField('emergencyContactPhone'), reason: bad);
      }
      expect((await repo.get()).emergencyContactPhone, '05321234567');
    });
  });

  test('geçersiz bir alan, aynı kaydın geçerli alanlarını da yazdırmaz', () async {
    await expectLater(
      repo.save(const ProfilesCompanion(
        bloodType: Value('A+'),
        allergies: Value('fıstık'),
        emergencyContactPhone: Value('abc'),
      )),
      invalidField('emergencyContactPhone'),
    );
    final p = await repo.get();
    expect(p.bloodType, isNull);
    expect(p.allergies, '');
  });

  test('kimlik alanlarına dokunmadan sağlık kartı yazılır', () async {
    await repo.save(const ProfilesCompanion(firstName: Value('Ada'), birthDate: Value('1990-05-17')));
    final after = await repo.save(const ProfilesCompanion(bloodType: Value('0-')));
    expect(after.firstName, 'Ada');
    expect(after.birthDate, '1990-05-17');
    expect(after.bloodType, '0-');
  });
}
