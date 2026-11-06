import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('tr')];

  /// Uygulama adı; başlıklarda ve görev listesinde görünür.
  ///
  /// In tr, this message translates to:
  /// **'Vitapuls'**
  String get appTitle;

  /// Ana ekranın üst çubuk başlığı.
  ///
  /// In tr, this message translates to:
  /// **'Vitapuls'**
  String get homeTitle;

  /// Ana ekranın üstündeki yönlendirme cümlesi.
  ///
  /// In tr, this message translates to:
  /// **'Bugün ne kaydetmek istersiniz?'**
  String get homeSubtitle;

  /// No description provided for @homeDailyLog.
  ///
  /// In tr, this message translates to:
  /// **'Günlük kayıt'**
  String get homeDailyLog;

  /// No description provided for @homeDailyLogHint.
  ///
  /// In tr, this message translates to:
  /// **'Uyku, su, ruh hali ve enerji'**
  String get homeDailyLogHint;

  /// No description provided for @homeSymptoms.
  ///
  /// In tr, this message translates to:
  /// **'Semptom girişi'**
  String get homeSymptoms;

  /// No description provided for @homeSymptomsHint.
  ///
  /// In tr, this message translates to:
  /// **'Bir şikâyet ekleyin ya da devam eden döneme not düşün'**
  String get homeSymptomsHint;

  /// Şikâyet dönemlerinin listesi (eski adıyla atak). Kullanıcıya 'dönem' denir.
  ///
  /// In tr, this message translates to:
  /// **'Dönemler'**
  String get homeEpisodes;

  /// No description provided for @homeEpisodesHint.
  ///
  /// In tr, this message translates to:
  /// **'Devam eden ve biten dönemler'**
  String get homeEpisodesHint;

  /// No description provided for @homeMedication.
  ///
  /// In tr, this message translates to:
  /// **'İlaç / takviye'**
  String get homeMedication;

  /// No description provided for @homeMedicationHint.
  ///
  /// In tr, this message translates to:
  /// **'Aldığınız ilacı ya da takviyeyi kaydedin'**
  String get homeMedicationHint;

  /// No description provided for @medLogTitle.
  ///
  /// In tr, this message translates to:
  /// **'İlaç / Takviye Al'**
  String get medLogTitle;

  /// No description provided for @medLogPick.
  ///
  /// In tr, this message translates to:
  /// **'İlaç seç'**
  String get medLogPick;

  /// No description provided for @medLogAddNew.
  ///
  /// In tr, this message translates to:
  /// **'Yeni ilaç ekle'**
  String get medLogAddNew;

  /// No description provided for @medLogPickHint.
  ///
  /// In tr, this message translates to:
  /// **'İlaç seçin...'**
  String get medLogPickHint;

  /// No description provided for @medLogDoseLabel.
  ///
  /// In tr, this message translates to:
  /// **'Doz miktarı (isteğe bağlı)'**
  String get medLogDoseLabel;

  /// No description provided for @medLogNoteLabel.
  ///
  /// In tr, this message translates to:
  /// **'Not (isteğe bağlı)'**
  String get medLogNoteLabel;

  /// No description provided for @medLogSave.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get medLogSave;

  /// No description provided for @medLogSaved.
  ///
  /// In tr, this message translates to:
  /// **'İlaç kaydedildi.'**
  String get medLogSaved;

  /// No description provided for @medLogPickRequired.
  ///
  /// In tr, this message translates to:
  /// **'Lütfen bir ilaç seçin.'**
  String get medLogPickRequired;

  /// No description provided for @medLogLoadError.
  ///
  /// In tr, this message translates to:
  /// **'İlaç listesi okunamadı. Ekranı kapatıp yeniden açmayı deneyin.'**
  String get medLogLoadError;

  /// No description provided for @medLogSaveError.
  ///
  /// In tr, this message translates to:
  /// **'İlaç kaydedilemedi. Tekrar deneyin; yazdıklarınız korunur.'**
  String get medLogSaveError;

  /// No description provided for @medLogAddError.
  ///
  /// In tr, this message translates to:
  /// **'İlaç eklenemedi. Tekrar deneyin.'**
  String get medLogAddError;

  /// No description provided for @medLogNewTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yeni İlaç Ekle'**
  String get medLogNewTitle;

  /// No description provided for @medLogNewName.
  ///
  /// In tr, this message translates to:
  /// **'İlaç adı'**
  String get medLogNewName;

  /// No description provided for @medLogCategoryLabel.
  ///
  /// In tr, this message translates to:
  /// **'Kategori (isteğe bağlı)'**
  String get medLogCategoryLabel;

  /// No description provided for @medLogNoCategory.
  ///
  /// In tr, this message translates to:
  /// **'Kategorisiz'**
  String get medLogNoCategory;

  /// No description provided for @medLogNewCategory.
  ///
  /// In tr, this message translates to:
  /// **'Yeni kategori oluştur…'**
  String get medLogNewCategory;

  /// No description provided for @medLogNewCategoryName.
  ///
  /// In tr, this message translates to:
  /// **'Yeni kategori adı'**
  String get medLogNewCategoryName;

  /// No description provided for @medLogManageCategories.
  ///
  /// In tr, this message translates to:
  /// **'Kategoriler'**
  String get medLogManageCategories;

  /// No description provided for @medLogCategoryChanged.
  ///
  /// In tr, this message translates to:
  /// **'Kategori güncellendi.'**
  String get medLogCategoryChanged;

  /// No description provided for @medLogCategoryError.
  ///
  /// In tr, this message translates to:
  /// **'Kategori kaydedilemedi. Tekrar deneyin.'**
  String get medLogCategoryError;

  /// No description provided for @medCatTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kategoriler'**
  String get medCatTitle;

  /// No description provided for @medCatEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz kategori yok. Aşağıdan ekleyebilirsiniz.'**
  String get medCatEmpty;

  /// No description provided for @medCatNameLabel.
  ///
  /// In tr, this message translates to:
  /// **'Kategori adı'**
  String get medCatNameLabel;

  /// No description provided for @medCatAdd.
  ///
  /// In tr, this message translates to:
  /// **'Ekle'**
  String get medCatAdd;

  /// No description provided for @medCatRename.
  ///
  /// In tr, this message translates to:
  /// **'Adı değiştir'**
  String get medCatRename;

  /// No description provided for @medCatRenameTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kategori adı'**
  String get medCatRenameTitle;

  /// No description provided for @medCatSave.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get medCatSave;

  /// No description provided for @medCatDelete.
  ///
  /// In tr, this message translates to:
  /// **'Sil'**
  String get medCatDelete;

  /// No description provided for @medCatClose.
  ///
  /// In tr, this message translates to:
  /// **'Kapat'**
  String get medCatClose;

  /// No description provided for @medCatDeleteTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kategori silinsin mi?'**
  String get medCatDeleteTitle;

  /// No description provided for @medCatDeleteBody.
  ///
  /// In tr, this message translates to:
  /// **'\"{name}\" silinir; bu kategorideki ilaçlar silinmez, kategorisiz kalır.'**
  String medCatDeleteBody(String name);

  /// No description provided for @medCatErrorEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Kategori adı boş olamaz.'**
  String get medCatErrorEmpty;

  /// No description provided for @medCatErrorTooLong.
  ///
  /// In tr, this message translates to:
  /// **'Kategori adı en çok 100 karakter olabilir.'**
  String get medCatErrorTooLong;

  /// No description provided for @medCatErrorExists.
  ///
  /// In tr, this message translates to:
  /// **'Bu adla bir kategori zaten var.'**
  String get medCatErrorExists;

  /// No description provided for @medCatErrorGeneric.
  ///
  /// In tr, this message translates to:
  /// **'İşlem yapılamadı. Tekrar deneyin.'**
  String get medCatErrorGeneric;

  /// No description provided for @medCatLoadError.
  ///
  /// In tr, this message translates to:
  /// **'Kategoriler okunamadı.'**
  String get medCatLoadError;

  /// No description provided for @medLogCancel.
  ///
  /// In tr, this message translates to:
  /// **'İptal'**
  String get medLogCancel;

  /// No description provided for @medLogAdd.
  ///
  /// In tr, this message translates to:
  /// **'Ekle'**
  String get medLogAdd;

  /// No description provided for @medLogAdded.
  ///
  /// In tr, this message translates to:
  /// **'{name} eklendi.'**
  String medLogAdded(String name);

  /// Aynı adlı ilaç (büyük/küçük harf ve fazla boşluk önemsiz) varsa yeni satır açılmaz, mevcut olan seçilir.
  ///
  /// In tr, this message translates to:
  /// **'{name} zaten var, seçildi.'**
  String medLogExistsSelected(String name);

  /// Günlük kayıt ekranı bugünün kaydını veritabanından okuyamazsa gösterilir; bu durumda kaydet düğmesi pasiftir.
  ///
  /// In tr, this message translates to:
  /// **'Bugünün kaydı okunamadı. Mevcut değerleriniz silinmedi; ekranı kapatıp yeniden açmayı deneyin.'**
  String get dailyLogLoadError;

  /// Günlük kayıtta uyku alanı boş, sayı değil ya da 0-24 saat dışındaysa gösterilir. Alan zorunludur.
  ///
  /// In tr, this message translates to:
  /// **'Uyku süresini 0 ile 24 saat arasında bir sayı olarak girin.'**
  String get dailyLogSleepInvalid;

  /// Günlük kayıtta su alanı boş, sayı değil ya da 0-10 litre dışındaysa gösterilir. Alan zorunludur.
  ///
  /// In tr, this message translates to:
  /// **'Su tüketimini 0 ile 10 litre arasında bir sayı olarak girin.'**
  String get dailyLogWaterInvalid;

  /// No description provided for @dailyLogSaved.
  ///
  /// In tr, this message translates to:
  /// **'Günlük kayıt kaydedildi'**
  String get dailyLogSaved;

  /// No description provided for @dailyLogUpdated.
  ///
  /// In tr, this message translates to:
  /// **'Günlük kayıt güncellendi'**
  String get dailyLogUpdated;

  /// Günlük kayıt veritabanına yazılamazsa gösterilir; form değerleri korunur.
  ///
  /// In tr, this message translates to:
  /// **'Kayıt kaydedilemedi. Girdiğiniz değerler ekranda duruyor; yeniden deneyin.'**
  String get dailyLogSaveError;

  /// Semptom girişi ekranı semptom listesini veritabanından okuyamazsa gösterilir; bu durumda kaydet düğmesi pasiftir.
  ///
  /// In tr, this message translates to:
  /// **'Semptom listesi okunamadı. Kayıtlarınız silinmedi; ekranı kapatıp yeniden açmayı deneyin.'**
  String get symptomsLoadError;

  /// No description provided for @symptomSelectRequired.
  ///
  /// In tr, this message translates to:
  /// **'Lütfen bir semptom seçin'**
  String get symptomSelectRequired;

  /// No description provided for @symptomSaved.
  ///
  /// In tr, this message translates to:
  /// **'Semptom kaydedildi'**
  String get symptomSaved;

  /// Semptom girişi veritabanına yazılamazsa gösterilir; form değerleri korunur.
  ///
  /// In tr, this message translates to:
  /// **'Semptom kaydedilemedi. Girdiğiniz değerler ekranda duruyor; yeniden deneyin.'**
  String get symptomSaveError;

  /// No description provided for @symptomAdded.
  ///
  /// In tr, this message translates to:
  /// **'Semptom eklendi'**
  String get symptomAdded;

  /// Kullanıcı listede zaten bulunan bir adı (büyük/küçük harf ve fazla boşluk önemsiz) yeni semptom olarak eklemeye çalışırsa gösterilir; yeni kayıt açılmaz, mevcut olan seçilir.
  ///
  /// In tr, this message translates to:
  /// **'Bu semptom listede zaten var, onu seçtim.'**
  String get symptomExistsSelected;

  /// No description provided for @symptomAddError.
  ///
  /// In tr, this message translates to:
  /// **'Semptom eklenemedi. Yeniden deneyin.'**
  String get symptomAddError;

  /// Devam eden dönemi olmayan bir semptom kaydedilince çıkan sorunun başlığı. Dönem = başlangıcı ve sonu olan şikâyet dönemi; kullanıcıya 'atak' denmez.
  ///
  /// In tr, this message translates to:
  /// **'Dönem takibi'**
  String get symptomEpisodeTrackTitle;

  /// No description provided for @symptomEpisodeTrackQuestion.
  ///
  /// In tr, this message translates to:
  /// **'Bu şikâyeti bir dönem olarak takip etmek ister misiniz?'**
  String get symptomEpisodeTrackQuestion;

  /// No description provided for @symptomEpisodeTrackNo.
  ///
  /// In tr, this message translates to:
  /// **'Hayır, sadece kaydet'**
  String get symptomEpisodeTrackNo;

  /// No description provided for @symptomEpisodeTrackYes.
  ///
  /// In tr, this message translates to:
  /// **'Evet, dönem başlat'**
  String get symptomEpisodeTrackYes;

  /// No description provided for @symptomSavedEpisodeStarted.
  ///
  /// In tr, this message translates to:
  /// **'Semptom kaydedildi ve dönem başlatıldı'**
  String get symptomSavedEpisodeStarted;

  /// Aynı semptom için devam eden bir dönem varken yeni giriş kaydedilince çıkan sorunun başlığı.
  ///
  /// In tr, this message translates to:
  /// **'Devam eden {symptom} döneminiz var'**
  String symptomEpisodeOngoingTitle(String symptom);

  /// No description provided for @symptomEpisodeOngoingQuestion.
  ///
  /// In tr, this message translates to:
  /// **'Bu kayıt nasıl eklensin?'**
  String get symptomEpisodeOngoingQuestion;

  /// No description provided for @symptomEpisodeIndependent.
  ///
  /// In tr, this message translates to:
  /// **'Bağımsız kayıt'**
  String get symptomEpisodeIndependent;

  /// No description provided for @symptomEpisodeAdd.
  ///
  /// In tr, this message translates to:
  /// **'Döneme ekle'**
  String get symptomEpisodeAdd;

  /// Yalnızca girişte konum yazılmışsa gösterilir; konum dönemin konumlarına eklenir.
  ///
  /// In tr, this message translates to:
  /// **'Yeni konumla ekle'**
  String get symptomEpisodeNewLocation;

  /// No description provided for @symptomAddedToEpisode.
  ///
  /// In tr, this message translates to:
  /// **'Semptom kaydedildi ve döneme eklendi'**
  String get symptomAddedToEpisode;

  /// No description provided for @symptomAddedToEpisodeNewLocation.
  ///
  /// In tr, this message translates to:
  /// **'Semptom kaydedildi, yeni konumla döneme eklendi'**
  String get symptomAddedToEpisodeNewLocation;

  /// Dönem işlemi (başlatma ya da ekleme) başarısız olursa gösterilir; giriş zaten kayıtlıdır.
  ///
  /// In tr, this message translates to:
  /// **'Semptom kaydedildi ama dönem işlemi yapılamadı.'**
  String get symptomEpisodeError;

  /// Dönem listesi ekranının başlığı. Dönem = başlangıcı ve sonu olan şikâyet dönemi (eski adıyla atak); kullanıcıya 'atak' denmez.
  ///
  /// In tr, this message translates to:
  /// **'Dönemler'**
  String get episodesTitle;

  /// No description provided for @episodesTabActive.
  ///
  /// In tr, this message translates to:
  /// **'Aktif'**
  String get episodesTabActive;

  /// No description provided for @episodesTabHistory.
  ///
  /// In tr, this message translates to:
  /// **'Geçmiş'**
  String get episodesTabHistory;

  /// No description provided for @episodesEmptyActive.
  ///
  /// In tr, this message translates to:
  /// **'Devam eden dönem yok'**
  String get episodesEmptyActive;

  /// No description provided for @episodesEmptyHistory.
  ///
  /// In tr, this message translates to:
  /// **'Geçmiş dönem yok'**
  String get episodesEmptyHistory;

  /// Dönem listesi veritabanından okunamazsa gösterilir.
  ///
  /// In tr, this message translates to:
  /// **'Dönemler okunamadı. Kayıtlarınız silinmedi; yenilemeyi deneyin.'**
  String get episodesLoadError;

  /// No description provided for @episodesRefresh.
  ///
  /// In tr, this message translates to:
  /// **'Yenile'**
  String get episodesRefresh;

  /// Devam eden dönem kartında son girişin şiddeti; giriş yoksa '-'.
  ///
  /// In tr, this message translates to:
  /// **'Şiddet: {value}/10'**
  String episodeSeverity(String value);

  /// Biten dönem kartında girişlerin en yüksek şiddeti; giriş yoksa '-'.
  ///
  /// In tr, this message translates to:
  /// **'Maks. şiddet: {value}/10'**
  String episodeMaxSeverity(String value);

  /// Devam eden dönem kartında başlangıç zamanı (bugünse saat, başka güne aitse tarihli).
  ///
  /// In tr, this message translates to:
  /// **'Başlangıç: {time}'**
  String episodeStart(String time);

  /// No description provided for @episodeLocation.
  ///
  /// In tr, this message translates to:
  /// **'Lokasyon: {locations}'**
  String episodeLocation(String locations);

  /// No description provided for @episodeNoLocation.
  ///
  /// In tr, this message translates to:
  /// **'Lokasyon belirtilmemiş'**
  String get episodeNoLocation;

  /// Biten dönem kartında başlangıç → bitiş ve süre.
  ///
  /// In tr, this message translates to:
  /// **'{start} → {end} · {duration}'**
  String episodeRange(String start, String end, String duration);

  /// No description provided for @episodeDurationHoursMinutes.
  ///
  /// In tr, this message translates to:
  /// **'{hours} saat {minutes} dakika'**
  String episodeDurationHoursMinutes(int hours, int minutes);

  /// No description provided for @episodeDurationMinutes.
  ///
  /// In tr, this message translates to:
  /// **'{minutes} dakika'**
  String episodeDurationMinutes(int minutes);

  /// No description provided for @episodeAddMedication.
  ///
  /// In tr, this message translates to:
  /// **'İlaç Ekle'**
  String get episodeAddMedication;

  /// No description provided for @episodeClose.
  ///
  /// In tr, this message translates to:
  /// **'Dönemi Kapat'**
  String get episodeClose;

  /// Dönem kartında döneme bağlı ilaç alımı; dose örn. '1,5 damla', time saat ya da tarihli saat.
  ///
  /// In tr, this message translates to:
  /// **'İlaç: {name} ({dose}) · {time}'**
  String episodeIntakeWithDose(String name, String dose, String time);

  /// Dönem kartında doz yazılmamış ilaç alımı.
  ///
  /// In tr, this message translates to:
  /// **'İlaç: {name} · {time}'**
  String episodeIntakeNoDose(String name, String time);

  /// No description provided for @episodeMedicationTitle.
  ///
  /// In tr, this message translates to:
  /// **'Döneme İlaç Ekle'**
  String get episodeMedicationTitle;

  /// No description provided for @episodeMedicationHint.
  ///
  /// In tr, this message translates to:
  /// **'İlaç seçin...'**
  String get episodeMedicationHint;

  /// No description provided for @episodeMedicationNone.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlı ilaç yok.'**
  String get episodeMedicationNone;

  /// No description provided for @episodeMedicationLoadError.
  ///
  /// In tr, this message translates to:
  /// **'İlaç listesi okunamadı.'**
  String get episodeMedicationLoadError;

  /// No description provided for @episodeMedicationPick.
  ///
  /// In tr, this message translates to:
  /// **'Lütfen bir ilaç seçin'**
  String get episodeMedicationPick;

  /// No description provided for @episodeDoseLabel.
  ///
  /// In tr, this message translates to:
  /// **'Doz miktarı'**
  String get episodeDoseLabel;

  /// No description provided for @episodeDoseInvalid.
  ///
  /// In tr, this message translates to:
  /// **'Doz sıfırdan büyük bir sayı olmalı'**
  String get episodeDoseInvalid;

  /// No description provided for @episodeMedicationSave.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get episodeMedicationSave;

  /// No description provided for @episodeMedicationSaved.
  ///
  /// In tr, this message translates to:
  /// **'İlaç döneme eklendi.'**
  String get episodeMedicationSaved;

  /// No description provided for @episodeMedicationSaveFailed.
  ///
  /// In tr, this message translates to:
  /// **'İlaç kaydedilemedi. Tekrar deneyin.'**
  String get episodeMedicationSaveFailed;

  /// No description provided for @doseUnitTablet.
  ///
  /// In tr, this message translates to:
  /// **'tablet'**
  String get doseUnitTablet;

  /// No description provided for @doseUnitMg.
  ///
  /// In tr, this message translates to:
  /// **'mg'**
  String get doseUnitMg;

  /// No description provided for @doseUnitMl.
  ///
  /// In tr, this message translates to:
  /// **'ml'**
  String get doseUnitMl;

  /// No description provided for @doseUnitDrop.
  ///
  /// In tr, this message translates to:
  /// **'damla'**
  String get doseUnitDrop;

  /// No description provided for @doseUnitCapsule.
  ///
  /// In tr, this message translates to:
  /// **'kapsül'**
  String get doseUnitCapsule;

  /// No description provided for @episodeClosed.
  ///
  /// In tr, this message translates to:
  /// **'Dönem kapatıldı.'**
  String get episodeClosed;

  /// No description provided for @episodeCloseNotesLabel.
  ///
  /// In tr, this message translates to:
  /// **'Nasıl geçti? (isteğe bağlı)'**
  String get episodeCloseNotesLabel;

  /// No description provided for @episodeCloseNotesHint.
  ///
  /// In tr, this message translates to:
  /// **'Örn: Uyuyarak geçirdim, ilaç aldım...'**
  String get episodeCloseNotesHint;

  /// Kapatılmış bir dönem tekrar kapatılmaya çalışılırsa (iş kuralı episode_already_closed).
  ///
  /// In tr, this message translates to:
  /// **'Bu dönem zaten kapatılmış. Listeyi yenileyin.'**
  String get episodeCloseAlreadyClosed;

  /// Şimdiki zaman dönemin başlangıcından önce ya da eşitse (iş kuralı episode_end_before_start); genelde cihaz saati geri alınmıştır.
  ///
  /// In tr, this message translates to:
  /// **'Bitiş zamanı başlangıçtan önce olamaz. Cihazın saatini kontrol edin.'**
  String get episodeCloseEndBeforeStart;

  /// No description provided for @episodeCloseFailed.
  ///
  /// In tr, this message translates to:
  /// **'Dönem kapatılamadı. Tekrar deneyin; yazdığınız not korunur.'**
  String get episodeCloseFailed;

  /// No description provided for @dbOpenErrorTitle.
  ///
  /// In tr, this message translates to:
  /// **'Veritabanı açılamadı'**
  String get dbOpenErrorTitle;

  /// Açılışta veritabanı anahtarla açılamazsa gösterilen hata metni.
  ///
  /// In tr, this message translates to:
  /// **'Şifreli veritabanı açılamadı. Uygulamayı tamamen kapatıp yeniden açmayı deneyin.'**
  String get dbOpenErrorBody;

  /// No description provided for @commonContinue.
  ///
  /// In tr, this message translates to:
  /// **'Devam'**
  String get commonContinue;

  /// No description provided for @commonCancel.
  ///
  /// In tr, this message translates to:
  /// **'Vazgeç'**
  String get commonCancel;

  /// No description provided for @commonBack.
  ///
  /// In tr, this message translates to:
  /// **'Geri'**
  String get commonBack;

  /// Kalan bekleme süresi, bir dakikadan kısa.
  ///
  /// In tr, this message translates to:
  /// **'{n} sn'**
  String waitSeconds(int n);

  /// Kalan bekleme süresi, dakika ve saniye (s iki haneli, ör. 05).
  ///
  /// In tr, this message translates to:
  /// **'{m} dk {s} sn'**
  String waitMinutes(int m, String s);

  /// No description provided for @lockTitle.
  ///
  /// In tr, this message translates to:
  /// **'Vitapuls kilitli'**
  String get lockTitle;

  /// No description provided for @lockEnterPin.
  ///
  /// In tr, this message translates to:
  /// **'PIN\'inizi girin'**
  String get lockEnterPin;

  /// No description provided for @lockWrongPin.
  ///
  /// In tr, this message translates to:
  /// **'Yanlış PIN'**
  String get lockWrongPin;

  /// Yanlış denemeler yüzünden giriş kapalıyken gösterilir.
  ///
  /// In tr, this message translates to:
  /// **'Çok fazla yanlış deneme. {wait} sonra tekrar deneyin.'**
  String lockBlocked(String wait);

  /// No description provided for @lockBackspace.
  ///
  /// In tr, this message translates to:
  /// **'Sil'**
  String get lockBackspace;

  /// No description provided for @lockBiometricReason.
  ///
  /// In tr, this message translates to:
  /// **'Vitapuls\'ın kilidini açmak için doğrulayın'**
  String get lockBiometricReason;

  /// No description provided for @lockBiometricButton.
  ///
  /// In tr, this message translates to:
  /// **'Parmak iziyle aç'**
  String get lockBiometricButton;

  /// No description provided for @lockForgotPin.
  ///
  /// In tr, this message translates to:
  /// **'PIN\'imi unuttum'**
  String get lockForgotPin;

  /// No description provided for @lockSetupTitle.
  ///
  /// In tr, this message translates to:
  /// **'PIN belirleyin'**
  String get lockSetupTitle;

  /// No description provided for @lockSetupEnter.
  ///
  /// In tr, this message translates to:
  /// **'Yeni PIN belirleyin (4-8 rakam)'**
  String get lockSetupEnter;

  /// No description provided for @lockSetupConfirm.
  ///
  /// In tr, this message translates to:
  /// **'PIN\'i tekrar girin'**
  String get lockSetupConfirm;

  /// No description provided for @lockSetupMismatch.
  ///
  /// In tr, this message translates to:
  /// **'PIN\'ler uyuşmadı, baştan başlayın'**
  String get lockSetupMismatch;

  /// No description provided for @lockConfirmCurrent.
  ///
  /// In tr, this message translates to:
  /// **'Mevcut PIN\'inizi girin'**
  String get lockConfirmCurrent;

  /// No description provided for @recoveryCodeTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kurtarma kodunuz'**
  String get recoveryCodeTitle;

  /// No description provided for @recoveryCodeBody.
  ///
  /// In tr, this message translates to:
  /// **'PIN\'inizi unutursanız verilerinize bu kodla dönebilirsiniz. Kodu bir kâğıda yazıp güvenli bir yerde saklayın. Bir daha gösterilmeyecek. PIN\'i ve kodu birlikte kaybederseniz verileriniz kurtarılamaz.'**
  String get recoveryCodeBody;

  /// No description provided for @recoveryCodeConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Kodu yazdım ve sakladım'**
  String get recoveryCodeConfirm;

  /// No description provided for @recoveryCodeDone.
  ///
  /// In tr, this message translates to:
  /// **'Bitti'**
  String get recoveryCodeDone;

  /// No description provided for @recoveryTitle.
  ///
  /// In tr, this message translates to:
  /// **'PIN\'imi unuttum'**
  String get recoveryTitle;

  /// No description provided for @recoveryEnterCode.
  ///
  /// In tr, this message translates to:
  /// **'12 karakterlik kurtarma kodunuzu girin'**
  String get recoveryEnterCode;

  /// No description provided for @recoveryCodeField.
  ///
  /// In tr, this message translates to:
  /// **'Kurtarma kodu'**
  String get recoveryCodeField;

  /// No description provided for @recoveryCodeInvalid.
  ///
  /// In tr, this message translates to:
  /// **'Kod 12 karakter olmalı (harf ve rakam)'**
  String get recoveryCodeInvalid;

  /// No description provided for @recoveryWrongCode.
  ///
  /// In tr, this message translates to:
  /// **'Kod yanlış'**
  String get recoveryWrongCode;

  /// Kurtarma kodu girişi kapalıyken gösterilir.
  ///
  /// In tr, this message translates to:
  /// **'Çok fazla yanlış deneme. {wait} sonra tekrar deneyin.'**
  String recoveryBlocked(String wait);

  /// No description provided for @recoveryLostBoth.
  ///
  /// In tr, this message translates to:
  /// **'Kodu da kaybettim'**
  String get recoveryLostBoth;

  /// No description provided for @wipeTitle.
  ///
  /// In tr, this message translates to:
  /// **'Tüm veriler silinsin mi?'**
  String get wipeTitle;

  /// No description provided for @wipeBody.
  ///
  /// In tr, this message translates to:
  /// **'Bu işlem tüm kayıtlarınızı kalıcı olarak siler ve geri alınamaz. Uygulama boş başlar.'**
  String get wipeBody;

  /// No description provided for @wipeConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Tümünü sil'**
  String get wipeConfirm;

  /// No description provided for @wipeFailed.
  ///
  /// In tr, this message translates to:
  /// **'Silinemedi, tekrar deneyin'**
  String get wipeFailed;

  /// GEÇİCİ ana ekran satırı; ayarlar ekranı gelince oraya taşınır.
  ///
  /// In tr, this message translates to:
  /// **'Uygulama kilidi'**
  String get lockSettingsTitle;

  /// No description provided for @lockSettingsOffHint.
  ///
  /// In tr, this message translates to:
  /// **'Kapalı. Açılışta PIN ya da parmak izi istenmez.'**
  String get lockSettingsOffHint;

  /// No description provided for @lockSettingsOnHint.
  ///
  /// In tr, this message translates to:
  /// **'Açık. Açılışta PIN ya da parmak izi istenir.'**
  String get lockSettingsOnHint;

  /// No description provided for @lockSettingsBiometric.
  ///
  /// In tr, this message translates to:
  /// **'Parmak iziyle aç'**
  String get lockSettingsBiometric;

  /// No description provided for @lockSettingsTimeout.
  ///
  /// In tr, this message translates to:
  /// **'Arka plandan dönünce kilitle'**
  String get lockSettingsTimeout;

  /// No description provided for @lockTimeoutNow.
  ///
  /// In tr, this message translates to:
  /// **'Hemen'**
  String get lockTimeoutNow;

  /// No description provided for @lockTimeoutSeconds.
  ///
  /// In tr, this message translates to:
  /// **'{n} sn sonra'**
  String lockTimeoutSeconds(int n);

  /// No description provided for @lockTimeoutMinutes.
  ///
  /// In tr, this message translates to:
  /// **'{n} dk sonra'**
  String lockTimeoutMinutes(int n);

  /// No description provided for @lockSettingsLockNow.
  ///
  /// In tr, this message translates to:
  /// **'Şimdi kilitle'**
  String get lockSettingsLockNow;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
