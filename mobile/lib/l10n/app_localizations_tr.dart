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
