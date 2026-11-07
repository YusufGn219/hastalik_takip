// Yerel veritabanı tabloları (Drift).
//
// Ortak kurallar (02 numaralı not, bölüm 4):
//  * Kimlik UUID (metin). Tam sayı kimlik yok.
//  * Her kayıtta created_at / updated_at / deleted_at (silme işareti).
//  * "An" alanları UTC saklanır; yanında cihazın o andaki UTC farkı (dakika)
//    ayrı sütunda tutulur (`*UtcOffsetMinutes`).
//  * "Gün" alanları yerel takvim günüdür, 'YYYY-MM-DD' metni (`logDate`, `date`).
//  * Kullanıcı (user) sütunu yok: bu cihazdaki tek kullanıcı.
//  * Hesaplanan değerler (döngü günü, ortalama vb.) tabloya yazılmaz.

import 'package:drift/drift.dart';

import 'enums.dart';

/// Tüm tablolarda ortak sütunlar.
mixin BaseColumns on Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Boş değilse kayıt silinmiş sayılır (veri fiziksel silinmez).
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// --------------------------------------------------------------- profil

/// Tek satırlık yerel profil.
class Profiles extends Table with BaseColumns {
  TextColumn get displayName => text().withDefault(const Constant(''))();

  /// Fotoğraf uygulama klasöründe tutulur; burada göreli yol.
  TextColumn get photoPath => text().nullable()();

  /// 'YYYY-MM-DD'
  TextColumn get birthDate => text().nullable()();
  TextColumn get bloodType => text().nullable()();

  /// Alerjiler serbest metin (satır satır).
  TextColumn get allergies => text().withDefault(const Constant(''))();
  TextColumn get emergencyContactName => text().nullable()();
  TextColumn get emergencyContactPhone => text().nullable()();

  /// İsteğe bağlı; "belirtmek istemiyorum" için boş bırakılır.
  TextColumn get gender => text().nullable()();

  /// Döngü takibi ayrı açma/kapama anahtarı, cinsiyet alanından bağımsız.
  BoolColumn get cycleTrackingEnabled =>
      boolean().withDefault(const Constant(false))();

  /// Yerel KVKK onayının verildiği an.
  DateTimeColumn get consentAt => dateTime().nullable()();
}

/// Anahtar-değer ayarlar (ör. hangi günlük alanlar açık). Silme işareti yok.
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

// ------------------------------------------------------------- semptom

class Symptoms extends Table with BaseColumns {
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get description => text().withDefault(const Constant(''))();

  /// Ör. 'ağrı', 'solunum', 'üreme'. Kategori listesi Sprint 7'de genişler.
  TextColumn get category => text().withDefault(const Constant('genel'))();

  /// Kullanıcının kendi eklediği semptom mu (başlangıç verisinden değil).
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
}

