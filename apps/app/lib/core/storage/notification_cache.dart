import 'dart:convert';

import 'package:dingit_shared/dingit_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationCache {
  static const _notificationsKey = 'cached_notifications';
  static const _historyKey = 'cached_history';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _instance async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<List<NotificationModel>> loadNotifications() async {
    try {
      final prefs = await _instance;
      final json = prefs.getString(_notificationsKey);
      if (json == null) return [];

      final list = jsonDecode(json) as List;
      return list
          .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[Cache] load notifications failed: $e');
      return [];
    }
  }

  Future<void> saveNotifications(List<NotificationModel> items) async {
    try {
      final prefs = await _instance;
      final json = jsonEncode(items.map((e) => e.toJson()).toList());
      await prefs.setString(_notificationsKey, json);
    } catch (e) {
      debugPrint('[Cache] save notifications failed: $e');
    }
  }

  Future<List<NotificationModel>> loadHistory() async {
    try {
      final prefs = await _instance;
      final json = prefs.getString(_historyKey);
      if (json == null) return [];

      final list = jsonDecode(json) as List;
      return list
          .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[Cache] load history failed: $e');
      return [];
    }
  }

  Future<void> saveHistory(List<NotificationModel> items) async {
    try {
      final prefs = await _instance;
      final json = jsonEncode(items.map((e) => e.toJson()).toList());
      await prefs.setString(_historyKey, json);
    } catch (e) {
      debugPrint('[Cache] save history failed: $e');
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await _instance;
      await prefs.remove(_notificationsKey);
      await prefs.remove(_historyKey);
    } catch (e) {
      debugPrint('[Cache] clear failed: $e');
    }
  }
}
