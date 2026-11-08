// SENTETİK VERİ ÜRETİCİSİ (geliştirme aracı; `flutter test` takımına girmez).
//
// Son 90 güne yayılan, birbiriyle tutarlı örnek veriyi şifreli bir veritabanına
// yazar ve uygulamanın "Yedekten geri yükle" ekranıyla açılabilen bir `.vpbak`
// dosyası üretir. Amaç: trend ve istatistik ekranlarını gerçeğe yakın veriyle
// görmek. Veri sabit rastgele tohumla üretilir (her çalıştırmada aynı).
//
// Kullanım (mobile/ klasöründe):
//   flutter test tool/synthetic_seed_test.dart --dart-define=OUT=C:/yol/sentetik.vpbak
// Yedek parolası: sentetik-veri-2026
//
// Veride kurulan ilişkiler (ekranlarda görünmesi beklenen örüntüler):
//  * Stres yüksek / uyku kısa / kafein fazla günlerde baş ağrısı olasılığı artar.
//  * Uyku ruh halini ve enerjiyi yukarı çeker; hafta sonu uyku uzar.
//  * Baş ağrısı dönemlerinde ilaç alımından sonra şiddet düşer (ilaç etkisi).
//  * Rutin ilaç uyumu 90 gün içinde yavaşça artar (%68 → %94 civarı).
//  * 7 günlük bir soğuk algınlığı (öksürük, ilk iki gün ateş).
//  * Kilo yavaşça düşer; ek alanlar (kafein, spor, ağrı düzeyi, stres) dolar.

import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/backup/backup_service.dart';
import 'package:mobile/data/database/database_opener.dart';
import 'package:mobile/data/database/enums.dart';
import 'package:mobile/data/database/app_database.dart';
import 'package:mobile/data/database/seed_loader.dart';
import 'package:mobile/data/repositories/daily_field_repository.dart';
import 'package:mobile/data/repositories/daily_log_repository.dart';
import 'package:mobile/data/repositories/dose_skip_repository.dart';
import 'package:mobile/data/repositories/episode_repository.dart';
import 'package:mobile/data/repositories/measurement_repository.dart';
import 'package:mobile/data/repositories/medication_log_repository.dart';
import 'package:mobile/data/repositories/medication_repository.dart';
import 'package:mobile/data/repositories/profile_repository.dart';
import 'package:mobile/data/repositories/support.dart';
import 'package:mobile/data/repositories/symptom_entry_repository.dart';
import 'package:mobile/domain/services/daily_field_service.dart';

import '../test/data/test_support.dart';

const _key = 'c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3';
const _passphrase = 'sentetik-veri-2026';
const _days = 90;

void main() {
  test('sentetik veri üret ve .vpbak olarak yaz', () async {
    const out = String.fromEnvironment('OUT');
    expect(out, isNotEmpty, reason: '--dart-define=OUT=<hedef .vpbak yolu> verin');

    final dir = Directory.systemTemp.createTempSync('vp_synth_');
    final dbFile = File('${dir.path}/vitapuls.db');
    final db = openEncryptedDatabase(dbFile, _key);
    final stats = await _generate(db);
    await db.close();

    final target = File(out);
    target.parent.createSync(recursive: true);
    await BackupService(currentSchemaVersion: db.schemaVersion).export(
      database: dbFile,
      hexKey: _key,
      target: target,
      passphrase: _passphrase,
    );
    dir.deleteSync(recursive: true);

    // ignore: avoid_print
    print('SENTETIK VERI: $stats\nYedek: $out (${target.lengthSync()} bayt), parola: $_passphrase');
  }, timeout: const Timeout(Duration(minutes: 10)));
}

