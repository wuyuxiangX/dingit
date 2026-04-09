import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// Application title displayed in the task switcher and notification page header
  ///
  /// In en, this message translates to:
  /// **'Dingit'**
  String get appTitle;

  /// No description provided for @notificationConnectionConnected.
  ///
  /// In en, this message translates to:
  /// **'Updated now'**
  String get notificationConnectionConnected;

  /// No description provided for @notificationConnectionConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get notificationConnectionConnecting;

  /// No description provided for @notificationConnectionDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get notificationConnectionDisconnected;

  /// Message shown in the undo pill after a notification is swiped away
  ///
  /// In en, this message translates to:
  /// **'Dismissed'**
  String get notificationDismissedPill;

  /// No description provided for @notificationUndoAction.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get notificationUndoAction;

  /// No description provided for @notificationEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'All clear'**
  String get notificationEmptyTitle;

  /// No description provided for @notificationEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up'**
  String get notificationEmptyBody;

  /// No description provided for @notificationEmptyViewHistory.
  ///
  /// In en, this message translates to:
  /// **'View history'**
  String get notificationEmptyViewHistory;

  /// No description provided for @actionBarDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get actionBarDismiss;

  /// No description provided for @actionBarNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get actionBarNext;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTitle;

  /// No description provided for @historyFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get historyFilterAll;

  /// No description provided for @historyFilterActioned.
  ///
  /// In en, this message translates to:
  /// **'Actioned'**
  String get historyFilterActioned;

  /// No description provided for @historyFilterDismissed.
  ///
  /// In en, this message translates to:
  /// **'Dismissed'**
  String get historyFilterDismissed;

  /// No description provided for @historyFilterExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get historyFilterExpired;

  /// No description provided for @historyLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load'**
  String get historyLoadFailed;

  /// No description provided for @historyRetry.
  ///
  /// In en, this message translates to:
  /// **'Tap to retry'**
  String get historyRetry;

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No history yet'**
  String get historyEmpty;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// AppBar trailing action on Settings that saves and closes the page
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get settingsDone;

  /// Generic cancel button used in dialogs
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @settingsSectionServer.
  ///
  /// In en, this message translates to:
  /// **'SERVER'**
  String get settingsSectionServer;

  /// No description provided for @settingsServerAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get settingsServerAddress;

  /// No description provided for @settingsServerPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'http://localhost:8080'**
  String get settingsServerPlaceholder;

  /// No description provided for @settingsServerTestConnection.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get settingsServerTestConnection;

  /// No description provided for @settingsServerConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get settingsServerConnected;

  /// No description provided for @settingsServerFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get settingsServerFailed;

  /// No description provided for @settingsSectionAuth.
  ///
  /// In en, this message translates to:
  /// **'AUTHENTICATION'**
  String get settingsSectionAuth;

  /// No description provided for @settingsAuthApiKey.
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get settingsAuthApiKey;

  /// No description provided for @settingsAuthApiKeyPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter your API key'**
  String get settingsAuthApiKeyPlaceholder;

  /// No description provided for @settingsAuthApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Your API key is encrypted and stored securely on this device.'**
  String get settingsAuthApiKeyHint;

  /// No description provided for @settingsSectionPreferences.
  ///
  /// In en, this message translates to:
  /// **'PREFERENCES'**
  String get settingsSectionPreferences;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsSectionAppearance;

  /// No description provided for @settingsAppearanceAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get settingsAppearanceAuto;

  /// No description provided for @settingsAppearanceLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsAppearanceLight;

  /// No description provided for @settingsAppearanceDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsAppearanceDark;

  /// No description provided for @settingsSectionLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsSectionLanguage;

  /// No description provided for @settingsLanguageAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get settingsLanguageAuto;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageChinese.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get settingsLanguageChinese;

  /// No description provided for @settingsSectionNotifications.
  ///
  /// In en, this message translates to:
  /// **'NOTIFICATIONS'**
  String get settingsSectionNotifications;

  /// No description provided for @settingsNotificationsClearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get settingsNotificationsClearHistory;

  /// No description provided for @settingsNotificationsResetBadge.
  ///
  /// In en, this message translates to:
  /// **'Reset Badge'**
  String get settingsNotificationsResetBadge;

  /// No description provided for @settingsClearHistoryDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear History?'**
  String get settingsClearHistoryDialogTitle;

  /// No description provided for @settingsClearHistoryDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'This will remove all notification history cached on this device. This cannot be undone.'**
  String get settingsClearHistoryDialogMessage;

  /// No description provided for @settingsClearHistoryDialogConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get settingsClearHistoryDialogConfirm;

  /// No description provided for @settingsClearHistoryDone.
  ///
  /// In en, this message translates to:
  /// **'History cleared'**
  String get settingsClearHistoryDone;

  /// No description provided for @settingsResetBadgeDone.
  ///
  /// In en, this message translates to:
  /// **'Badge reset'**
  String get settingsResetBadgeDone;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'ABOUT'**
  String get settingsSectionAbout;

  /// No description provided for @settingsAboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsAboutVersion;

  /// No description provided for @settingsAboutSourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source Code'**
  String get settingsAboutSourceCode;

  /// No description provided for @settingsAboutLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open Source Licenses'**
  String get settingsAboutLicenses;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get settingsSignOut;

  /// No description provided for @settingsSignOutDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign Out?'**
  String get settingsSignOutDialogTitle;

  /// No description provided for @settingsSignOutDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'This will clear your server URL and API key and disconnect. You will need to re-enter them to reconnect.'**
  String get settingsSignOutDialogMessage;

  /// No description provided for @settingsSignOutDialogConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get settingsSignOutDialogConfirm;

  /// No description provided for @settingsSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get settingsSignedOut;

  /// Snack bar shown when saving settings throws
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String settingsSaveFailed(String error);

  /// No description provided for @detailNotFound.
  ///
  /// In en, this message translates to:
  /// **'Notification not found'**
  String get detailNotFound;

  /// No description provided for @detailMetadataSection.
  ///
  /// In en, this message translates to:
  /// **'METADATA'**
  String get detailMetadataSection;

  /// No description provided for @detailActionTaken.
  ///
  /// In en, this message translates to:
  /// **'Action taken'**
  String get detailActionTaken;

  /// Timestamp row below the title showing when the user responded
  ///
  /// In en, this message translates to:
  /// **'Actioned {date}'**
  String detailActionedAt(String date);

  /// No description provided for @detailStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get detailStatusPending;

  /// No description provided for @detailStatusActioned.
  ///
  /// In en, this message translates to:
  /// **'Actioned'**
  String get detailStatusActioned;

  /// No description provided for @detailStatusDismissed.
  ///
  /// In en, this message translates to:
  /// **'Dismissed'**
  String get detailStatusDismissed;

  /// No description provided for @detailStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get detailStatusExpired;

  /// No description provided for @detailPriorityUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get detailPriorityUrgent;

  /// No description provided for @detailPriorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get detailPriorityHigh;

  /// No description provided for @detailPriorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get detailPriorityLow;

  /// No description provided for @detailPriorityNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get detailPriorityNormal;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