/// Atak / dönem (başlangıcı ve sonu olan şikâyet dönemi).
class Episodes extends Table with BaseColumns {
  TextColumn get symptomId => text().references(Symptoms, #id)();
  DateTimeColumn get startTime => dateTime()();
  IntColumn get startUtcOffsetMinutes => integer()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  IntColumn get endUtcOffsetMinutes => integer().nullable()();
  TextColumn get status => textEnum<EpisodeStatus>()
      .withDefault(Constant(EpisodeStatus.ongoing.name))();
  TextColumn get resolutionNotes => text().withDefault(const Constant(''))();
}

class SymptomEntries extends Table with BaseColumns {
  TextColumn get symptomId => text().references(Symptoms, #id)();
  TextColumn get episodeId => text().nullable().references(Episodes, #id)();
  IntColumn get severity => integer()();
  DateTimeColumn get timestamp => dateTime()();
  IntColumn get utcOffsetMinutes => integer()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get location => text().withDefault(const Constant(''))();
}

class EpisodeLocationEntries extends Table with BaseColumns {
  TextColumn get episodeId => text().references(Episodes, #id)();
  TextColumn get location => text().withLength(min: 1, max: 100)();
  DateTimeColumn get addedAt => dateTime()();
  IntColumn get utcOffsetMinutes => integer()();
}

// ---------------------------------------------------------------- ilaç

/// Kullanıcının kendi ilaç kategorileri (ör. "Ağrı", "Vitamin"). Katalogla
/// gelmez: her kullanıcı kendininkini oluşturur. Adı silinmemiş kayıtlar
/// arasında tekildir (kısmi dizin `app_database.dart`'ta).
class MedicationCategories extends Table with BaseColumns {
  TextColumn get name => text().withLength(min: 1, max: 100)();
}

class Medications extends Table with BaseColumns {
  TextColumn get name => text().withLength(min: 1, max: 100)();

  /// İsteğe bağlı tek kategori. Boş = kategorisiz (katalog ilaçları böyle
  /// başlar). Kategori silinince ilaç silinmez, bu alan boşalır.
  TextColumn get categoryId =>
      text().nullable().references(MedicationCategories, #id)();

  /// Başlangıç kataloğundan gelen ilaç (kullanıcının eklediği değil).
  BoolColumn get isCatalog => boolean().withDefault(const Constant(false))();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();

  /// Doz saatleri, virgülle ayrılmış 'HH:mm' listesi: "08:00" ya da
  /// "08:00,20:00" (cihaz yerel saati, sıralı, tekil). Eski kayıtlarda tek
  /// saat ya da saniyeli yazım ("08:30:00") olabilir; okuyan taraf toleranslıdır.
  TextColumn get recurringTime => text().nullable()();

  /// JSON liste: ["monday","wednesday"]. Boş/null = her gün.
  TextColumn get recurringDays => text().nullable()();

  /// Yerel bildirim için ayrı sayısal numara (UUID bildirim kimliği olamaz).
  /// Bildirim kimliği = notificationId * 10 + gün.
  IntColumn get notificationId => integer().nullable()();
}

class ChronicConditions extends Table with BaseColumns {
  TextColumn get name => text().withLength(min: 1, max: 200)();
}

/// Kronik hastalık ile ilaç arasındaki çoktan-çoğa bağlantı.
class ConditionMedications extends Table {
  TextColumn get conditionId => text().references(ChronicConditions, #id)();
  TextColumn get medicationId => text().references(Medications, #id)();

  @override
  Set<Column> get primaryKey => {conditionId, medicationId};
}

class MedicationLogs extends Table with BaseColumns {
  TextColumn get medicationId => text().references(Medications, #id)();
  DateTimeColumn get takenAt => dateTime()();
  IntColumn get utcOffsetMinutes => integer()();
  RealColumn get doseAmount => real().nullable()();
  TextColumn get doseUnit => textEnum<DoseUnit>()
      .withDefault(Constant(DoseUnit.tablet.name))();
  TextColumn get episodeId => text().nullable().references(Episodes, #id)();
  TextColumn get conditionId =>
      text().nullable().references(ChronicConditions, #id)();
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// Rutin ilacın hangi planlı dozu için alındığı: doz saati 'HH:mm' ve o dozun
  /// yerel günü 'YYYY-MM-DD'. İkisi birlikte dolu ya da birlikte boştur; boş =
  /// plansız (ekstra) alım. Silinmemiş kayıtlar arasında (ilaç, gün, saat) tekil.
  TextColumn get scheduledTime => text().nullable()();
  TextColumn get scheduledDay => text().nullable()();
}

/// Atlandığı açıkça işaretlenen rutin dozlar. Alım kaydı DEĞİLDİR: alım kaydı
/// okuyan hiçbir yer bu tabloyu görmez, atlanan doz yanlışlıkla "alındı"
/// sayılmaz. Silinmemiş kayıtlar arasında (ilaç, gün, saat) tekil. Doz sonradan
/// alınırsa bu kayıt silinmiş işareti alır.
class DoseSkips extends Table with BaseColumns {
  TextColumn get medicationId => text().references(Medications, #id)();

  /// Atlanan dozun yerel günü 'YYYY-MM-DD' ve doz saati 'HH:mm'.
  TextColumn get scheduledDay => text()();
  TextColumn get scheduledTime => text()();

  /// "Atladım" denilen an (UTC) ve o andaki cihaz UTC farkı (dakika).
  DateTimeColumn get skippedAt => dateTime()();
  IntColumn get utcOffsetMinutes => integer()();
}

// -------------------------------------------------------- günlük / ölçüm

/// Günlük kayıt: bugünkü dört alan (uyku, su, ruh hali, enerji). Altın verinin
/// eşdeğerliği bunlara bağlı olduğu için ayrı sütunlar olarak kalır.
class DailyLogs extends Table with BaseColumns {
  /// Yerel takvim günü, 'YYYY-MM-DD'. Silinmemiş kayıtlar arasında tekil.
  TextColumn get logDate => text()();
  RealColumn get sleepHours => real()();
  RealColumn get waterIntake => real()();
  IntColumn get mood => integer()();
  IntColumn get energyLevel => integer()();
  TextColumn get notes => text().nullable()();
}

/// Genel ölçüm tablosu: yeni günlük tetikleyiciler (stres, kafein...) ve vücut
/// ölçüleri (kilo, boy). Yeni takip alanı şema değişikliği gerektirmez.
class Measurements extends Table with BaseColumns {
  /// Bkz. [MeasurementTypes].
  TextColumn get type => text()();
  RealColumn get value => real()();
  TextColumn get unit => text().withDefault(const Constant(''))();

  /// Ölçümün ait olduğu yerel gün, 'YYYY-MM-DD'.
  TextColumn get logDate => text()();
  DateTimeColumn get measuredAt => dateTime()();
  IntColumn get utcOffsetMinutes => integer()();
  TextColumn get notes => text().nullable()();
}

// -------------------------------------------------------------- etiket

class Tags extends Table with BaseColumns {
  TextColumn get name => text().withLength(min: 1, max: 100)();

  /// Ör. 'trigger' (tetikleyici), 'environment' (çevre).
  TextColumn get kind => text().withDefault(const Constant('trigger'))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

class TagEntries extends Table with BaseColumns {
  TextColumn get tagId => text().references(Tags, #id)();
  DateTimeColumn get occurredAt => dateTime()();
  IntColumn get utcOffsetMinutes => integer()();
  TextColumn get notes => text().nullable()();
}

// --------------------------------------------------------------- döngü

class CyclePeriods extends Table with BaseColumns {
  /// 'YYYY-MM-DD'
  TextColumn get startDate => text()();

  /// Devam ediyorsa boş.
  TextColumn get endDate => text().nullable()();
  TextColumn get notes => text().nullable()();
}

class CycleFlows extends Table with BaseColumns {
  /// 'YYYY-MM-DD'. Silinmemiş kayıtlar arasında tekil.
  TextColumn get flowDate => text()();
  TextColumn get intensity => textEnum<FlowIntensity>()();
  TextColumn get periodId =>
      text().nullable().references(CyclePeriods, #id)();
}

@DataClassName('CycleStatusRecord') // Drift tekil adı "CycleStatuse" üretirdi.
class CycleStatuses extends Table with BaseColumns {
  TextColumn get kind => textEnum<CycleStatusKind>()();
  TextColumn get startDate => text()();
  TextColumn get endDate => text().nullable()();
}
