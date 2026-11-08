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
  String get medLogCategoryLabel => 'Kategori (isteğe bağlı)';

  @override
  String get medLogNoCategory => 'Kategorisiz';

  @override
  String get medLogNewCategory => 'Yeni kategori oluştur…';

  @override
  String get medLogNewCategoryName => 'Yeni kategori adı';

  @override
  String get medLogManageCategories => 'Kategoriler';

  @override
  String get medLogCategoryChanged => 'Kategori güncellendi.';

  @override
  String get medLogCategoryError => 'Kategori kaydedilemedi. Tekrar deneyin.';

  @override
  String get homeConditions => 'Kronik hastalıklar';

  @override
  String get homeConditionsHint =>
      'Hastalıklarınızı ve kullandığınız ilaçları yönetin';

  @override
  String get homeRoutines => 'Rutin ilaçlar';

  @override
  String get homeRoutinesHint =>
      'Her gün ya da belirli günlerde alacağınız ilaçlar';

  @override
  String get routineTitle => 'Rutinlerim';

  @override
  String get routineAddTooltip => 'Rutin ekle';

  @override
  String get routineTodayTitle => 'Bugünün rutinleri';

  @override
  String get routineTodayEmpty => 'Bugün için rutin yok.';

  @override
  String get routineAllTitle => 'Tüm rutinler';

  @override
  String get routineAllEmpty => 'Henüz rutin tanımlanmamış.';

  @override
  String get routineOtherGroup => 'Diğer';

  @override
  String get routineEveryDay => 'Her gün';

  @override
  String get routineTaken => 'Aldım';

  @override
  String routineTakenSaved(String name) {
    return '$name alındı olarak kaydedildi.';
  }

  @override
  String get routineNewTitle => 'Yeni rutin';

  @override
  String get routineMedLabel => 'İlaç';

  @override
  String get routineMedHint => 'İlaç seçin';

  @override
  String get routineNoMedsAvailable =>
      'Rutin kurulacak ilaç yok. Önce İlaç / takviye ekranından ilaç ekleyin ya da var olan rutinlerden birini kapatın.';

  @override
  String get routineTimesLabel => 'Doz saatleri';

  @override
  String get routineAddTime => 'Saat ekle';

  @override
  String get routineRemoveTime => 'Saati sil';

  @override
  String get routineSkip => 'Atladım';

  @override
  String get routineStateTaken => 'Alındı';

  @override
  String get routineStateSkipped => 'Atlandı';

  @override
  String get routineStateWaiting => 'Bekliyor';

  @override
  String get routineStateUnrecorded => 'Kaydedilmedi';

  @override
  String routineSkippedSaved(String name) {
    return '$name atlandı olarak kaydedildi.';
  }

  @override
  String get routineAddedNoReminder =>
      'Rutin eklendi ama hatırlatma kurulamadı.';

  @override
  String get routineClosedNoReminder =>
      'Rutin kapatıldı ama hatırlatma iptal edilemedi.';

  @override
  String get reminderPermTitle => 'Bildirim izni';

  @override
  String get reminderPermBody =>
      'İlaç saatinde hatırlatma gelmesi için Vitapuls\'ın bildirim göstermesine izin vermeniz gerekir. Bildirimde ilaç adı yazmaz.';

  @override
  String get reminderPermContinue => 'Devam';

  @override
  String get reminderPermLater => 'Şimdi değil';

  @override
  String get reminderOffBanner =>
      'Bildirimler kapalı: doz saatinde hatırlatma gelmez. Telefonun Ayarlar > Uygulamalar > Vitapuls > Bildirimler bölümünden açabilirsiniz.';

  @override
  String get reminderInexactBanner =>
      'Hatırlatmalar tam saatinde değil, birkaç dakika sapmayla gelebilir.';

  @override
  String get reminderExactButton => 'Tam saatte gelmesi için izin ver';

  @override
  String get reminderTitle => 'Vitapuls';

  @override
  String get reminderBody => 'İlaç saatiniz geldi';

  @override
  String get reminderChannelName => 'İlaç hatırlatmaları';

  @override
  String get reminderChannelDescription =>
      'Rutin ilaç dozlarının saatinde gelen hatırlatmalar';

  @override
  String get routineErrorTimes => 'En az bir doz saati seçin.';

  @override
  String get routineErrorTooManyTimes => 'Günde en çok 10 doz saati olabilir.';

  @override
  String get routineErrorDoseTaken => 'Bu doz zaten alındı olarak kaydedilmiş.';

  @override
  String get routineErrorDoseSkipped =>
      'Bu doz zaten atlandı olarak kaydedilmiş.';

  @override
  String get routineErrorDoseNotScheduled =>
      'Bu doz artık planlı değil. Ekranı yenileyip tekrar deneyin.';

  @override
  String get routineDaysLabel => 'Günler';

  @override
  String get routineSave => 'Kaydet';

  @override
  String get routineCancel => 'İptal';

  @override
  String get routineAdded => 'Rutin eklendi.';

  @override
  String get routineCloseTooltip => 'Rutini kapat';

  @override
  String get routineCloseTitle => 'Rutin kapatılsın mı?';

  @override
  String routineCloseBody(String name) {
    return '\"$name\" rutini kapatılır; ilacınız ve eski ilaç kayıtlarınız silinmez.';
  }

  @override
  String get routineCloseConfirm => 'Kapat';

  @override
  String get routineClosed => 'Rutin kapatıldı.';

  @override
  String get routineLoadError =>
      'Rutinler okunamadı. Ekranı kapatıp yeniden açmayı deneyin.';

  @override
  String get routineErrorNoMed => 'Önce bir ilaç seçin.';

  @override
  String get routineErrorDays => 'En az bir gün seçin.';

  @override
  String get routineErrorTime => 'Saat geçerli değil.';

  @override
  String get routineErrorMedication =>
      'Seçtiğiniz ilaç artık yok. Ekranı yenileyip tekrar deneyin.';

  @override
  String get routineErrorGeneric => 'İşlem yapılamadı. Tekrar deneyin.';

  @override
  String get dayMonShort => 'Pzt';

  @override
  String get dayTueShort => 'Sal';

  @override
  String get dayWedShort => 'Çar';

  @override
  String get dayThuShort => 'Per';

  @override
  String get dayFriShort => 'Cum';

  @override
  String get daySatShort => 'Cmt';

  @override
  String get daySunShort => 'Paz';

  @override
  String get condTitle => 'Kronik Hastalıklarım';

  @override
  String get condAddTooltip => 'Hastalık ekle';

  @override
  String get condEmpty => 'Henüz kronik hastalık eklenmemiş.';

  @override
  String get condNewTitle => 'Yeni Kronik Hastalık';

  @override
  String get condEditTitle => 'Hastalığı Düzenle';

  @override
  String get condNameLabel => 'Hastalık adı';

  @override
  String get condMedsLabel => 'İlaçlar';

  @override
  String get condNoMeds => 'İlaç eklenmemiş.';

  @override
  String get condNoMedsAvailable => 'Seçilecek ilaç yok.';

  @override
  String get condSave => 'Kaydet';

  @override
  String get condCancel => 'İptal';

  @override
  String get condEditTooltip => 'Düzenle';

  @override
  String get condDeleteTooltip => 'Sil';

  @override
  String get condDeleteTitle => 'Hastalık silinsin mi?';

  @override
  String condDeleteBody(String name) {
    return '\"$name\" silinir; ilaçlarınız ve eski ilaç kayıtlarınız silinmez.';
  }

  @override
  String get condDeleteConfirm => 'Sil';

  @override
  String get condAdded => 'Hastalık eklendi.';

  @override
  String get condUpdated => 'Hastalık güncellendi.';

  @override
  String get condDeleted => 'Hastalık silindi.';

  @override
  String get condLoadError =>
      'Kronik hastalıklar okunamadı. Ekranı kapatıp yeniden açmayı deneyin.';

  @override
  String get condErrorEmpty => 'Hastalık adı boş olamaz.';

  @override
  String get condErrorTooLong => 'Hastalık adı en çok 200 karakter olabilir.';

  @override
  String get condErrorExists => 'Bu adla bir kronik hastalık zaten var.';

  @override
  String get condErrorMedication =>
      'Seçtiğiniz ilaçlardan biri artık yok. Ekranı yenileyip tekrar deneyin.';

  @override
  String get condErrorGeneric => 'İşlem yapılamadı. Tekrar deneyin.';

  @override
  String get medCatTitle => 'Kategoriler';

  @override
  String get medCatEmpty => 'Henüz kategori yok. Aşağıdan ekleyebilirsiniz.';

  @override
  String get medCatNameLabel => 'Kategori adı';

  @override
  String get medCatAdd => 'Ekle';

  @override
  String get medCatRename => 'Adı değiştir';

  @override
  String get medCatRenameTitle => 'Kategori adı';

  @override
  String get medCatSave => 'Kaydet';

  @override
  String get medCatDelete => 'Sil';

  @override
  String get medCatClose => 'Kapat';

  @override
  String get medCatDeleteTitle => 'Kategori silinsin mi?';

  @override
  String medCatDeleteBody(String name) {
    return '\"$name\" silinir; bu kategorideki ilaçlar silinmez, kategorisiz kalır.';
  }

  @override
  String get medCatErrorEmpty => 'Kategori adı boş olamaz.';

  @override
  String get medCatErrorTooLong => 'Kategori adı en çok 100 karakter olabilir.';

  @override
  String get medCatErrorExists => 'Bu adla bir kategori zaten var.';

  @override
  String get medCatErrorGeneric => 'İşlem yapılamadı. Tekrar deneyin.';

  @override
  String get medCatLoadError => 'Kategoriler okunamadı.';

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
  String get homeTimeline => 'Zaman çizelgesi';

  @override
  String get homeTimelineHint => 'Günün kayıtlarını sırayla görün';

  @override
  String get timelineTitle => 'Zaman çizelgesi';

  @override
  String get timelinePrevDay => 'Önceki gün';

  @override
  String get timelineNextDay => 'Sonraki gün';

  @override
  String get timelineGoToday => 'Bugüne dön';

  @override
  String get timelineToday => 'Bugün';

  @override
  String get timelineLoadError =>
      'Zaman çizelgesi okunamadı. Verileriniz silinmedi; ekranı kapatıp yeniden açmayı deneyin.';

  @override
  String get timelineActiveTitle => 'Devam eden dönemler';

  @override
  String get timelineDailyTitle => 'Günlük kayıt';

  @override
  String get timelineNoDailyLog => 'Bu gün için günlük kayıt yok.';

  @override
  String get timelineAddDailyLog => 'Günlük kayıt ekle';

  @override
  String timelineSleep(String value) {
    return 'Uyku: $value saat';
  }

  @override
  String timelineWater(String value) {
    return 'Su: $value litre';
  }

  @override
  String timelineMood(int value) {
    return 'Ruh hali: $value/5';
  }

  @override
  String timelineEnergy(int value) {
    return 'Enerji: $value/5';
  }

  @override
  String get timelineEventsTitle => 'Kayıtlar';

  @override
  String get timelineEventsEmpty => 'Bu gün için semptom ya da ilaç kaydı yok.';

  @override
  String timelineSymptomLine(String name, int severity) {
    return '$name · Şiddet $severity/10';
  }

  @override
  String timelineIntakeLine(String name) {
    return '$name alındı';
  }

  @override
  String timelineIntakeDoseLine(String name, String dose) {
    return '$name ($dose) alındı';
  }

  @override
  String timelineScheduledDose(String time) {
    return '$time dozu';
  }

  @override
  String timelineSkippedLine(String name) {
    return '$name atlandı';
  }

  @override
  String get homeAnalytics => 'Analizler';

  @override
  String get homeAnalyticsHint => 'Semptom, günlük ve ilaç eğilimleriniz';

  @override
  String get analyticsTitle => 'Analizler';

  @override
  String get analyticsTabSymptoms => 'Semptomlar';

  @override
  String get analyticsTabDaily => 'Günlük';

  @override
  String get analyticsTabEffect => 'İlaç etkisi';

  @override
  String get analyticsTabAdherence => 'Uyum';

  @override
  String analyticsDays(int n) {
    return '$n gün';
  }

  @override
  String get analyticsLoadError =>
      'Analizler okunamadı. Verileriniz silinmedi; ekranı kapatıp yeniden açmayı deneyin.';

  @override
  String get analyticsSymptomFrequency => 'Semptom sıklığı';

  @override
  String get analyticsSeverityTrend => 'Günlük ortalama şiddet';

  @override
  String get analyticsNoSymptoms => 'Bu dönemde semptom kaydı yok';

  @override
  String get analyticsNotEnoughData => 'Yeterli veri yok';

  @override
  String analyticsCount(int n) {
    return '$n kez';
  }

  @override
  String analyticsAvg(String value) {
    return 'Ort: $value';
  }

  @override
  String analyticsDailyAverages(int n) {
    return 'Ortalamalar (son $n gün)';
  }

  @override
  String get analyticsSleep => 'Uyku';

  @override
  String get analyticsWater => 'Su';

  @override
  String get analyticsMood => 'Ruh hali';

  @override
  String get analyticsEnergy => 'Enerji';

  @override
  String analyticsHours(String value) {
    return '$value saat';
  }

  @override
  String analyticsLiters(String value) {
    return '$value litre';
  }

  @override
  String analyticsOutOf5(String value) {
    return '$value / 5';
  }

  @override
  String get analyticsMoodEnergyTrend => 'Ruh hali ve enerji eğilimi';

  @override
  String get analyticsNoDaily => 'Bu dönemde günlük kayıt yok';

  @override
  String get analyticsEffectTitle => 'İlaç öncesi / sonrası şiddet';

  @override
  String get analyticsNoEffect => 'Bu dönemde ilaç-semptom eşleşmesi yok';

  @override
  String analyticsUsed(int n) {
    return '$n kez kullanıldı';
  }

  @override
  String get analyticsBefore => 'Önce';

  @override
  String get analyticsAfter => 'Sonra';

  @override
  String analyticsReliefMinutes(int n) {
    return 'Ortalama etki: $n dakika';
  }

  @override
  String get analyticsAdherenceTitle => 'Rutin ilaç uyumu';

  @override
  String get analyticsNoAdherence => 'Rutin ilaç tanımlanmamış';

  @override
  String get analyticsNoAdherenceData => 'Henüz veri yok';

  @override
  String analyticsAdherenceLine(int taken, int skipped, int unrecorded) {
    return '$taken alındı · $skipped atlandı · $unrecorded kaydedilmedi';
  }

  @override
  String analyticsExtra(int n) {
    return 'Plansız alım: $n';
  }

  @override
  String get analyticsAdherenceNote =>
      'Sayım, ilacın ilk kayıtlı dozundan başlar. Rutini sonradan değiştirdiyseniz geçmiş günler bugünkü rutininize göre hesaplanır.';

  @override
  String get analyticsDisclaimer =>
      'Bu sayılar yalnız kendi kayıtlarınızdan hesaplanır; tıbbi tavsiye değildir.';

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

  @override
  String get onboardingSkip => 'Geç';

  @override
  String get onboardingNext => 'İleri';

  @override
  String get onboardingStart => 'Başla';

  @override
  String get onboardingTitle1 => 'Sağlığınızı takip edin';

  @override
  String get onboardingBody1 =>
      'Uyku, su, ruh hali ve enerjinizi günlük kayıtla birkaç saniyede not edin.';

  @override
  String get onboardingTitle2 => 'Semptomlarınızı kaydedin';

  @override
  String get onboardingBody2 =>
      'Yaşadığınız şikâyetleri zamanı ve şiddetiyle yazın.';

  @override
  String get onboardingTitle3 => 'Dönemleri yönetin';

  @override
  String get onboardingBody3 =>
      'Bir şikâyet dönemini başlatın, seyrini izleyin ve bittiğinde kapatın.';

  @override
  String get onboardingTitle4 => 'Eğilimlerinizi görün';

  @override
  String get onboardingBody4 =>
      'Kayıtlarınızdan hesaplanan grafikleri ve ilaç etkisini inceleyin. Tıbbi tavsiye değildir.';

  @override
  String get homeSettings => 'Ayarlar';

  @override
  String get settingsTitle => 'Ayarlar';

  @override
  String get settingsDataSection => 'Veriler';

  @override
  String get settingsWipeTitle => 'Tüm verimi sil';

  @override
  String get settingsWipeHint =>
      'Tüm kayıtlarınızı bu telefondan kalıcı olarak siler; geri alınamaz.';

  @override
  String get settingsProfileTitle => 'Profil';

  @override
  String get settingsProfileEmpty => 'Adınızı ve temel bilgilerinizi ekleyin';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileIntro =>
      'Bu bilgiler yalnızca bu telefonda, şifreli veritabanınızda durur. Hepsi isteğe bağlıdır.';

  @override
  String get profileFirstName => 'Ad';

  @override
  String get profileLastName => 'Soyad';

  @override
  String get profileBirthDate => 'Doğum tarihi';

  @override
  String get profileBirthDateNone => 'Seçilmedi';

  @override
  String get profileBirthDateClear => 'Tarihi temizle';

  @override
  String get profileGender => 'Cinsiyet';

  @override
  String get profileGenderNone => 'Belirtmek istemiyorum';

  @override
  String get profileGenderFemale => 'Kadın';

  @override
  String get profileGenderMale => 'Erkek';

  @override
  String get profileGenderOther => 'Diğer';

  @override
  String get profilePhotoAdd => 'Fotoğraf ekle';

  @override
  String get profilePhotoChange => 'Fotoğrafı değiştir';

  @override
  String get profilePhotoGallery => 'Galeriden seç';

  @override
  String get profilePhotoCamera => 'Kamerayla çek';

  @override
  String get profilePhotoRemove => 'Fotoğrafı kaldır';

  @override
  String get profilePhotoFailed => 'Fotoğraf alınamadı.';

  @override
  String get profileSave => 'Kaydet';

  @override
  String get profileSaved => 'Profil kaydedildi';

  @override
  String get profileSaveFailed => 'Profil kaydedilemedi.';

  @override
  String get profileLoadFailed => 'Profil okunamadı.';

  @override
  String get profileRetry => 'Yeniden dene';

  @override
  String get settingsBackupSection => 'Yedek';

  @override
  String get settingsBackupExportTitle => 'Yedek al';

  @override
  String get settingsBackupExportHint =>
      'Verilerinizi parolayla şifreli bir dosyaya kaydedin';

  @override
  String get backupTitle => 'Yedek al';

  @override
  String get backupIntro =>
      'Tüm kayıtlarınız, belirleyeceğiniz parolayla şifrelenmiş tek bir dosyaya yazılır. Dosyayı telefonunuzda, bulut depolamanızda ya da bir SD kartta saklayabilirsiniz.';

  @override
  String get backupWarning =>
      'Bu parolayı unutursanız yedeğiniz açılamaz; kurtarma yolu yoktur. Parolayı güvenli bir yere not edin.';

  @override
  String get backupPassphrase => 'Yedek parolası';

  @override
  String get backupPassphraseConfirm => 'Parolayı tekrar yazın';

  @override
  String get backupShowPassphrase => 'Parolayı göster';

  @override
  String get backupHidePassphrase => 'Parolayı gizle';

  @override
  String backupTooShort(int n) {
    return 'Parola en az $n karakter olmalı';
  }

  @override
  String get backupMismatch => 'Parolalar aynı değil';

  @override
  String get backupAction => 'Yedek al';

  @override
  String get backupWorking => 'Yedek hazırlanıyor…';

  @override
  String get backupDone => 'Yedek kaydedildi.';

  @override
  String get backupCancelled => 'Konum seçilmedi; yedek alınmadı.';

  @override
  String get backupFailed =>
      'Yedek alınamadı. Verileriniz silinmedi; tekrar deneyin.';

  @override
  String get commonOk => 'Tamam';

  @override
  String get settingsRestoreTitle => 'Yedekten geri yükle';

  @override
  String get settingsRestoreHint =>
      'Daha önce aldığınız yedeği bu telefona yükleyin';

  @override
  String get restoreTitle => 'Yedekten geri yükle';

  @override
  String get restoreIntro =>
      'Daha önce aldığınız yedek dosyasını seçin ve yedeği alırken belirlediğiniz parolayı yazın.';

  @override
  String get restoreWarning =>
      'Geri yükleme, telefondaki mevcut tüm kayıtlarınızın yerine yedektekileri koyar ve geri alınamaz. Önce güncel bir yedek almanız önerilir.';

  @override
  String get restorePick => 'Yedek dosyası seç';

  @override
  String get restoreNoFile => 'Henüz dosya seçilmedi';

  @override
  String get restorePassphrase => 'Yedek parolası';

  @override
  String get restoreAction => 'Geri yükle';

  @override
  String get restoreWorking => 'Geri yükleniyor…';

  @override
  String get restoreNeedFile => 'Önce bir yedek dosyası seçin';

  @override
  String get restoreNeedPassphrase => 'Yedek parolasını yazın';

  @override
  String get restoreConfirmTitle => 'Geri yüklensin mi?';

  @override
  String get restoreConfirmBody =>
      'Telefondaki mevcut tüm kayıtlarınız silinir ve yedektekilerle değiştirilir. Bu işlem geri alınamaz.';

  @override
  String get restoreDoneTitle => 'Geri yüklendi';

  @override
  String get restoreDoneBody => 'Verileriniz yedekten geri yüklendi.';

  @override
  String get restoreErrWrong =>
      'Parola yanlış ya da dosya bozuk. Mevcut verileriniz değişmedi.';

  @override
  String get restoreErrNewer =>
      'Bu yedek uygulamanın daha yeni bir sürümüyle alınmış. Önce uygulamayı güncelleyin. Mevcut verileriniz değişmedi.';

  @override
  String get restoreErrNotBackup =>
      'Bu dosya bir Vitapuls yedeği değil. Mevcut verileriniz değişmedi.';

  @override
  String get restoreErrIo =>
      'Geri yüklenemedi. Mevcut verileriniz değişmedi; tekrar deneyin.';
}
