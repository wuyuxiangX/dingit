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

    // Get APNs token first (iOS)
    final apnsToken = await _messaging.getAPNSToken();
    debugPrint('[Push] APNs token: ${apnsToken != null ? "obtained" : "null"}');

    // Get FCM token
    _deviceToken = await _messaging.getToken();
    debugPrint('[Push] FCM token: ${_deviceToken?.substring(0, 20)}...');

    if (_deviceToken != null) {
      await _registerDevice(_deviceToken!);
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('[Push] Token refreshed');
      _deviceToken = newToken;
      _registerDevice(newToken);
    });

    // Foreground message handling
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('[Push] Foreground message: ${message.notification?.title}');
      // Foreground notifications are already handled via WebSocket
      // No need to show local notification since app is in foreground
    });

    // When user taps notification (app was in background)
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('[Push] Opened from background: ${message.data}');
      // TODO: Navigate to notification detail page
    });

    // Check if app was opened from a terminated state via notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[Push] Opened from terminated: ${initialMessage.data}');
      // TODO: Navigate to notification detail page
    }
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
