// Şema 4: profil kimliği (ad, soyad, doğum tarihi, cinsiyet, fotoğraf) ve
// 3 → 4 geçişi.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/enums.dart';
import 'package:mobile/data/repositories/profile_repository.dart';

import 'test_support.dart';

void main() {
  late AppDatabase db;
  late DriftProfileRepository repo;

  // "Bugün" sabit: 2026-11-08.
  setUp(() {
    db = createTestDb();
    repo = DriftProfileRepository(db, clock: () => DateTime(2026, 11, 8, 12));
  });
  tearDown(() => db.close());

  group('kimlik alanları', () {
    test('yeni profilde ad, soyad, doğum tarihi, cinsiyet ve fotoğraf boş', () async {
      final p = await repo.get();
      expect(p.firstName, '');
      expect(p.lastName, '');
      expect(p.birthDate, isNull);
      expect(p.gender, isNull);
      expect(p.photo, isNull);
    });

    test('ad ve soyad kırpılarak yazılır; ikisi de boş bırakılabilir', () async {
      final saved = await repo.save(const ProfilesCompanion(
        firstName: Value('  Yusuf '),
        lastName: Value(' Gün  '),
      ));
      expect(saved.firstName, 'Yusuf');
      expect(saved.lastName, 'Gün');

      final cleared = await repo.save(const ProfilesCompanion(
        firstName: Value(''),
        lastName: Value('   '),
      ));
      expect(cleared.firstName, '');
      expect(cleared.lastName, '');
    });

    test('verilmeyen alana dokunulmaz', () async {
      await repo.save(const ProfilesCompanion(
        firstName: Value('Ada'),
        lastName: Value('Lovelace'),
        gender: Value(Genders.female),
      ));
      final after = await repo.save(const ProfilesCompanion(
        birthDate: Value('1990-05-17'),
      ));
      expect(after.firstName, 'Ada');
      expect(after.lastName, 'Lovelace');
      expect(after.gender, Genders.female);
      expect(after.birthDate, '1990-05-17');
    });

    test('ad 60 karaktere kadar kabul edilir, fazlası reddedilir', () async {
      final ok = 'a' * maxProfileNameLength;
      expect((await repo.save(ProfilesCompanion(firstName: Value(ok)))).firstName, ok);
      expect(
        () => repo.save(ProfilesCompanion(firstName: Value('a' * (maxProfileNameLength + 1)))),
        throwsArgumentError,
      );
      expect(
        () => repo.save(ProfilesCompanion(lastName: Value('b' * (maxProfileNameLength + 1)))),
        throwsArgumentError,
      );
    });

    test('doğum tarihi: geçerli gün, bugün dahil; geçersiz ve gelecek reddedilir', () async {
      expect((await repo.save(const ProfilesCompanion(birthDate: Value('2026-11-08')))).birthDate,
          '2026-11-08');
      expect((await repo.save(const ProfilesCompanion(birthDate: Value('2024-02-29')))).birthDate,
          '2024-02-29');
      expect((await repo.save(const ProfilesCompanion(birthDate: Value(null)))).birthDate, isNull);

      for (final bad in ['2026-11-09', '2025-02-29', '2026-13-01', '1899-12-31', '17.05.1990', '1990-5-7', '']) {
        expect(
          () => repo.save(ProfilesCompanion(birthDate: Value(bad))),
          throwsArgumentError,
          reason: bad,
        );
      }
    });

    test('cinsiyet: bilinen değerler ve boş kabul edilir, başkası reddedilir', () async {
      for (final g in Genders.all) {
        expect((await repo.save(ProfilesCompanion(gender: Value(g))).then((p) => p.gender)), g);
      }
      expect((await repo.save(const ProfilesCompanion(gender: Value(null)))).gender, isNull);
      expect(() => repo.save(const ProfilesCompanion(gender: Value('x'))), throwsArgumentError);
    });

    test('geçersiz kayıt hiçbir şey yazmaz', () async {
      await repo.save(const ProfilesCompanion(firstName: Value('Ada')));
      await expectLater(
        repo.save(const ProfilesCompanion(
          firstName: Value('Başka'),
          birthDate: Value('2999-01-01'),
        )),
        throwsArgumentError,
      );
      expect((await repo.get()).firstName, 'Ada');
    });
  });

  group('fotoğraf', () {
    test('baytlar aynen saklanır ve geri okunur; null ile silinir', () async {
      final bytes = Uint8List.fromList(List.generate(300, (i) => i % 256));
      final saved = await repo.save(ProfilesCompanion(photo: Value(bytes)));
      expect(saved.photo, bytes);

      final removed = await repo.save(const ProfilesCompanion(photo: Value(null)));
      expect(removed.photo, isNull);
    });

    test('boş ve sınırı aşan fotoğraf reddedilir; sınırdaki kabul edilir', () async {
      expect(() => repo.save(ProfilesCompanion(photo: Value(Uint8List(0)))), throwsArgumentError);
      expect(
        () => repo.save(ProfilesCompanion(photo: Value(Uint8List(maxProfilePhotoBytes + 1)))),
        throwsArgumentError,
      );
      final edge = Uint8List(maxProfilePhotoBytes);
      expect((await repo.save(ProfilesCompanion(photo: Value(edge)))).photo!.length,
          maxProfilePhotoBytes);
    });
  });

  group('şema 3 → 4 geçişi', () {
    test('eski görünen ad ad alanına taşınır, diğer veri korunur, yeni yapı çalışır', () async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final raw = NativeDatabase.memory(setup: (rdb) {
        rdb.execute(oldProfilesTableV3);
        rdb.execute(
            "INSERT INTO profiles (id, created_at, updated_at, display_name, photo_path, birth_date, blood_type, allergies, gender, cycle_tracking_enabled, consent_at) "
            "VALUES ('p1', 1000, 1000, 'Yusuf', 'eski/yol.jpg', '1990-05-17', '0 Rh+', 'penisilin', 'male', 1, 5000)");
        rdb.execute('PRAGMA user_version = 3');
      });
      final old = AppDatabase(raw);
      addTearDown(old.close);

      final migrated = await DriftProfileRepository(old,
              clock: () => DateTime(2026, 11, 8, 12))
          .get();
      expect(migrated.id, 'p1');
      expect(migrated.firstName, 'Yusuf');
      expect(migrated.lastName, '');
      expect(migrated.photo, isNull);
      expect(migrated.birthDate, '1990-05-17');
      expect(migrated.bloodType, '0 Rh+');
      expect(migrated.allergies, 'penisilin');
      expect(migrated.gender, 'male');
      expect(migrated.cycleTrackingEnabled, isTrue);
      expect(migrated.consentAt, isNotNull);

      final columns = await old.customSelect('PRAGMA table_info(profiles)').get();
      final names = columns.map((r) => r.read<String>('name')).toSet();
      expect(names, containsAll(['first_name', 'last_name', 'photo']));
      expect(names, isNot(contains('display_name')));
      expect(names, isNot(contains('photo_path')));

      final saved = await DriftProfileRepository(old,
              clock: () => DateTime(2026, 11, 8, 12))
          .save(ProfilesCompanion(
        lastName: const Value('Gün'),
        photo: Value(Uint8List.fromList([1, 2, 3])),
      ));
      expect(saved.lastName, 'Gün');
      expect(saved.photo, [1, 2, 3]);
      expect((await old.select(old.profiles).get()).length, 1);

      final v = await old.customSelect('PRAGMA user_version').getSingle();
      expect(v.read<int>('user_version'), 4);
    });
  });
}