Future<Map<String, int>> _generate(AppDatabase db) async {
  final rng = math.Random(20261108);
  double g() {
    final u1 = 1 - rng.nextDouble();
    final u2 = rng.nextDouble();
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
  }

  double clamp(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);
  double r1(double v) => (v * 10).roundToDouble() / 10;

  await seedLoaderFor(db).seedIfNeeded();

  final episodes = DriftEpisodeRepository(db);
  final entries = DriftSymptomEntryRepository(db);
  final logs = DriftMedicationLogRepository(db);
  final skips = DriftDoseSkipRepository(db);
  final meds = DriftMedicationRepository(db);
  final dailyLogs = DriftDailyLogRepository(db);
  final measurements = DriftMeasurementRepository(db);
  final profile = DriftProfileRepository(db);
  final fields = DailyFieldService(
    fields: DriftDailyFieldRepository(db),
    measurements: measurements,
    clock: DateTime.now,
    transactor: db.transaction,
  );

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  DateTime dayOf(int daysAgo) => DateTime(today.year, today.month, today.day - daysAgo);

  final headache = SeedLoader.symptomId('headache');
  final fever = SeedLoader.symptomId('fever');
  final cough = SeedLoader.symptomId('cough');
  final fatigue = SeedLoader.symptomId('fatigue');
  final nausea = SeedLoader.symptomId('nausea');
  final abdominal = SeedLoader.symptomId('abdominal_pain');
  final dizziness = SeedLoader.symptomId('dizziness');
  final parol = SeedLoader.medicationId('parol');
  final aspirin = SeedLoader.medicationId('aspirin');
  final nurofen = SeedLoader.medicationId('nurofen');
  final majezik = SeedLoader.medicationId('majezik');
  final vitD = SeedLoader.medicationId('vitamin_d');
  final magnesium = SeedLoader.medicationId('magnesium');
  final omega = SeedLoader.medicationId('omega_3');
  final b12 = SeedLoader.medicationId('vitamin_b12');

  final stats = <String, int>{
    'gunluk_kayit': 0,
    'bas_agrisi_donemi': 0,
    'semptom_girisi': 0,
    'ilac_alimi': 0,
    'atlanan_doz': 0,
    'kilo': 0,
  };

  // ------------------------------------------------------------- profil
  await profile.save(const ProfilesCompanion(
    firstName: Value('Deneme'),
    lastName: Value('Kullanıcı'),
    birthDate: Value('1990-05-15'),
    bloodType: Value('A+'),
    allergies: Value('Polen'),
  ));
  await meds.createCondition(name: 'Migren (örnek)', medicationIds: [parol, aspirin]);

  // ------------------------------------------------------- ek günlük alanlar
  await fields.ensurePresets();
  for (final f in await fields.list()) {
    if (f.builtinKey != null) await fields.setActive(f.id, true);
  }
  final caffeineField = (await fields.list()).firstWhere((f) => f.builtinKey == MeasurementTypes.caffeine);
  final exerciseField = (await fields.list()).firstWhere((f) => f.builtinKey == MeasurementTypes.exercise);
  final painField = (await fields.list()).firstWhere((f) => f.builtinKey == MeasurementTypes.pain);
  final stressField = await fields.create(name: 'Stres', kind: DailyFieldKinds.scale);

  // ------------------------------------------------------------- rutinler
  // (ilaç, saatler, günler [null = her gün], sayaç anahtarı)
  final routines = <({String id, List<String> times, List<String>? days, int startedDaysAgo})>[
    (id: vitD, times: ['08:00'], days: null, startedDaysAgo: 90),
    (id: magnesium, times: ['21:30'], days: null, startedDaysAgo: 90),
    (id: omega, times: ['08:00', '20:00'], days: null, startedDaysAgo: 75),
    (id: b12, times: ['12:00'], days: ['monday', 'thursday'], startedDaysAgo: 40),
  ];
  for (final r in routines) {
    await meds.setRecurrence(
      r.id,
      isRecurring: true,
      recurringTime: r.times.join(','),
      recurringDays: r.days,
    );
    await meds.ensureNotificationId(r.id);
  }
  const weekdayNames = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];

  // ----------------------------------------------------------------- boy
  await measurements.add(
    type: MeasurementTypes.height,
    value: 178,
    unit: 'cm',
    measuredAt: DateTime(dayOf(_days - 1).year, dayOf(_days - 1).month, dayOf(_days - 1).day, 12),
  );

  // Soğuk algınlığı: 52..46 gün önce (7 gün).
  const coldStart = 52, coldEnd = 46;

  for (var i = _days - 1; i >= 0; i--) {
    final date = dayOf(i);
    final key = dayKey(date);
    final weekend = date.weekday >= 6;

    // Gizli gerilim: yavaş dalga + gürültü + 38-46 gün önce yoğun bir dönem.
    var stress = 0.9 * math.sin(i / 8.0) + 0.5 * g();
    if (i >= 38 && i <= 46) stress += 1.2;

    final exerciseDay = (date.weekday == 1 || date.weekday == 3 || date.weekday == 6) && rng.nextDouble() < 0.8;
    final exerciseMin = exerciseDay ? (25 + rng.nextInt(40)).toDouble() : 0.0;
    final sleep = r1(clamp(7.1 + (weekend ? 0.8 : 0) - 0.55 * stress + 0.6 * g(), 4.5, 9.5));
    final caffeine = clamp((2.3 + 0.9 * stress + 0.8 * g()).roundToDouble(), 0, 9);
    final water = r1(clamp(1.9 + 0.25 * g() - 0.15 * stress + (exerciseDay ? 0.3 : 0), 0.8, 3.4));
    final mood = clamp((3.2 + 0.45 * (sleep - 7) - 0.35 * stress + 0.6 * g()).roundToDouble(), 1, 5).toInt();
    final energy =
        clamp((3.1 + 0.55 * (sleep - 7) - 0.25 * math.max(0, caffeine - 4) + 0.6 * g()).roundToDouble(), 1, 5)
            .toInt();

    // Günlük kayıt ve ek alanlar (günlerin ~%5'i hiç girilmez; bugün her zaman).
    final logged = i == 0 || rng.nextDouble() > 0.05;
    if (logged) {
      await dailyLogs.upsert(
        logDate: key,
        sleepHours: sleep,
        waterIntake: water,
        mood: mood,
        energyLevel: energy,
      );
      stats['gunluk_kayit'] = stats['gunluk_kayit']! + 1;
      await fields.setValue(caffeineField.id, key, caffeine);
      if (exerciseMin > 0) await fields.setValue(exerciseField.id, key, exerciseMin);
      await fields.setValue(stressField.id, key, clamp((3 + stress).roundToDouble(), 1, 5));
    }

    // Bugün için olay üretilmez (geleceğe taşan saat olmasın).
    if (i == 0) continue;

    // ----------------------------------------------------------- baş ağrısı
    final logit = -2.0 + 0.8 * stress + 0.35 * (caffeine - 3) - 0.5 * (sleep - 7);
    final headacheToday = rng.nextDouble() < 1 / (1 + math.exp(-logit));
    if (headacheToday) {
      final start = DateTime(date.year, date.month, date.day, 8 + rng.nextInt(12), rng.nextInt(60));
      final s0 = clamp((5 + stress * 0.8 + g() * 1.2).roundToDouble(), 3, 9).toInt();
      final ep = await episodes.start(symptomId: headache, startTime: start);
      if (rng.nextDouble() < 0.6) {
        await episodes.addLocation(
          episodeId: ep.id,
          location: rng.nextBool() ? 'Şakak' : 'Alın',
          addedAt: start,
        );
      }

      final takeMed = rng.nextDouble() < 0.85;
      String? medId;
      double drop = 0;
      if (takeMed) {
        final pick = rng.nextDouble();
        if (pick < 0.65) {
          medId = parol;
          drop = 2.5;
        } else if (pick < 0.85) {
          medId = aspirin;
          drop = 2;
        } else if (pick < 0.93) {
          medId = nurofen;
          drop = 3.5;
        } else {
          medId = majezik;
          drop = 3;
        }
      }

      Future<void> entry(int minutes, int severity) async {
        await entries.create(
          symptomId: headache,
          severity: severity.clamp(1, 10),
          timestamp: start.add(Duration(minutes: minutes)),
          episodeId: ep.id,
        );
        stats['semptom_girisi'] = stats['semptom_girisi']! + 1;
      }

      await entry(0, s0);
      if (medId != null) {
        await logs.create(
          medicationId: medId,
          takenAt: start.add(const Duration(minutes: 10)),
          doseAmount: 1,
          doseUnit: DoseUnit.tablet,
          episodeId: ep.id,
        );
        stats['ilac_alimi'] = stats['ilac_alimi']! + 1;
        await entry(40, (s0 - drop * 0.5).round());
        await entry(100, (s0 - drop).round());
        await entry(200, (s0 - drop - 1).round());
      } else {
        await entry(60, s0 - (rng.nextBool() ? 0 : 1));
        await entry(150, s0 - 1);
        await entry(240, s0 - 2);
      }
      await episodes.markResolved(
        id: ep.id,
        endedAt: start.add(Duration(minutes: medId != null ? 220 : 300)),
        resolutionNotes: medId != null ? 'İlaçla geçti' : 'Kendiliğinden geçti',
      );
      stats['bas_agrisi_donemi'] = stats['bas_agrisi_donemi']! + 1;
      if (logged) await fields.setValue(painField.id, key, clamp(s0.toDouble(), 0, 10));
    }

    // -------------------------------------------------- diğer semptomlar
    Future<void> plain(String symptomId, int hour, int severity) async {
      await entries.create(
        symptomId: symptomId,
        severity: severity.clamp(1, 10),
        timestamp: DateTime(date.year, date.month, date.day, hour, rng.nextInt(60)),
      );
      stats['semptom_girisi'] = stats['semptom_girisi']! + 1;
    }

    if (energy <= 2 && rng.nextDouble() < 0.6) await plain(fatigue, 15, (7 - energy * 1.2).round());
    if (rng.nextDouble() < 0.04) await plain(nausea, 13, 3 + rng.nextInt(4));
    if (rng.nextDouble() < 0.03) await plain(abdominal, 19, 3 + rng.nextInt(4));
    if (rng.nextDouble() < 0.02) await plain(dizziness, 11, 2 + rng.nextInt(3));

    if (i <= coldStart && i >= coldEnd) {
      final n = coldStart - i; // 0..6
      await plain(cough, 9, 6 - n ~/ 1 > 1 ? 6 - n : 2);
      await plain(cough, 21, 6 - n ~/ 1 > 1 ? 6 - n : 2);
      if (n <= 1) {
        await plain(fever, 18, 5 - n);
        final t = DateTime(date.year, date.month, date.day, 18, 30);
        await logs.create(medicationId: parol, takenAt: t, doseAmount: 1, doseUnit: DoseUnit.tablet);
        stats['ilac_alimi'] = stats['ilac_alimi']! + 1;
      }
    }

    // -------------------------------------------------- rutin dozlar
    final progress = (_days - 1 - i) / (_days - 1); // 0..1
    final takenRate = 0.68 + 0.26 * progress;
    for (final r in routines) {
      if (i > r.startedDaysAgo) continue;
      if (r.days != null && !r.days!.contains(weekdayNames[date.weekday - 1])) continue;
      for (final time in r.times) {
        final hh = int.parse(time.substring(0, 2));
        final mm = int.parse(time.substring(3, 5));
        final planned = DateTime(date.year, date.month, date.day, hh, mm);
        final roll = rng.nextDouble();
        if (roll < takenRate) {
          await logs.create(
            medicationId: r.id,
            takenAt: planned.add(Duration(minutes: rng.nextInt(95) - 5)),
            doseAmount: 1,
            doseUnit: DoseUnit.capsule,
            scheduledTime: time,
            scheduledDay: key,
          );
          stats['ilac_alimi'] = stats['ilac_alimi']! + 1;
        } else if (roll < takenRate + 0.06) {
          await skips.create(
            medicationId: r.id,
            scheduledDay: key,
            scheduledTime: time,
            skippedAt: planned.add(const Duration(minutes: 30)),
          );
          stats['atlanan_doz'] = stats['atlanan_doz']! + 1;
        }
        // Kalanı "kaydedilmedi" bırakılır.
      }
    }

    // ----------------------------------------------------------------- kilo
    if (i % 3 == 0) {
      final w = r1(79.0 - 0.025 * (_days - 1 - i) + 0.3 * g());
      await measurements.add(
        type: MeasurementTypes.weight,
        value: w,
        unit: 'kg',
        measuredAt: DateTime(date.year, date.month, date.day, 8, 15),
      );
      stats['kilo'] = stats['kilo']! + 1;
    }
  }
  return stats;
}
