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

  /// No description provided for @homeConditions.
  ///
  /// In tr, this message translates to:
  /// **'Kronik hastalıklar'**
  String get homeConditions;

  /// No description provided for @homeConditionsHint.
  ///
  /// In tr, this message translates to:
  /// **'Hastalıklarınızı ve kullandığınız ilaçları yönetin'**
  String get homeConditionsHint;

  /// No description provided for @homeRoutines.
  ///
  /// In tr, this message translates to:
  /// **'Rutin ilaçlar'**
  String get homeRoutines;

  /// No description provided for @homeRoutinesHint.
  ///
  /// In tr, this message translates to:
  /// **'Her gün ya da belirli günlerde alacağınız ilaçlar'**
  String get homeRoutinesHint;

  /// No description provided for @routineTitle.
  ///
  /// In tr, this message translates to:
  /// **'Rutinlerim'**
  String get routineTitle;

  /// No description provided for @routineAddTooltip.
  ///
  /// In tr, this message translates to:
  /// **'Rutin ekle'**
  String get routineAddTooltip;

  /// No description provided for @routineTodayTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bugünün rutinleri'**
  String get routineTodayTitle;

  /// No description provided for @routineTodayEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Bugün için rutin yok.'**
  String get routineTodayEmpty;

  /// No description provided for @routineAllTitle.
  ///
  /// In tr, this message translates to:
  /// **'Tüm rutinler'**
  String get routineAllTitle;

  /// No description provided for @routineAllEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz rutin tanımlanmamış.'**
  String get routineAllEmpty;

  /// No description provided for @routineOtherGroup.
  ///
  /// In tr, this message translates to:
  /// **'Diğer'**
  String get routineOtherGroup;

  /// No description provided for @routineEveryDay.
  ///
  /// In tr, this message translates to:
  /// **'Her gün'**
  String get routineEveryDay;

  /// No description provided for @routineTaken.
  ///
  /// In tr, this message translates to:
  /// **'Aldım'**
  String get routineTaken;

  /// No description provided for @routineTakenSaved.
  ///
  /// In tr, this message translates to:
  /// **'{name} alındı olarak kaydedildi.'**
  String routineTakenSaved(String name);

  /// No description provided for @routineNewTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yeni rutin'**
  String get routineNewTitle;

  /// No description provided for @routineMedLabel.
  ///
  /// In tr, this message translates to:
  /// **'İlaç'**
  String get routineMedLabel;

  /// No description provided for @routineMedHint.
  ///
  /// In tr, this message translates to:
  /// **'İlaç seçin'**
  String get routineMedHint;

  /// No description provided for @routineNoMedsAvailable.
  ///
  /// In tr, this message translates to:
  /// **'Rutin kurulacak ilaç yok. Önce İlaç / takviye ekranından ilaç ekleyin ya da var olan rutinlerden birini kapatın.'**
  String get routineNoMedsAvailable;

  /// No description provided for @routineTimesLabel.
  ///
  /// In tr, this message translates to:
  /// **'Doz saatleri'**
  String get routineTimesLabel;

  /// No description provided for @routineAddTime.
  ///
  /// In tr, this message translates to:
  /// **'Saat ekle'**
  String get routineAddTime;

  /// No description provided for @routineRemoveTime.
  ///
  /// In tr, this message translates to:
  /// **'Saati sil'**
  String get routineRemoveTime;

  /// No description provided for @routineSkip.
  ///
  /// In tr, this message translates to:
  /// **'Atladım'**
  String get routineSkip;

  /// No description provided for @routineStateTaken.
  ///
  /// In tr, this message translates to:
  /// **'Alındı'**
  String get routineStateTaken;

  /// No description provided for @routineStateSkipped.
  ///
  /// In tr, this message translates to:
  /// **'Atlandı'**
  String get routineStateSkipped;

  /// No description provided for @routineStateWaiting.
  ///
  /// In tr, this message translates to:
  /// **'Bekliyor'**
  String get routineStateWaiting;

  /// No description provided for @routineStateUnrecorded.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedilmedi'**
  String get routineStateUnrecorded;

  /// No description provided for @routineSkippedSaved.
  ///
  /// In tr, this message translates to:
  /// **'{name} atlandı olarak kaydedildi.'**
  String routineSkippedSaved(String name);

  /// No description provided for @routineAddedNoReminder.
  ///
  /// In tr, this message translates to:
  /// **'Rutin eklendi ama hatırlatma kurulamadı.'**
  String get routineAddedNoReminder;

  /// No description provided for @routineClosedNoReminder.
  ///
  /// In tr, this message translates to:
  /// **'Rutin kapatıldı ama hatırlatma iptal edilemedi.'**
  String get routineClosedNoReminder;

  /// No description provided for @reminderPermTitle.
  ///
  /// In tr, this message translates to:
  /// **'Bildirim izni'**
  String get reminderPermTitle;

  /// No description provided for @reminderPermBody.
  ///
  /// In tr, this message translates to:
  /// **'İlaç saatinde hatırlatma gelmesi için Vitapuls\'ın bildirim göstermesine izin vermeniz gerekir. Bildirimde ilaç adı yazmaz.'**
  String get reminderPermBody;

  /// No description provided for @reminderPermContinue.
  ///
  /// In tr, this message translates to:
  /// **'Devam'**
  String get reminderPermContinue;

  /// No description provided for @reminderPermLater.
  ///
  /// In tr, this message translates to:
  /// **'Şimdi değil'**
  String get reminderPermLater;

  /// No description provided for @reminderOpenSettings.
  ///
  /// In tr, this message translates to:
  /// **'Ayarları aç'**
  String get reminderOpenSettings;

  /// No description provided for @reminderOffBanner.
  ///
  /// In tr, this message translates to:
  /// **'Bildirimler kapalı: doz saatinde hatırlatma gelmez. Telefonun Ayarlar > Uygulamalar > Vitapuls > Bildirimler bölümünden açabilirsiniz.'**
  String get reminderOffBanner;

  /// No description provided for @reminderInexactBanner.
  ///
  /// In tr, this message translates to:
  /// **'Hatırlatmalar tam saatinde değil, birkaç dakika sapmayla gelebilir.'**
  String get reminderInexactBanner;

  /// No description provided for @reminderExactButton.
  ///
  /// In tr, this message translates to:
  /// **'Tam saatte gelmesi için izin ver'**
  String get reminderExactButton;

  /// No description provided for @reminderTitle.
  ///
  /// In tr, this message translates to:
  /// **'Vitapuls'**
  String get reminderTitle;

  /// No description provided for @reminderBody.
  ///
  /// In tr, this message translates to:
  /// **'İlaç saatiniz geldi'**
  String get reminderBody;

  /// No description provided for @reminderChannelName.
  ///
  /// In tr, this message translates to:
  /// **'İlaç hatırlatmaları'**
  String get reminderChannelName;

  /// No description provided for @reminderChannelDescription.
  ///
  /// In tr, this message translates to:
  /// **'Rutin ilaç dozlarının saatinde gelen hatırlatmalar'**
  String get reminderChannelDescription;

  /// No description provided for @routineErrorTimes.
  ///
  /// In tr, this message translates to:
  /// **'En az bir doz saati seçin.'**
  String get routineErrorTimes;

  /// No description provided for @routineErrorTooManyTimes.
  ///
  /// In tr, this message translates to:
  /// **'Günde en çok 10 doz saati olabilir.'**
  String get routineErrorTooManyTimes;

  /// No description provided for @routineErrorDoseTaken.
  ///
  /// In tr, this message translates to:
  /// **'Bu doz zaten alındı olarak kaydedilmiş.'**
  String get routineErrorDoseTaken;

  /// No description provided for @routineErrorDoseSkipped.
  ///
  /// In tr, this message translates to:
  /// **'Bu doz zaten atlandı olarak kaydedilmiş.'**
  String get routineErrorDoseSkipped;

  /// No description provided for @routineErrorDoseNotScheduled.
  ///
  /// In tr, this message translates to:
  /// **'Bu doz artık planlı değil. Ekranı yenileyip tekrar deneyin.'**
  String get routineErrorDoseNotScheduled;

  /// No description provided for @routineDaysLabel.
  ///
  /// In tr, this message translates to:
  /// **'Günler'**
  String get routineDaysLabel;

  /// No description provided for @routineSave.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get routineSave;

  /// No description provided for @routineCancel.
  ///
  /// In tr, this message translates to:
  /// **'İptal'**
  String get routineCancel;

  /// No description provided for @routineAdded.
  ///
  /// In tr, this message translates to:
  /// **'Rutin eklendi.'**
  String get routineAdded;

  /// No description provided for @routineCloseTooltip.
  ///
  /// In tr, this message translates to:
  /// **'Rutini kapat'**
  String get routineCloseTooltip;

  /// No description provided for @routineCloseTitle.
  ///
  /// In tr, this message translates to:
  /// **'Rutin kapatılsın mı?'**
  String get routineCloseTitle;

  /// No description provided for @routineCloseBody.
  ///
  /// In tr, this message translates to:
  /// **'\"{name}\" rutini kapatılır; ilacınız ve eski ilaç kayıtlarınız silinmez.'**
  String routineCloseBody(String name);

  /// No description provided for @routineCloseConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Kapat'**
  String get routineCloseConfirm;

  /// No description provided for @routineClosed.
  ///
  /// In tr, this message translates to:
  /// **'Rutin kapatıldı.'**
  String get routineClosed;

  /// No description provided for @routineLoadError.
  ///
  /// In tr, this message translates to:
  /// **'Rutinler okunamadı. Ekranı kapatıp yeniden açmayı deneyin.'**
  String get routineLoadError;

  /// No description provided for @routineErrorNoMed.
  ///
  /// In tr, this message translates to:
  /// **'Önce bir ilaç seçin.'**
  String get routineErrorNoMed;

  /// No description provided for @routineErrorDays.
  ///
  /// In tr, this message translates to:
  /// **'En az bir gün seçin.'**
  String get routineErrorDays;

  /// No description provided for @routineErrorTime.
  ///
  /// In tr, this message translates to:
  /// **'Saat geçerli değil.'**
  String get routineErrorTime;

  /// No description provided for @routineErrorMedication.
  ///
  /// In tr, this message translates to:
  /// **'Seçtiğiniz ilaç artık yok. Ekranı yenileyip tekrar deneyin.'**
  String get routineErrorMedication;

  /// No description provided for @routineErrorGeneric.
  ///
  /// In tr, this message translates to:
  /// **'İşlem yapılamadı. Tekrar deneyin.'**
  String get routineErrorGeneric;

  /// No description provided for @dayMonShort.
  ///
  /// In tr, this message translates to:
  /// **'Pzt'**
  String get dayMonShort;

  /// No description provided for @dayTueShort.
  ///
  /// In tr, this message translates to:
  /// **'Sal'**
  String get dayTueShort;

  /// No description provided for @dayWedShort.
  ///
  /// In tr, this message translates to:
  /// **'Çar'**
  String get dayWedShort;

  /// No description provided for @dayThuShort.
  ///
  /// In tr, this message translates to:
  /// **'Per'**
  String get dayThuShort;

  /// No description provided for @dayFriShort.
  ///
  /// In tr, this message translates to:
  /// **'Cum'**
  String get dayFriShort;

  /// No description provided for @daySatShort.
  ///
  /// In tr, this message translates to:
  /// **'Cmt'**
  String get daySatShort;

  /// No description provided for @daySunShort.
  ///
  /// In tr, this message translates to:
  /// **'Paz'**
  String get daySunShort;

  /// No description provided for @condTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kronik Hastalıklarım'**
  String get condTitle;

  /// No description provided for @condAddTooltip.
  ///
  /// In tr, this message translates to:
  /// **'Hastalık ekle'**
  String get condAddTooltip;

  /// No description provided for @condEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz kronik hastalık eklenmemiş.'**
  String get condEmpty;

  /// No description provided for @condNewTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yeni Kronik Hastalık'**
  String get condNewTitle;

  /// No description provided for @condEditTitle.
  ///
  /// In tr, this message translates to:
  /// **'Hastalığı Düzenle'**
  String get condEditTitle;

  /// No description provided for @condNameLabel.
  ///
  /// In tr, this message translates to:
  /// **'Hastalık adı'**
  String get condNameLabel;

  /// No description provided for @condMedsLabel.
  ///
  /// In tr, this message translates to:
  /// **'İlaçlar'**
  String get condMedsLabel;

  /// No description provided for @condNoMeds.
  ///
  /// In tr, this message translates to:
  /// **'İlaç eklenmemiş.'**
  String get condNoMeds;

  /// No description provided for @condNoMedsAvailable.
  ///
  /// In tr, this message translates to:
  /// **'Seçilecek ilaç yok.'**
  String get condNoMedsAvailable;

  /// No description provided for @condSave.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get condSave;

  /// No description provided for @condCancel.
  ///
  /// In tr, this message translates to:
  /// **'İptal'**
  String get condCancel;

  /// No description provided for @condEditTooltip.
  ///
  /// In tr, this message translates to:
  /// **'Düzenle'**
  String get condEditTooltip;

  /// No description provided for @condDeleteTooltip.
  ///
  /// In tr, this message translates to:
  /// **'Sil'**
  String get condDeleteTooltip;

  /// No description provided for @condDeleteTitle.
  ///
  /// In tr, this message translates to:
  /// **'Hastalık silinsin mi?'**
  String get condDeleteTitle;

  /// No description provided for @condDeleteBody.
  ///
  /// In tr, this message translates to:
  /// **'\"{name}\" silinir; ilaçlarınız ve eski ilaç kayıtlarınız silinmez.'**
  String condDeleteBody(String name);

  /// No description provided for @condDeleteConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Sil'**
  String get condDeleteConfirm;

  /// No description provided for @condAdded.
  ///
  /// In tr, this message translates to:
  /// **'Hastalık eklendi.'**
  String get condAdded;

  /// No description provided for @condUpdated.
  ///
  /// In tr, this message translates to:
  /// **'Hastalık güncellendi.'**
  String get condUpdated;

  /// No description provided for @condDeleted.
  ///
  /// In tr, this message translates to:
  /// **'Hastalık silindi.'**
  String get condDeleted;

  /// No description provided for @condLoadError.
  ///
  /// In tr, this message translates to:
  /// **'Kronik hastalıklar okunamadı. Ekranı kapatıp yeniden açmayı deneyin.'**
  String get condLoadError;

  /// No description provided for @condErrorEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Hastalık adı boş olamaz.'**
  String get condErrorEmpty;

  /// No description provided for @condErrorTooLong.
  ///
  /// In tr, this message translates to:
  /// **'Hastalık adı en çok 200 karakter olabilir.'**
  String get condErrorTooLong;

  /// No description provided for @condErrorExists.
  ///
  /// In tr, this message translates to:
  /// **'Bu adla bir kronik hastalık zaten var.'**
  String get condErrorExists;

  /// No description provided for @condErrorMedication.
  ///
  /// In tr, this message translates to:
  /// **'Seçtiğiniz ilaçlardan biri artık yok. Ekranı yenileyip tekrar deneyin.'**
  String get condErrorMedication;

  /// No description provided for @condErrorGeneric.
  ///
  /// In tr, this message translates to:
  /// **'İşlem yapılamadı. Tekrar deneyin.'**
  String get condErrorGeneric;

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

  /// No description provided for @homeTimeline.
  ///
  /// In tr, this message translates to:
  /// **'Zaman çizelgesi'**
  String get homeTimeline;

  /// No description provided for @homeTimelineHint.
  ///
  /// In tr, this message translates to:
  /// **'Günün kayıtlarını sırayla görün'**
  String get homeTimelineHint;

  /// No description provided for @timelineTitle.
  ///
  /// In tr, this message translates to:
  /// **'Zaman çizelgesi'**
  String get timelineTitle;

  /// No description provided for @timelinePrevDay.
  ///
  /// In tr, this message translates to:
  /// **'Önceki gün'**
  String get timelinePrevDay;

  /// No description provided for @timelineNextDay.
  ///
  /// In tr, this message translates to:
  /// **'Sonraki gün'**
  String get timelineNextDay;

  /// No description provided for @timelineGoToday.
  ///
  /// In tr, this message translates to:
  /// **'Bugüne dön'**
  String get timelineGoToday;

  /// No description provided for @timelineToday.
  ///
  /// In tr, this message translates to:
  /// **'Bugün'**
  String get timelineToday;

  /// No description provided for @timelineLoadError.
  ///
  /// In tr, this message translates to:
  /// **'Zaman çizelgesi okunamadı. Verileriniz silinmedi; ekranı kapatıp yeniden açmayı deneyin.'**
  String get timelineLoadError;

  /// No description provided for @timelineActiveTitle.
  ///
  /// In tr, this message translates to:
  /// **'Devam eden dönemler'**
  String get timelineActiveTitle;

  /// No description provided for @timelineDailyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Günlük kayıt'**
  String get timelineDailyTitle;

  /// No description provided for @timelineNoDailyLog.
  ///
  /// In tr, this message translates to:
  /// **'Bu gün için günlük kayıt yok.'**
  String get timelineNoDailyLog;

  /// No description provided for @timelineAddDailyLog.
  ///
  /// In tr, this message translates to:
  /// **'Günlük kayıt ekle'**
  String get timelineAddDailyLog;

  /// No description provided for @timelineSleep.
  ///
  /// In tr, this message translates to:
  /// **'Uyku: {value} saat'**
  String timelineSleep(String value);

  /// No description provided for @timelineWater.
  ///
  /// In tr, this message translates to:
  /// **'Su: {value} litre'**
  String timelineWater(String value);

  /// No description provided for @timelineMood.
  ///
  /// In tr, this message translates to:
  /// **'Ruh hali: {value}/5'**
  String timelineMood(int value);

  /// No description provided for @timelineEnergy.
  ///
  /// In tr, this message translates to:
  /// **'Enerji: {value}/5'**
  String timelineEnergy(int value);

  /// No description provided for @timelineEventsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlar'**
  String get timelineEventsTitle;

  /// No description provided for @timelineEventsEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Bu gün için semptom ya da ilaç kaydı yok.'**
  String get timelineEventsEmpty;

  /// No description provided for @timelineSymptomLine.
  ///
  /// In tr, this message translates to:
  /// **'{name} · Şiddet {severity}/10'**
  String timelineSymptomLine(String name, int severity);

  /// No description provided for @timelineIntakeLine.
  ///
  /// In tr, this message translates to:
  /// **'{name} alındı'**
  String timelineIntakeLine(String name);

  /// No description provided for @timelineIntakeDoseLine.
  ///
  /// In tr, this message translates to:
  /// **'{name} ({dose}) alındı'**
  String timelineIntakeDoseLine(String name, String dose);

  /// No description provided for @timelineScheduledDose.
  ///
  /// In tr, this message translates to:
  /// **'{time} dozu'**
  String timelineScheduledDose(String time);

  /// No description provided for @timelineSkippedLine.
  ///
  /// In tr, this message translates to:
  /// **'{name} atlandı'**
  String timelineSkippedLine(String name);

  /// No description provided for @homeAnalytics.
  ///
  /// In tr, this message translates to:
  /// **'Analizler'**
  String get homeAnalytics;

  /// No description provided for @homeAnalyticsHint.
  ///
  /// In tr, this message translates to:
  /// **'Semptom, günlük ve ilaç eğilimleriniz'**
  String get homeAnalyticsHint;

  /// No description provided for @analyticsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Analizler'**
  String get analyticsTitle;

  /// No description provided for @analyticsTabSymptoms.
  ///
  /// In tr, this message translates to:
  /// **'Semptomlar'**
  String get analyticsTabSymptoms;

  /// No description provided for @analyticsTabDaily.
  ///
  /// In tr, this message translates to:
  /// **'Günlük'**
  String get analyticsTabDaily;

  /// No description provided for @analyticsTabEffect.
  ///
  /// In tr, this message translates to:
  /// **'İlaç etkisi'**
  String get analyticsTabEffect;

  /// No description provided for @analyticsTabAdherence.
  ///
  /// In tr, this message translates to:
  /// **'Uyum'**
  String get analyticsTabAdherence;

  /// No description provided for @analyticsTabFields.
  ///
  /// In tr, this message translates to:
  /// **'Ek alanlar'**
  String get analyticsTabFields;

  /// No description provided for @analyticsNoFields.
  ///
  /// In tr, this message translates to:
  /// **'Bu dönemde ek alan değeri girilmemiş'**
  String get analyticsNoFields;

  /// No description provided for @analyticsFieldYesNo.
  ///
  /// In tr, this message translates to:
  /// **'{yes} gün evet · {no} gün hayır'**
  String analyticsFieldYesNo(int yes, int no);

  /// No description provided for @analyticsFieldWithSymptom.
  ///
  /// In tr, this message translates to:
  /// **'Semptom kaydı olan günler: {value} ({n} gün)'**
  String analyticsFieldWithSymptom(String value, int n);

  /// No description provided for @analyticsFieldWithoutSymptom.
  ///
  /// In tr, this message translates to:
  /// **'Semptom kaydı olmayan günler: {value} ({n} gün)'**
  String analyticsFieldWithoutSymptom(String value, int n);

  /// No description provided for @analyticsFieldTooFew.
  ///
  /// In tr, this message translates to:
  /// **'Karşılaştırma için her grupta en az {n} gün gerekir'**
  String analyticsFieldTooFew(int n);

  /// No description provided for @analyticsFieldsNote.
  ///
  /// In tr, this message translates to:
  /// **'Bu karşılaştırma bir birliktelik gösterir; bir şeyin diğerine yol açtığını kanıtlamaz. Tıbbi tavsiye değildir.'**
  String get analyticsFieldsNote;

  /// No description provided for @analyticsDays.
  ///
  /// In tr, this message translates to:
  /// **'{n} gün'**
  String analyticsDays(int n);

  /// No description provided for @analyticsLoadError.
  ///
  /// In tr, this message translates to:
  /// **'Analizler okunamadı. Verileriniz silinmedi; ekranı kapatıp yeniden açmayı deneyin.'**
  String get analyticsLoadError;

  /// No description provided for @analyticsSymptomFrequency.
  ///
  /// In tr, this message translates to:
  /// **'Semptom sıklığı'**
  String get analyticsSymptomFrequency;

  /// No description provided for @analyticsSeverityTrend.
  ///
  /// In tr, this message translates to:
  /// **'Günlük ortalama şiddet'**
  String get analyticsSeverityTrend;

  /// No description provided for @analyticsNoSymptoms.
  ///
  /// In tr, this message translates to:
  /// **'Bu dönemde semptom kaydı yok'**
  String get analyticsNoSymptoms;

  /// No description provided for @analyticsNotEnoughData.
  ///
  /// In tr, this message translates to:
  /// **'Yeterli veri yok'**
  String get analyticsNotEnoughData;

  /// No description provided for @analyticsCount.
  ///
  /// In tr, this message translates to:
  /// **'{n} kez'**
  String analyticsCount(int n);

  /// No description provided for @analyticsAvg.
  ///
  /// In tr, this message translates to:
  /// **'Ort: {value}'**
  String analyticsAvg(String value);

  /// No description provided for @analyticsDailyAverages.
  ///
  /// In tr, this message translates to:
  /// **'Ortalamalar (son {n} gün)'**
  String analyticsDailyAverages(int n);

  /// No description provided for @analyticsSleep.
  ///
  /// In tr, this message translates to:
  /// **'Uyku'**
  String get analyticsSleep;

  /// No description provided for @analyticsWater.
  ///
  /// In tr, this message translates to:
  /// **'Su'**
  String get analyticsWater;

  /// No description provided for @analyticsMood.
  ///
  /// In tr, this message translates to:
  /// **'Ruh hali'**
  String get analyticsMood;

  /// No description provided for @analyticsEnergy.
  ///
  /// In tr, this message translates to:
  /// **'Enerji'**
  String get analyticsEnergy;

  /// No description provided for @analyticsHours.
  ///
  /// In tr, this message translates to:
  /// **'{value} saat'**
  String analyticsHours(String value);

  /// No description provided for @analyticsLiters.
  ///
  /// In tr, this message translates to:
  /// **'{value} litre'**
  String analyticsLiters(String value);

  /// No description provided for @analyticsOutOf5.
  ///
  /// In tr, this message translates to:
  /// **'{value} / 5'**
  String analyticsOutOf5(String value);

  /// No description provided for @analyticsMoodEnergyTrend.
  ///
  /// In tr, this message translates to:
  /// **'Ruh hali ve enerji eğilimi'**
  String get analyticsMoodEnergyTrend;

  /// No description provided for @analyticsNoDaily.
  ///
  /// In tr, this message translates to:
  /// **'Bu dönemde günlük kayıt yok'**
  String get analyticsNoDaily;

  /// No description provided for @analyticsEffectTitle.
  ///
  /// In tr, this message translates to:
  /// **'İlaç öncesi / sonrası şiddet'**
  String get analyticsEffectTitle;

  /// No description provided for @analyticsNoEffect.
  ///
  /// In tr, this message translates to:
  /// **'Bu dönemde ilaç-semptom eşleşmesi yok'**
  String get analyticsNoEffect;

  /// No description provided for @analyticsUsed.
  ///
  /// In tr, this message translates to:
  /// **'{n} kez kullanıldı'**
  String analyticsUsed(int n);

  /// No description provided for @analyticsBefore.
  ///
  /// In tr, this message translates to:
  /// **'Önce'**
  String get analyticsBefore;

  /// No description provided for @analyticsAfter.
  ///
  /// In tr, this message translates to:
  /// **'Sonra'**
  String get analyticsAfter;

  /// No description provided for @analyticsReliefMinutes.
  ///
  /// In tr, this message translates to:
  /// **'Ortalama etki: {n} dakika'**
  String analyticsReliefMinutes(int n);

  /// No description provided for @analyticsAdherenceTitle.
  ///
  /// In tr, this message translates to:
  /// **'Rutin ilaç uyumu'**
  String get analyticsAdherenceTitle;

  /// No description provided for @analyticsNoAdherence.
  ///
  /// In tr, this message translates to:
  /// **'Rutin ilaç tanımlanmamış'**
  String get analyticsNoAdherence;

  /// No description provided for @analyticsNoAdherenceData.
  ///
  /// In tr, this message translates to:
  /// **'Henüz veri yok'**
  String get analyticsNoAdherenceData;

  /// No description provided for @analyticsAdherenceLine.
  ///
  /// In tr, this message translates to:
  /// **'{taken} alındı · {skipped} atlandı · {unrecorded} kaydedilmedi'**
  String analyticsAdherenceLine(int taken, int skipped, int unrecorded);

  /// No description provided for @analyticsAdherenceWeekly.
  ///
  /// In tr, this message translates to:
  /// **'Haftalık uyum (her nokta 7 gün)'**
  String get analyticsAdherenceWeekly;

  /// No description provided for @analyticsExtra.
  ///
  /// In tr, this message translates to:
  /// **'Plansız alım: {n}'**
  String analyticsExtra(int n);

  /// No description provided for @analyticsAdherenceNote.
  ///
  /// In tr, this message translates to:
  /// **'Sayım, ilacın ilk kayıtlı dozundan başlar. Rutini sonradan değiştirdiyseniz geçmiş günler bugünkü rutininize göre hesaplanır.'**
  String get analyticsAdherenceNote;

  /// No description provided for @analyticsDisclaimer.
  ///
  /// In tr, this message translates to:
  /// **'Bu sayılar yalnız kendi kayıtlarınızdan hesaplanır; tıbbi tavsiye değildir.'**
  String get analyticsDisclaimer;

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

  /// No description provided for @onboardingSkip.
  ///
  /// In tr, this message translates to:
  /// **'Geç'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In tr, this message translates to:
  /// **'İleri'**
  String get onboardingNext;

  /// No description provided for @onboardingStart.
  ///
  /// In tr, this message translates to:
  /// **'Başla'**
  String get onboardingStart;

  /// No description provided for @onboardingTitle1.
  ///
  /// In tr, this message translates to:
  /// **'Sağlığınızı takip edin'**
  String get onboardingTitle1;

  /// No description provided for @onboardingBody1.
  ///
  /// In tr, this message translates to:
  /// **'Uyku, su, ruh hali ve enerjinizi günlük kayıtla birkaç saniyede not edin.'**
  String get onboardingBody1;

  /// No description provided for @onboardingTitle2.
  ///
  /// In tr, this message translates to:
  /// **'Semptomlarınızı kaydedin'**
  String get onboardingTitle2;

  /// No description provided for @onboardingBody2.
  ///
  /// In tr, this message translates to:
  /// **'Yaşadığınız şikâyetleri zamanı ve şiddetiyle yazın.'**
  String get onboardingBody2;

  /// Üçüncü tanıtım sayfası; kullanıcıya 'atak' değil 'dönem' denir.
  ///
  /// In tr, this message translates to:
  /// **'Dönemleri yönetin'**
  String get onboardingTitle3;

  /// No description provided for @onboardingBody3.
  ///
  /// In tr, this message translates to:
  /// **'Bir şikâyet dönemini başlatın, seyrini izleyin ve bittiğinde kapatın.'**
  String get onboardingBody3;

  /// No description provided for @onboardingTitle4.
  ///
  /// In tr, this message translates to:
  /// **'Eğilimlerinizi görün'**
  String get onboardingTitle4;

  /// No description provided for @onboardingBody4.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlarınızdan hesaplanan grafikleri ve ilaç etkisini inceleyin. Tıbbi tavsiye değildir.'**
  String get onboardingBody4;

  /// No description provided for @homeSettings.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar'**
  String get homeSettings;

  /// No description provided for @settingsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Ayarlar'**
  String get settingsTitle;

  /// No description provided for @settingsDataSection.
  ///
  /// In tr, this message translates to:
  /// **'Veriler'**
  String get settingsDataSection;

  /// No description provided for @settingsWipeTitle.
  ///
  /// In tr, this message translates to:
  /// **'Tüm verimi sil'**
  String get settingsWipeTitle;

  /// No description provided for @settingsWipeHint.
  ///
  /// In tr, this message translates to:
  /// **'Tüm kayıtlarınızı bu telefondan kalıcı olarak siler; geri alınamaz.'**
  String get settingsWipeHint;

  /// No description provided for @settingsProfileTitle.
  ///
  /// In tr, this message translates to:
  /// **'Profil'**
  String get settingsProfileTitle;

  /// No description provided for @settingsProfileEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Adınızı ve temel bilgilerinizi ekleyin'**
  String get settingsProfileEmpty;

  /// No description provided for @profileTitle.
  ///
  /// In tr, this message translates to:
  /// **'Profil'**
  String get profileTitle;

  /// No description provided for @profileIntro.
  ///
  /// In tr, this message translates to:
  /// **'Bu bilgiler yalnızca bu telefonda, şifreli veritabanınızda durur. Hepsi isteğe bağlıdır.'**
  String get profileIntro;

  /// No description provided for @profileFirstName.
  ///
  /// In tr, this message translates to:
  /// **'Ad'**
  String get profileFirstName;

  /// No description provided for @profileLastName.
  ///
  /// In tr, this message translates to:
  /// **'Soyad'**
  String get profileLastName;

  /// No description provided for @profileBirthDate.
  ///
  /// In tr, this message translates to:
  /// **'Doğum tarihi'**
  String get profileBirthDate;

  /// No description provided for @profileBirthDateNone.
  ///
  /// In tr, this message translates to:
  /// **'Seçilmedi'**
  String get profileBirthDateNone;

  /// No description provided for @profileBirthDateClear.
  ///
  /// In tr, this message translates to:
  /// **'Tarihi temizle'**
  String get profileBirthDateClear;

  /// No description provided for @profileGender.
  ///
  /// In tr, this message translates to:
  /// **'Cinsiyet'**
  String get profileGender;

  /// No description provided for @profileGenderNone.
  ///
  /// In tr, this message translates to:
  /// **'Belirtmek istemiyorum'**
  String get profileGenderNone;

  /// No description provided for @profileGenderFemale.
  ///
  /// In tr, this message translates to:
  /// **'Kadın'**
  String get profileGenderFemale;

  /// No description provided for @profileGenderMale.
  ///
  /// In tr, this message translates to:
  /// **'Erkek'**
  String get profileGenderMale;

  /// No description provided for @profileGenderOther.
  ///
  /// In tr, this message translates to:
  /// **'Diğer'**
  String get profileGenderOther;

  /// No description provided for @profilePhotoAdd.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf ekle'**
  String get profilePhotoAdd;

  /// No description provided for @profilePhotoChange.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğrafı değiştir'**
  String get profilePhotoChange;

  /// No description provided for @profilePhotoGallery.
  ///
  /// In tr, this message translates to:
  /// **'Galeriden seç'**
  String get profilePhotoGallery;

  /// No description provided for @profilePhotoCamera.
  ///
  /// In tr, this message translates to:
  /// **'Kamerayla çek'**
  String get profilePhotoCamera;

  /// No description provided for @profilePhotoRemove.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğrafı kaldır'**
  String get profilePhotoRemove;

  /// No description provided for @profilePhotoFailed.
  ///
  /// In tr, this message translates to:
  /// **'Fotoğraf alınamadı.'**
  String get profilePhotoFailed;

  /// No description provided for @profileSave.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get profileSave;

  /// No description provided for @profileSaved.
  ///
  /// In tr, this message translates to:
  /// **'Profil kaydedildi'**
  String get profileSaved;

  /// No description provided for @profileSaveFailed.
  ///
  /// In tr, this message translates to:
  /// **'Profil kaydedilemedi.'**
  String get profileSaveFailed;

  /// No description provided for @profileLoadFailed.
  ///
  /// In tr, this message translates to:
  /// **'Profil okunamadı.'**
  String get profileLoadFailed;

  /// No description provided for @profileRetry.
  ///
  /// In tr, this message translates to:
  /// **'Yeniden dene'**
  String get profileRetry;

  /// No description provided for @settingsBodyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Boy ve kilo'**
  String get settingsBodyTitle;

  /// No description provided for @settingsBodyHint.
  ///
  /// In tr, this message translates to:
  /// **'Kilo geçmişinizi ve boyunuzu kaydedin'**
  String get settingsBodyHint;

  /// No description provided for @bodyTitle.
  ///
  /// In tr, this message translates to:
  /// **'Boy ve kilo'**
  String get bodyTitle;

  /// No description provided for @bodyHeightSection.
  ///
  /// In tr, this message translates to:
  /// **'Boy'**
  String get bodyHeightSection;

  /// No description provided for @bodyHeightLabel.
  ///
  /// In tr, this message translates to:
  /// **'Boy (cm)'**
  String get bodyHeightLabel;

  /// No description provided for @bodyHeightSave.
  ///
  /// In tr, this message translates to:
  /// **'Boyu kaydet'**
  String get bodyHeightSave;

  /// No description provided for @bodyHeightSaved.
  ///
  /// In tr, this message translates to:
  /// **'Boy kaydedildi'**
  String get bodyHeightSaved;

  /// No description provided for @bodyWeightSection.
  ///
  /// In tr, this message translates to:
  /// **'Kilo'**
  String get bodyWeightSection;

  /// No description provided for @bodyWeightLabel.
  ///
  /// In tr, this message translates to:
  /// **'Kilo (kg)'**
  String get bodyWeightLabel;

  /// No description provided for @bodyWeightDate.
  ///
  /// In tr, this message translates to:
  /// **'Tarih'**
  String get bodyWeightDate;

  /// No description provided for @bodyToday.
  ///
  /// In tr, this message translates to:
  /// **'Bugün'**
  String get bodyToday;

  /// No description provided for @bodyWeightAdd.
  ///
  /// In tr, this message translates to:
  /// **'Kilo ekle'**
  String get bodyWeightAdd;

  /// No description provided for @bodyWeightAdded.
  ///
  /// In tr, this message translates to:
  /// **'Kilo kaydedildi'**
  String get bodyWeightAdded;

  /// No description provided for @bodyChartTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kilo değişimi'**
  String get bodyChartTitle;

  /// No description provided for @bodyChartNeedMore.
  ///
  /// In tr, this message translates to:
  /// **'Grafik için en az iki kilo kaydı gerekir.'**
  String get bodyChartNeedMore;

  /// No description provided for @bodyHistoryTitle.
  ///
  /// In tr, this message translates to:
  /// **'Geçmiş'**
  String get bodyHistoryTitle;

  /// No description provided for @bodyHistoryEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz kilo kaydı yok.'**
  String get bodyHistoryEmpty;

  /// No description provided for @bodyDeleteTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kayıt silinsin mi?'**
  String get bodyDeleteTitle;

  /// No description provided for @bodyDeleteBody.
  ///
  /// In tr, this message translates to:
  /// **'Bu kilo kaydı silinecek.'**
  String get bodyDeleteBody;

  /// No description provided for @bodyDeleteAction.
  ///
  /// In tr, this message translates to:
  /// **'Sil'**
  String get bodyDeleteAction;

  /// No description provided for @bodyDeleted.
  ///
  /// In tr, this message translates to:
  /// **'Kayıt silindi'**
  String get bodyDeleted;

  /// No description provided for @bodyErrNumber.
  ///
  /// In tr, this message translates to:
  /// **'Geçerli bir sayı girin.'**
  String get bodyErrNumber;

  /// No description provided for @bodyErrHeight.
  ///
  /// In tr, this message translates to:
  /// **'Boyu 50 ile 250 cm arasında girin.'**
  String get bodyErrHeight;

  /// No description provided for @bodyErrWeight.
  ///
  /// In tr, this message translates to:
  /// **'Kiloyu 2 ile 500 kg arasında girin.'**
  String get bodyErrWeight;

  /// No description provided for @bodyErrDay.
  ///
  /// In tr, this message translates to:
  /// **'Geçerli bir gün seçin.'**
  String get bodyErrDay;

  /// No description provided for @bodyErrGeneric.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedilemedi.'**
  String get bodyErrGeneric;

  /// No description provided for @bodyLoadFailed.
  ///
  /// In tr, this message translates to:
  /// **'Ölçümler okunamadı.'**
  String get bodyLoadFailed;

  /// No description provided for @profileHealthSection.
  ///
  /// In tr, this message translates to:
  /// **'Sağlık kartı'**
  String get profileHealthSection;

  /// No description provided for @profileHealthIntro.
  ///
  /// In tr, this message translates to:
  /// **'Yalnızca bu ekranda görünür; kilit ekranında ya da bildirimlerde gösterilmez.'**
  String get profileHealthIntro;

  /// No description provided for @profileBloodType.
  ///
  /// In tr, this message translates to:
  /// **'Kan grubu'**
  String get profileBloodType;

  /// No description provided for @profileBloodNone.
  ///
  /// In tr, this message translates to:
  /// **'Belirtilmedi'**
  String get profileBloodNone;

  /// No description provided for @profileAllergies.
  ///
  /// In tr, this message translates to:
  /// **'Alerjiler'**
  String get profileAllergies;

  /// No description provided for @profileAllergiesHint.
  ///
  /// In tr, this message translates to:
  /// **'Her satıra bir alerji yazın'**
  String get profileAllergiesHint;

  /// No description provided for @profileContactName.
  ///
  /// In tr, this message translates to:
  /// **'Acil durum kişisi'**
  String get profileContactName;

  /// No description provided for @profileContactPhone.
  ///
  /// In tr, this message translates to:
  /// **'Acil durum telefonu'**
  String get profileContactPhone;

  /// No description provided for @profilePhoneInvalid.
  ///
  /// In tr, this message translates to:
  /// **'Geçerli bir telefon numarası girin (7-15 rakam).'**
  String get profilePhoneInvalid;

  /// No description provided for @unsavedTitle.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedilmemiş değişiklikler var'**
  String get unsavedTitle;

  /// No description provided for @unsavedBody.
  ///
  /// In tr, this message translates to:
  /// **'Çıkarsanız girdiğiniz bilgiler kaybolur.'**
  String get unsavedBody;

  /// No description provided for @unsavedStay.
  ///
  /// In tr, this message translates to:
  /// **'Kal'**
  String get unsavedStay;

  /// No description provided for @unsavedLeave.
  ///
  /// In tr, this message translates to:
  /// **'Çık'**
  String get unsavedLeave;

  /// No description provided for @bodyHeightClear.
  ///
  /// In tr, this message translates to:
  /// **'Boyu temizle'**
  String get bodyHeightClear;

  /// No description provided for @bodyHeightClearTitle.
  ///
  /// In tr, this message translates to:
  /// **'Boy silinsin mi?'**
  String get bodyHeightClearTitle;

  /// No description provided for @bodyHeightClearBody.
  ///
  /// In tr, this message translates to:
  /// **'Kayıtlı boy bilgisi silinecek.'**
  String get bodyHeightClearBody;

  /// No description provided for @bodyHeightCleared.
  ///
  /// In tr, this message translates to:
  /// **'Boy silindi'**
  String get bodyHeightCleared;

  /// No description provided for @settingsBackupSection.
  ///
  /// In tr, this message translates to:
  /// **'Yedek'**
  String get settingsBackupSection;

  /// No description provided for @settingsBackupExportTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yedek al'**
  String get settingsBackupExportTitle;

  /// No description provided for @settingsBackupExportHint.
  ///
  /// In tr, this message translates to:
  /// **'Verilerinizi parolayla şifreli bir dosyaya kaydedin'**
  String get settingsBackupExportHint;

  /// No description provided for @backupTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yedek al'**
  String get backupTitle;

  /// No description provided for @backupIntro.
  ///
  /// In tr, this message translates to:
  /// **'Tüm kayıtlarınız, belirleyeceğiniz parolayla şifrelenmiş tek bir dosyaya yazılır. Dosyayı telefonunuzda, bulut depolamanızda ya da bir SD kartta saklayabilirsiniz.'**
  String get backupIntro;

  /// No description provided for @backupWarning.
  ///
  /// In tr, this message translates to:
  /// **'Bu parolayı unutursanız yedeğiniz açılamaz; kurtarma yolu yoktur. Parolayı güvenli bir yere not edin.'**
  String get backupWarning;

  /// No description provided for @backupPassphrase.
  ///
  /// In tr, this message translates to:
  /// **'Yedek parolası'**
  String get backupPassphrase;

  /// No description provided for @backupPassphraseConfirm.
  ///
  /// In tr, this message translates to:
  /// **'Parolayı tekrar yazın'**
  String get backupPassphraseConfirm;

  /// No description provided for @backupShowPassphrase.
  ///
  /// In tr, this message translates to:
  /// **'Parolayı göster'**
  String get backupShowPassphrase;

  /// No description provided for @backupHidePassphrase.
  ///
  /// In tr, this message translates to:
  /// **'Parolayı gizle'**
  String get backupHidePassphrase;

  /// No description provided for @backupTooShort.
  ///
  /// In tr, this message translates to:
  /// **'Parola en az {n} karakter olmalı'**
  String backupTooShort(int n);

  /// No description provided for @backupMismatch.
  ///
  /// In tr, this message translates to:
  /// **'Parolalar aynı değil'**
  String get backupMismatch;

  /// No description provided for @backupAction.
  ///
  /// In tr, this message translates to:
  /// **'Yedek al'**
  String get backupAction;

  /// No description provided for @backupWorking.
  ///
  /// In tr, this message translates to:
  /// **'Yedek hazırlanıyor…'**
  String get backupWorking;

  /// No description provided for @backupDone.
  ///
  /// In tr, this message translates to:
  /// **'Yedek kaydedildi.'**
  String get backupDone;

  /// No description provided for @backupCancelled.
  ///
  /// In tr, this message translates to:
  /// **'Konum seçilmedi; yedek alınmadı.'**
  String get backupCancelled;

  /// No description provided for @backupFailed.
  ///
  /// In tr, this message translates to:
  /// **'Yedek alınamadı. Verileriniz silinmedi; tekrar deneyin.'**
  String get backupFailed;

  /// No description provided for @commonOk.
  ///
  /// In tr, this message translates to:
  /// **'Tamam'**
  String get commonOk;

  /// No description provided for @settingsRestoreTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yedekten geri yükle'**
  String get settingsRestoreTitle;

  /// No description provided for @settingsRestoreHint.
  ///
  /// In tr, this message translates to:
  /// **'Daha önce aldığınız yedeği bu telefona yükleyin'**
  String get settingsRestoreHint;

  /// No description provided for @restoreTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yedekten geri yükle'**
  String get restoreTitle;

  /// No description provided for @restoreIntro.
  ///
  /// In tr, this message translates to:
  /// **'Daha önce aldığınız yedek dosyasını seçin ve yedeği alırken belirlediğiniz parolayı yazın.'**
  String get restoreIntro;

  /// No description provided for @restoreWarning.
  ///
  /// In tr, this message translates to:
  /// **'Geri yükleme, telefondaki mevcut tüm kayıtlarınızın yerine yedektekileri koyar ve geri alınamaz. Önce güncel bir yedek almanız önerilir.'**
  String get restoreWarning;

  /// No description provided for @restorePick.
  ///
  /// In tr, this message translates to:
  /// **'Yedek dosyası seç'**
  String get restorePick;

  /// No description provided for @restoreNoFile.
  ///
  /// In tr, this message translates to:
  /// **'Henüz dosya seçilmedi'**
  String get restoreNoFile;

  /// No description provided for @restorePassphrase.
  ///
  /// In tr, this message translates to:
  /// **'Yedek parolası'**
  String get restorePassphrase;

  /// No description provided for @restoreAction.
  ///
  /// In tr, this message translates to:
  /// **'Geri yükle'**
  String get restoreAction;

  /// No description provided for @restoreWorking.
  ///
  /// In tr, this message translates to:
  /// **'Geri yükleniyor…'**
  String get restoreWorking;

  /// No description provided for @restoreNeedFile.
  ///
  /// In tr, this message translates to:
  /// **'Önce bir yedek dosyası seçin'**
  String get restoreNeedFile;

  /// No description provided for @restoreNeedPassphrase.
  ///
  /// In tr, this message translates to:
  /// **'Yedek parolasını yazın'**
  String get restoreNeedPassphrase;

  /// No description provided for @restoreConfirmTitle.
  ///
  /// In tr, this message translates to:
  /// **'Geri yüklensin mi?'**
  String get restoreConfirmTitle;

  /// No description provided for @restoreConfirmBody.
  ///
  /// In tr, this message translates to:
  /// **'Telefondaki mevcut tüm kayıtlarınız silinir ve yedektekilerle değiştirilir. Bu işlem geri alınamaz.'**
  String get restoreConfirmBody;

  /// No description provided for @restoreDoneTitle.
  ///
  /// In tr, this message translates to:
  /// **'Geri yüklendi'**
  String get restoreDoneTitle;

  /// No description provided for @restoreDoneBody.
  ///
  /// In tr, this message translates to:
  /// **'Verileriniz yedekten geri yüklendi.'**
  String get restoreDoneBody;

  /// No description provided for @restoreErrWrong.
  ///
  /// In tr, this message translates to:
  /// **'Parola yanlış ya da dosya bozuk. Mevcut verileriniz değişmedi.'**
  String get restoreErrWrong;

  /// No description provided for @restoreErrNewer.
  ///
  /// In tr, this message translates to:
  /// **'Bu yedek uygulamanın daha yeni bir sürümüyle alınmış. Önce uygulamayı güncelleyin. Mevcut verileriniz değişmedi.'**
  String get restoreErrNewer;

  /// No description provided for @restoreErrNotBackup.
  ///
  /// In tr, this message translates to:
  /// **'Bu dosya bir Vitapuls yedeği değil. Mevcut verileriniz değişmedi.'**
  String get restoreErrNotBackup;

  /// No description provided for @restoreErrIo.
  ///
  /// In tr, this message translates to:
  /// **'Geri yüklenemedi. Mevcut verileriniz değişmedi; tekrar deneyin.'**
  String get restoreErrIo;

  /// No description provided for @extraFieldsTitle.
  ///
  /// In tr, this message translates to:
  /// **'Ek alanlar'**
  String get extraFieldsTitle;

  /// No description provided for @extraFieldsEdit.
  ///
  /// In tr, this message translates to:
  /// **'Alanları düzenle'**
  String get extraFieldsEdit;

  /// No description provided for @extraFieldsEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Henüz açık ek alan yok. Kafein, spor, ağrı gibi hazır alanları açabilir ya da kendi alanınızı ekleyebilirsiniz.'**
  String get extraFieldsEmpty;

  /// No description provided for @extraFieldsSaveError.
  ///
  /// In tr, this message translates to:
  /// **'Günlük kaydedildi ama ek alanlar kaydedilemedi. Tekrar deneyin.'**
  String get extraFieldsSaveError;

  /// No description provided for @extraFieldYes.
  ///
  /// In tr, this message translates to:
  /// **'Evet'**
  String get extraFieldYes;

  /// No description provided for @extraFieldNo.
  ///
  /// In tr, this message translates to:
  /// **'Hayır'**
  String get extraFieldNo;

  /// No description provided for @fieldsScreenTitle.
  ///
  /// In tr, this message translates to:
  /// **'Günlük alanları'**
  String get fieldsScreenTitle;

  /// No description provided for @fieldsIntro.
  ///
  /// In tr, this message translates to:
  /// **'Açık alanlar günlük kaydınızda görünür. Bir alanı kapatmak eski değerlerini silmez.'**
  String get fieldsIntro;

  /// No description provided for @fieldsAdd.
  ///
  /// In tr, this message translates to:
  /// **'Alan ekle'**
  String get fieldsAdd;

  /// No description provided for @fieldsAddTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yeni alan'**
  String get fieldsAddTitle;

  /// No description provided for @fieldsEditTitle.
  ///
  /// In tr, this message translates to:
  /// **'Alanı düzenle'**
  String get fieldsEditTitle;

  /// No description provided for @fieldsName.
  ///
  /// In tr, this message translates to:
  /// **'Alan adı'**
  String get fieldsName;

  /// No description provided for @fieldsKind.
  ///
  /// In tr, this message translates to:
  /// **'Tür'**
  String get fieldsKind;

  /// No description provided for @fieldsKindNumber.
  ///
  /// In tr, this message translates to:
  /// **'Sayı'**
  String get fieldsKindNumber;

  /// No description provided for @fieldsKindScale.
  ///
  /// In tr, this message translates to:
  /// **'1–5 ölçek'**
  String get fieldsKindScale;

  /// No description provided for @fieldsKindYesNo.
  ///
  /// In tr, this message translates to:
  /// **'Evet / hayır'**
  String get fieldsKindYesNo;

  /// No description provided for @fieldsUnit.
  ///
  /// In tr, this message translates to:
  /// **'Birim (isteğe bağlı)'**
  String get fieldsUnit;

  /// No description provided for @fieldsMin.
  ///
  /// In tr, this message translates to:
  /// **'En az'**
  String get fieldsMin;

  /// No description provided for @fieldsMax.
  ///
  /// In tr, this message translates to:
  /// **'En çok'**
  String get fieldsMax;

  /// No description provided for @fieldsBuiltin.
  ///
  /// In tr, this message translates to:
  /// **'Hazır alan'**
  String get fieldsBuiltin;

  /// No description provided for @fieldsSave.
  ///
  /// In tr, this message translates to:
  /// **'Kaydet'**
  String get fieldsSave;

  /// No description provided for @fieldsSaved.
  ///
  /// In tr, this message translates to:
  /// **'Alan kaydedildi'**
  String get fieldsSaved;

  /// No description provided for @fieldsRetry.
  ///
  /// In tr, this message translates to:
  /// **'Tekrar dene'**
  String get fieldsRetry;

  /// No description provided for @fieldsLoadError.
  ///
  /// In tr, this message translates to:
  /// **'Alanlar yüklenemedi.'**
  String get fieldsLoadError;

  /// No description provided for @fieldsSaveError.
  ///
  /// In tr, this message translates to:
  /// **'Kaydedilemedi, tekrar deneyin.'**
  String get fieldsSaveError;

  /// No description provided for @fieldsToggleError.
  ///
  /// In tr, this message translates to:
  /// **'Alan değiştirilemedi.'**
  String get fieldsToggleError;

  /// No description provided for @fieldsErrNameEmpty.
  ///
  /// In tr, this message translates to:
  /// **'Alan adı boş olamaz.'**
  String get fieldsErrNameEmpty;

  /// No description provided for @fieldsErrNameTooLong.
  ///
  /// In tr, this message translates to:
  /// **'Alan adı en çok 40 karakter olabilir.'**
  String get fieldsErrNameTooLong;

  /// No description provided for @fieldsErrNameExists.
  ///
  /// In tr, this message translates to:
  /// **'Bu adda bir alan zaten var.'**
  String get fieldsErrNameExists;

  /// No description provided for @fieldsErrUnitTooLong.
  ///
  /// In tr, this message translates to:
  /// **'Birim en çok 12 karakter olabilir.'**
  String get fieldsErrUnitTooLong;

  /// No description provided for @fieldsErrRange.
  ///
  /// In tr, this message translates to:
  /// **'En az değer, en çok değerden küçük olmalı.'**
  String get fieldsErrRange;

  /// No description provided for @fieldsErrTooMany.
  ///
  /// In tr, this message translates to:
  /// **'En çok 30 özel alan ekleyebilirsiniz.'**
  String get fieldsErrTooMany;

  /// No description provided for @extraFieldInvalid.
  ///
  /// In tr, this message translates to:
  /// **'{name} için geçerli bir değer girin ({range}).'**
  String extraFieldInvalid(String name, String range);

  /// No description provided for @analyticsSleepTrend.
  ///
  /// In tr, this message translates to:
  /// **'Uyku eğilimi (saat)'**
  String get analyticsSleepTrend;

  /// No description provided for @analyticsWaterTrend.
  ///
  /// In tr, this message translates to:
  /// **'Su eğilimi (litre)'**
  String get analyticsWaterTrend;

  /// No description provided for @analyticsSmoothedNote.
  ///
  /// In tr, this message translates to:
  /// **'Çok günlük dönemlerde çizgiler 7 günlük hareketli ortalamadır; kayıt girilmeyen günler hesaba katılmaz.'**
  String get analyticsSmoothedNote;
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
