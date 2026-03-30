import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:notify_shared/notify_shared.dart';

class CallbackService {
  final http.Client _httpClient;

  CallbackService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  Future<bool> deliver({
    required NotificationModel notification,
    required ActionResponse response,
  }) async {
    final callbackUrl = notification.callbackUrl;
    if (callbackUrl == null || callbackUrl.isEmpty) return false;

    final payload = {
      'notification_id': notification.id,
      'action': response.action,
      'timestamp': response.timestamp.toIso8601String(),
      'metadata': notification.metadata,
      'source': response.source,
    };

    // Retry with exponential backoff: 1s, 3s, 9s
    const maxRetries = 3;
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final res = await _httpClient.post(
          Uri.parse(callbackUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );
        if (res.statusCode >= 200 && res.statusCode < 300) {
          print('[Callback] Delivered to $callbackUrl (${res.statusCode})');
          return true;
        }
        print('[Callback] Failed attempt ${attempt + 1}: ${res.statusCode}');
      } catch (e) {
        print('[Callback] Error attempt ${attempt + 1}: $e');
      }

      if (attempt < maxRetries - 1) {
        final delay = Duration(seconds: _pow3(attempt + 1));
        await Future.delayed(delay);
      }
    }

    print('[Callback] All retries exhausted for $callbackUrl');
    return false;
  }

  int _pow3(int n) {
    var result = 1;
    for (var i = 0; i < n; i++) {
      result *= 3;
    }
    return result;
  }

  void dispose() => _httpClient.close();
}
