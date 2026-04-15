import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../../features/notifications/providers/notifications_provider.dart';
import '../../features/settings/providers/settings_provider.dart';

/// Background message handler — must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[Push] Background message: ${message.messageId}');
}

class PushNotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final Ref _ref;

  String? _deviceToken;

  PushNotificationService(this._ref);

  String? get deviceToken => _deviceToken;

  ApiClient get _api => _ref.read(apiClientProvider);
  SettingsState get _settings => _ref.read(settingsProvider);

  Future<void> initialize() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('[Push] Permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        debugPrint('[Push] Permission denied');
        return;
      }

      String? apnsToken;
      for (var i = 0; i < 10; i++) {
        apnsToken = await _messaging.getAPNSToken();
        if (apnsToken != null) break;
        await Future.delayed(const Duration(seconds: 1));
      }
      debugPrint('[Push] APNs token: ${apnsToken != null ? "obtained" : "null after retries"}');

      if (apnsToken == null) {
        debugPrint('[Push] APNs token unavailable, push registration skipped');
        return;
      }

      _deviceToken = apnsToken;
      debugPrint('[Push] Registering APNs token with server...');
      await _registerDevice(apnsToken);

      FirebaseMessaging.onMessage.listen((message) {
        debugPrint('[Push] Foreground message: ${message.notification?.title}');
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        debugPrint('[Push] Opened from background: ${message.data}');
      });
    } catch (e) {
      debugPrint('[Push] Initialization failed: $e');
    }
  }

  /// Re-push the current DND/server settings for the cached device
  /// token. Falls back to [initialize] on the first run when no token
  /// has been fetched yet. Used by the settings listener so changing
  /// DND bounds reaches the server without re-running Firebase's
  /// permission + token fetch on every Done tap.
  Future<void> updateRegistration() async {
    final token = _deviceToken;
    if (token == null) {
      await initialize();
      return;
    }
    await _registerDevice(token);
  }

  /// Unregister the cached device token from the current server. Safe
  /// to call when no token exists (no-op). Used during sign-out before
  /// the API key is cleared so the request still authenticates.
  Future<void> unregister() async {
    final token = _deviceToken;
    if (token == null) return;
    try {
      await _api.unregisterDevice(token);
      debugPrint('[Push] Device unregistered');
    } catch (e) {
      debugPrint('[Push] Device unregister failed: $e');
    }
  }

  Future<void> _registerDevice(String token) async {
    try {
      await _api.registerDevice(
        token: token,
        platform: 'ios',
        dndEnabled: _settings.dndEnabled,
        dndStart: _settings.dndStartWire,
        dndEnd: _settings.dndEndWire,
        dndTzOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
      );
      debugPrint('[Push] Device registered');
    } catch (e) {
      debugPrint('[Push] Device registration failed: $e');
    }
  }
}
