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
  String get settingsDone => 'Done';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get settingsSectionServer => 'SERVER';

  @override
  String get settingsServerAddress => 'Address';

  @override
  String get settingsServerPlaceholder => 'http://localhost:8080';

  @override
  String get settingsServerTestConnection => 'Test Connection';

  @override
  String get settingsServerTesting => 'Testing…';

  @override
  String get settingsServerConnected => 'Connected';

  @override
  String get settingsServerFailed => 'Failed';

  @override
  String get settingsServerUnreachable =>
      'Cannot reach this server. Check the URL and API key.';

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
  String get settingsSectionPreferences => 'PREFERENCES';

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
  String get settingsSectionNotifications => 'NOTIFICATIONS';

  @override
  String get settingsNotificationsClearHistory => 'Clear History';

  @override
  String get settingsNotificationsResetBadge => 'Reset Badge';

  @override
  String get settingsClearHistoryDialogTitle => 'Clear History?';

  @override
  String get settingsClearHistoryDialogMessage =>
      'This will remove all notification history cached on this device. This cannot be undone.';

  @override
  String get settingsClearHistoryDialogConfirm => 'Clear';

  @override
  String get settingsClearHistoryDone => 'History cleared';

  @override
  String get settingsResetBadgeDone => 'Badge reset';

  @override
  String get settingsSectionAbout => 'ABOUT';

  @override
  String get settingsAboutVersion => 'Version';

  @override
  String get settingsAboutSourceCode => 'Source Code';

  @override
  String get settingsAboutLicenses => 'Open Source Licenses';

  @override
  String get settingsSignOut => 'Sign Out';

  @override
  String get settingsSignOutDialogTitle => 'Sign Out?';

  @override
  String get settingsSignOutDialogMessage =>
      'This will clear your server URL and API key and disconnect. You will need to re-enter them to reconnect.';

  @override
  String get settingsSignOutDialogConfirm => 'Sign Out';

  @override
  String get settingsSignedOut => 'Signed out';

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
