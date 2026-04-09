import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridge to native iOS badge control.
///
/// On Android this is a no-op: Android badge APIs are vendor-specific
/// (Samsung/Xiaomi/Huawei each differ) and not supported yet.
class BadgeService {
  static const _channel = MethodChannel('com.dingit.badge');

  static Future<void> setCount(int count) async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod('setBadgeCount', {'count': count});
    } catch (e) {
      debugPrint('[Badge] setCount($count) failed: $e');
    }
  }

  static Future<void> clear() => setCount(0);
}
