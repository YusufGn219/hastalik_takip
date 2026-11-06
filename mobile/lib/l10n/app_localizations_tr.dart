// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Vitapuls';

  @override
  String get homeTitle => 'Vitapuls';

  @override
  String get homeSubtitle => 'Bugün ne kaydetmek istersiniz?';

  @override
  String get homeDailyLog => 'Günlük kayıt';

  @override
  String get homeDailyLogHint => 'Uyku, su, ruh hali ve enerji';

  @override
  String get homeSymptoms => 'Semptom girişi';

  @override
  String get homeSymptomsHint =>
      'Bir şikâyet ekleyin ya da devam eden döneme not düşün';

  @override
  String get homeEpisodes => 'Dönemler';

  @override
  String get homeEpisodesHint => 'Devam eden ve biten dönemler';

  @override
  String get homeMedication => 'İlaç / takviye';

  @override
  String get homeMedicationHint => 'Aldığınız ilacı ya da takviyeyi kaydedin';

  @override
  String get medLogTitle => 'İlaç / Takviye Al';

  @override
  String get medLogPick => 'İlaç seç';

  @override
  String get medLogAddNew => 'Yeni ilaç ekle';

  @override
  String get medLogPickHint => 'İlaç seçin...';

  @override
  String get medLogDoseLabel => 'Doz miktarı (isteğe bağlı)';

  @override
  String get medLogNoteLabel => 'Not (isteğe bağlı)';

  @override
  String get medLogSave => 'Kaydet';

  @override
  String get medLogSaved => 'İlaç kaydedildi.';

  @override
  String get medLogPickRequired => 'Lütfen bir ilaç seçin.';

  @override
  String get medLogLoadError =>
      'İlaç listesi okunamadı. Ekranı kapatıp yeniden açmayı deneyin.';

  @override
  String get medLogSaveError =>
      'İlaç kaydedilemedi. Tekrar deneyin; yazdıklarınız korunur.';

  @override
  String get medLogAddError => 'İlaç eklenemedi. Tekrar deneyin.';

  @override
  String get medLogNewTitle => 'Yeni İlaç Ekle';

  @override
  String get medLogNewName => 'İlaç adı';

  @override
  String get medLogCancel => 'İptal';

  @override
  String get medLogAdd => 'Ekle';

  @override
  String medLogAdded(String name) {
    return '$name eklendi.';
  }

  @override
  String medLogExistsSelected(String name) {
    return '$name zaten var, seçildi.';
  }

  @override
  String get dailyLogLoadError =>
      'Bugünün kaydı okunamadı. Mevcut değerleriniz silinmedi; ekranı kapatıp yeniden açmayı deneyin.';

  @override
  String get dailyLogSleepInvalid =>
      'Uyku süresini 0 ile 24 saat arasında bir sayı olarak girin.';

  @override
  String get dailyLogWaterInvalid =>
      'Su tüketimini 0 ile 10 litre arasında bir sayı olarak girin.';

  @override
  String get dailyLogSaved => 'Günlük kayıt kaydedildi';

  @override
  String get dailyLogUpdated => 'Günlük kayıt güncellendi';

  @override
  String get dailyLogSaveError =>
      'Kayıt kaydedilemedi. Girdiğiniz değerler ekranda duruyor; yeniden deneyin.';

  @override
  String get symptomsLoadError =>
      'Semptom listesi okunamadı. Kayıtlarınız silinmedi; ekranı kapatıp yeniden açmayı deneyin.';

  @override
  String get symptomSelectRequired => 'Lütfen bir semptom seçin';

  @override
  String get symptomSaved => 'Semptom kaydedildi';

  @override
  String get symptomSaveError =>
      'Semptom kaydedilemedi. Girdiğiniz değerler ekranda duruyor; yeniden deneyin.';

  @override
  String get symptomAdded => 'Semptom eklendi';

  @override
  String get symptomExistsSelected =>
      'Bu semptom listede zaten var, onu seçtim.';

  @override
  String get symptomAddError => 'Semptom eklenemedi. Yeniden deneyin.';

  @override
  String get symptomEpisodeTrackTitle => 'Dönem takibi';

  @override
  String get symptomEpisodeTrackQuestion =>
      'Bu şikâyeti bir dönem olarak takip etmek ister misiniz?';

  @override
  String get symptomEpisodeTrackNo => 'Hayır, sadece kaydet';

  @override
  String get symptomEpisodeTrackYes => 'Evet, dönem başlat';

  @override
  String get symptomSavedEpisodeStarted =>
      'Semptom kaydedildi ve dönem başlatıldı';

  @override
  String symptomEpisodeOngoingTitle(String symptom) {
    return 'Devam eden $symptom döneminiz var';
  }

  @override
  String get symptomEpisodeOngoingQuestion => 'Bu kayıt nasıl eklensin?';

  @override
  String get symptomEpisodeIndependent => 'Bağımsız kayıt';

  @override
  String get symptomEpisodeAdd => 'Döneme ekle';

  @override
  String get symptomEpisodeNewLocation => 'Yeni konumla ekle';

  @override
  String get symptomAddedToEpisode => 'Semptom kaydedildi ve döneme eklendi';

  @override
  String get symptomAddedToEpisodeNewLocation =>
      'Semptom kaydedildi, yeni konumla döneme eklendi';

  @override
  String get symptomEpisodeError =>
      'Semptom kaydedildi ama dönem işlemi yapılamadı.';

  @override
  String get episodesTitle => 'Dönemler';

  @override
  String get episodesTabActive => 'Aktif';

  @override
  String get episodesTabHistory => 'Geçmiş';

  @override
  String get episodesEmptyActive => 'Devam eden dönem yok';

  @override
  String get episodesEmptyHistory => 'Geçmiş dönem yok';

  @override
  String get episodesLoadError =>
      'Dönemler okunamadı. Kayıtlarınız silinmedi; yenilemeyi deneyin.';

  @override
  String get episodesRefresh => 'Yenile';

  @override
  String episodeSeverity(String value) {
    return 'Şiddet: $value/10';
  }

  @override
  String episodeMaxSeverity(String value) {
    return 'Maks. şiddet: $value/10';
  }

  @override
  String episodeStart(String time) {
    return 'Başlangıç: $time';
  }

  @override
  String episodeLocation(String locations) {
    return 'Lokasyon: $locations';
  }

  @override
  String get episodeNoLocation => 'Lokasyon belirtilmemiş';

  @override
  String episodeRange(String start, String end, String duration) {
    return '$start → $end · $duration';
  }

  @override
  String episodeDurationHoursMinutes(int hours, int minutes) {
    return '$hours saat $minutes dakika';
  }

  @override
  String episodeDurationMinutes(int minutes) {
    return '$minutes dakika';
  }

  @override
  String get episodeAddMedication => 'İlaç Ekle';

  @override
  String get episodeClose => 'Dönemi Kapat';

  @override
  String episodeIntakeWithDose(String name, String dose, String time) {
    return 'İlaç: $name ($dose) · $time';
  }

  @override
  String episodeIntakeNoDose(String name, String time) {
    return 'İlaç: $name · $time';
  }

  @override
  String get episodeMedicationTitle => 'Döneme İlaç Ekle';

  @override
  String get episodeMedicationHint => 'İlaç seçin...';

  @override
  String get episodeMedicationNone => 'Kayıtlı ilaç yok.';

  @override
  String get episodeMedicationLoadError => 'İlaç listesi okunamadı.';

  @override
  String get episodeMedicationPick => 'Lütfen bir ilaç seçin';

  @override
  String get episodeDoseLabel => 'Doz miktarı';

  @override
  String get episodeDoseInvalid => 'Doz sıfırdan büyük bir sayı olmalı';

  @override
  String get episodeMedicationSave => 'Kaydet';

  @override
  String get episodeMedicationSaved => 'İlaç döneme eklendi.';

  @override
  String get episodeMedicationSaveFailed =>
      'İlaç kaydedilemedi. Tekrar deneyin.';

  @override
  String get doseUnitTablet => 'tablet';

  @override
  String get doseUnitMg => 'mg';

  @override
  String get doseUnitMl => 'ml';

  @override
  String get doseUnitDrop => 'damla';

  @override
  String get doseUnitCapsule => 'kapsül';

  @override
  String get episodeClosed => 'Dönem kapatıldı.';

  @override
  String get episodeCloseNotesLabel => 'Nasıl geçti? (isteğe bağlı)';

  @override
  String get episodeCloseNotesHint => 'Örn: Uyuyarak geçirdim, ilaç aldım...';

  @override
  String get episodeCloseAlreadyClosed =>
      'Bu dönem zaten kapatılmış. Listeyi yenileyin.';

  @override
  String get episodeCloseEndBeforeStart =>
      'Bitiş zamanı başlangıçtan önce olamaz. Cihazın saatini kontrol edin.';

  @override
  String get episodeCloseFailed =>
      'Dönem kapatılamadı. Tekrar deneyin; yazdığınız not korunur.';

  @override
  String get dbOpenErrorTitle => 'Veritabanı açılamadı';

  @override
  String get dbOpenErrorBody =>
      'Şifreli veritabanı açılamadı. Uygulamayı tamamen kapatıp yeniden açmayı deneyin.';

  @override
  String get commonContinue => 'Devam';

  @override
  String get commonCancel => 'Vazgeç';

  @override
  String get commonBack => 'Geri';

  @override
  String waitSeconds(int n) {
    return '$n sn';
  }

  @override
  String waitMinutes(int m, String s) {
    return '$m dk $s sn';
  }

  @override
  String get lockTitle => 'Vitapuls kilitli';

  @override
  String get lockEnterPin => 'PIN\'inizi girin';

  @override
  String get lockWrongPin => 'Yanlış PIN';

  @override
  String lockBlocked(String wait) {
    return 'Çok fazla yanlış deneme. $wait sonra tekrar deneyin.';
  }

  @override
  String get lockBackspace => 'Sil';

  @override
  String get lockBiometricReason =>
      'Vitapuls\'ın kilidini açmak için doğrulayın';

  @override
  String get lockBiometricButton => 'Parmak iziyle aç';

  @override
  String get lockForgotPin => 'PIN\'imi unuttum';

  @override
  String get lockSetupTitle => 'PIN belirleyin';

  @override
  String get lockSetupEnter => 'Yeni PIN belirleyin (4-8 rakam)';

  @override
  String get lockSetupConfirm => 'PIN\'i tekrar girin';

  @override
  String get lockSetupMismatch => 'PIN\'ler uyuşmadı, baştan başlayın';

  @override
  String get lockConfirmCurrent => 'Mevcut PIN\'inizi girin';

  @override
  String get recoveryCodeTitle => 'Kurtarma kodunuz';

  @override
  String get recoveryCodeBody =>
      'PIN\'inizi unutursanız verilerinize bu kodla dönebilirsiniz. Kodu bir kâğıda yazıp güvenli bir yerde saklayın. Bir daha gösterilmeyecek. PIN\'i ve kodu birlikte kaybederseniz verileriniz kurtarılamaz.';

  @override
  String get recoveryCodeConfirm => 'Kodu yazdım ve sakladım';

  @override
  String get recoveryCodeDone => 'Bitti';

  @override
  String get recoveryTitle => 'PIN\'imi unuttum';

  @override
  String get recoveryEnterCode => '12 karakterlik kurtarma kodunuzu girin';

  @override
  String get recoveryCodeField => 'Kurtarma kodu';

  @override
  String get recoveryCodeInvalid => 'Kod 12 karakter olmalı (harf ve rakam)';

  @override
  String get recoveryWrongCode => 'Kod yanlış';

  @override
  String recoveryBlocked(String wait) {
    return 'Çok fazla yanlış deneme. $wait sonra tekrar deneyin.';
  }

  @override
  String get recoveryLostBoth => 'Kodu da kaybettim';

  @override
  String get wipeTitle => 'Tüm veriler silinsin mi?';

  @override
  String get wipeBody =>
      'Bu işlem tüm kayıtlarınızı kalıcı olarak siler ve geri alınamaz. Uygulama boş başlar.';

  @override
  String get wipeConfirm => 'Tümünü sil';

  @override
  String get wipeFailed => 'Silinemedi, tekrar deneyin';

  @override
  String get lockSettingsTitle => 'Uygulama kilidi';

  @override
  String get lockSettingsOffHint =>
      'Kapalı. Açılışta PIN ya da parmak izi istenmez.';

  @override
  String get lockSettingsOnHint =>
      'Açık. Açılışta PIN ya da parmak izi istenir.';

  @override
  String get lockSettingsBiometric => 'Parmak iziyle aç';

  @override
  String get lockSettingsTimeout => 'Arka plandan dönünce kilitle';

  @override
  String get lockTimeoutNow => 'Hemen';

  @override
  String lockTimeoutSeconds(int n) {
    return '$n sn sonra';
  }

  @override
  String lockTimeoutMinutes(int n) {
    return '$n dk sonra';
  }

  @override
  String get lockSettingsLockNow => 'Şimdi kilitle';
}
