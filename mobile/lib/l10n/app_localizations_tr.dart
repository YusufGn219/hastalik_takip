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
  String get dbOpenErrorTitle => 'Veritabanı açılamadı';

  @override
  String get dbOpenErrorBody =>
      'Şifreli veritabanı açılamadı. Uygulamayı tamamen kapatıp yeniden açmayı deneyin.';
}
