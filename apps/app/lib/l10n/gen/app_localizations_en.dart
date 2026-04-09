// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Dingit';

  @override
  String get notificationConnectionConnected => 'Updated now';

  @override
  String get notificationConnectionConnecting => 'Connecting...';

  @override
  String get notificationConnectionDisconnected => 'Disconnected';

  @override
  String get notificationDismissedPill => 'Dismissed';

  @override
  String get notificationUndoAction => 'Undo';

  @override
  String get notificationEmptyTitle => 'All clear';

  @override
  String get notificationEmptyBody => 'You\'re all caught up';

  @override
  String get notificationEmptyViewHistory => 'View history';

  @override
  String get actionBarDismiss => 'Dismiss';

  @override
  String get actionBarNext => 'Next';

  @override
  String get historyTitle => 'History';

  @override
  String get historyFilterAll => 'All';

  @override
  String get historyFilterActioned => 'Actioned';

  @override
  String get historyFilterDismissed => 'Dismissed';

  @override
  String get historyFilterExpired => 'Expired';

  @override
  String get historyLoadFailed => 'Failed to load';

  @override
  String get historyRetry => 'Tap to retry';

  @override
  String get historyEmpty => 'No history yet';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionServer => 'SERVER';

  @override
  String get settingsServerAddress => 'Address';

  @override
  String get settingsServerPlaceholder => 'http://localhost:8080';

  @override
  String get settingsServerTestConnection => 'Test Connection';

  @override
  String get settingsServerConnected => 'Connected';

  @override
  String get settingsServerFailed => 'Failed';

  @override
  String get settingsSectionAuth => 'AUTHENTICATION';

  @override
  String get settingsAuthApiKey => 'API Key';

  @override
  String get settingsAuthApiKeyPlaceholder => 'Enter your API key';

  @override
  String get settingsAuthApiKeyHint =>
      'Your API key is encrypted and stored securely on this device.';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsAppearanceAuto => 'Auto';

  @override
  String get settingsAppearanceLight => 'Light';

  @override
  String get settingsAppearanceDark => 'Dark';

  @override
  String get settingsSectionLanguage => 'Language';

  @override
  String get settingsLanguageAuto => 'Auto';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageChinese => '简体中文';

  @override
  String get settingsSave => 'Save Settings';

  @override
  String settingsSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get detailNotFound => 'Notification not found';

  @override
  String get detailMetadataSection => 'METADATA';

  @override
  String get detailActionTaken => 'Action taken';

  @override
  String detailActionedAt(String date) {
    return 'Actioned $date';
  }

  @override
  String get detailStatusPending => 'Pending';

  @override
  String get detailStatusActioned => 'Actioned';

  @override
  String get detailStatusDismissed => 'Dismissed';

  @override
  String get detailStatusExpired => 'Expired';

  @override
  String get detailPriorityUrgent => 'Urgent';

  @override
  String get detailPriorityHigh => 'High';

  @override
  String get detailPriorityLow => 'Low';

  @override
  String get detailPriorityNormal => 'Normal';
}
