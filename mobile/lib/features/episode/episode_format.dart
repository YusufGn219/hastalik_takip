// Dönem kartlarındaki zaman ve süre biçimleri.

import 'package:intl/intl.dart';

import '../../data/repositories/support.dart';
import '../../domain/local_day.dart';
import '../../l10n/app_localizations.dart';

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

/// "2 saat 5 dakika" ya da (bir saatten kısaysa) "45 dakika".
String formatEpisodeDuration(int minutes, AppLocalizations l10n) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return hours > 0
      ? l10n.episodeDurationHoursMinutes(hours, rest)
      : l10n.episodeDurationMinutes(rest);
}
