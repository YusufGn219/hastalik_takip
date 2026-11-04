import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

/// `context.l10n` kısayolu (yeni ekranlar için).
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
