import 'package:flutter/widgets.dart';

import '../../l10n/gen/app_localizations.dart';

/// Shortcut for `AppLocalizations.of(context)`.
///
/// Usage:
/// ```dart
/// Text(context.l10n.settingsTitle)
/// ```
extension DingitL10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
