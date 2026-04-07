import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../api/api_client.dart';

/// Background message handler — must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[Push] Background message: ${message.messageId}');
}

class PushNotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final ApiClient _api;

  String? _deviceToken;

  PushNotificationService(this._api);

  String? get deviceToken => _deviceToken;

  Future<void> initialize() async {
    // Request permission
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

    // Wait for APNs token (iOS)
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

    // Register APNs token directly with server (no FCM needed)
    _deviceToken = apnsToken;
    debugPrint('[Push] Registering APNs token with server...');
    await _registerDevice(apnsToken);

    // Foreground message handling (for FCM messages if VPN is on)
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('[Push] Foreground message: ${message.notification?.title}');
    });

    // When user taps notification (app was in background)
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('[Push] Opened from background: ${message.data}');
    });
  }

  Future<void> _registerDevice(String token) async {
    try {
      await _api.registerDevice(token: token, platform: 'ios');
      debugPrint('[Push] Device registered');
    } catch (e) {
      debugPrint('[Push] Device registration failed: $e');
    }
  }
}
