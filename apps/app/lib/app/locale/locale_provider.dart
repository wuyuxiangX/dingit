import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _localeKey = 'app_locale';

/// User-selected locale override, persisted to SharedPreferences.
///
/// State semantics:
///   * `null`  → follow system (MaterialApp falls back to the platform locale
///               after running it through `localeResolutionCallback`)
///   * `en`/`zh` → force that locale, regardless of system settings
///
/// Watch this in `DingitApp` so MaterialApp rebuilds whenever the user
/// changes the locale via the Settings page. The nullable state mirrors
/// `ThemeModeNotifier`'s Auto/Light/Dark shape on purpose — the settings UI
/// renders both the same way.
final localeProvider =
    NotifierProvider<LocaleNotifier, Locale?>(LocaleNotifier.new);

class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = _parse(prefs.getString(_localeKey));
  }

  Future<void> set(Locale? locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_localeKey);
    } else {
      await prefs.setString(_localeKey, locale.languageCode);
    }
  }

  static Locale? _parse(String? raw) {
    switch (raw) {
      case 'en':
        return const Locale('en');
      case 'zh':
        return const Locale('zh');
      default:
        return null;
    }
  }
}
