// Dönem kartlarındaki zaman ve süre biçimleri.

import 'package:intl/intl.dart';

import '../../data/database/enums.dart';
import '../../data/repositories/support.dart';
import '../../domain/local_day.dart';
import '../../l10n/app_localizations.dart';
import 'episode_overview.dart';

/// Bir anı, kaydın kendi UTC farkıyla (kayıt anındaki cihaz saatiyle) yazar:
/// [now]'ın yerel günündeyse yalnız saat ("10:58"), başka güne aitse tarihli
/// ("5 Kas 10:58"). Saat dilimi değişse de eski kayıtların saati kaymaz.
String formatEpisodeMoment(
  DateTime instant,
  int offsetMinutes,
  DateTime now,
  String locale,
) {
  final wallClock = instant.toUtc().add(Duration(minutes: offsetMinutes));
  final sameDay =
      formatDay(wallClock.year, wallClock.month, wallClock.day) == dayKey(now);
  return sameDay
      ? DateFormat.Hm(locale).format(wallClock)
      : DateFormat('d MMM HH:mm', locale).format(wallClock);
}

/// Doz biriminin Türkçe adı ("damla", "kapsül"...).
String doseUnitLabel(DoseUnit unit, AppLocalizations l10n) => switch (unit) {
      DoseUnit.tablet => l10n.doseUnitTablet,
      DoseUnit.mg => l10n.doseUnitMg,
      DoseUnit.ml => l10n.doseUnitMl,
      DoseUnit.drop => l10n.doseUnitDrop,
      DoseUnit.capsule => l10n.doseUnitCapsule,
    };

/// Kartta bir ilaç alımı: "İlaç: Parol (1,5 damla) · 08:30"; doz yoksa
/// "İlaç: Parol · 08:30". Zaman [formatEpisodeMoment] gibi kaydın kendi UTC
/// farkıyla yazılır; doz yerel ondalık ayracıyla ("1,5", tam sayıysa "2").
String formatEpisodeIntake(
  EpisodeMedicationIntake intake,
  DateTime now,
  AppLocalizations l10n,
  String locale,
) {
  final time =
      formatEpisodeMoment(intake.takenAt, intake.utcOffsetMinutes, now, locale);
  final amount = intake.doseAmount;
  if (amount == null) {
    return l10n.episodeIntakeNoDose(intake.medicationName, time);
  }
  final dose =
      '${NumberFormat.decimalPattern(locale).format(amount)} ${doseUnitLabel(intake.doseUnit, l10n)}';
  return l10n.episodeIntakeWithDose(intake.medicationName, dose, time);
}

/// "2 saat 5 dakika" ya da (bir saatten kısaysa) "45 dakika".
String formatEpisodeDuration(int minutes, AppLocalizations l10n) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return hours > 0
      ? l10n.episodeDurationHoursMinutes(hours, rest)
      : l10n.episodeDurationMinutes(rest);
}
