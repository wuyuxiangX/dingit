import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dingit_shared/dingit_shared.dart';

import '../../../core/api/api_client.dart';
import '../../../core/push/push_notification_service.dart';
import '../../../core/storage/notification_cache.dart';
import '../../../core/websocket/ws_client.dart';
import '../../settings/providers/settings_provider.dart';

final notificationCacheProvider = Provider<NotificationCache>((ref) {
  return NotificationCache();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final settings = ref.watch(settingsProvider);
  return ApiClient(baseUrl: settings.serverUrl, apiKey: settings.apiKey);
});

final wsClientProvider = Provider<WsClient>((ref) {
  final settings = ref.watch(settingsProvider);
  final notifier = ref.read(notificationsProvider.notifier);
  final client = WsClient(
    url: settings.wsUrl,
    apiKey: settings.apiKey,
    onMessage: notifier.handleWsMessage,
    lastSyncAt: notifier._lastSyncAt,
  );
  ref.onDispose(() => client.disconnect());
  return client;
});

final connectionStateProvider = Provider<ValueNotifier<WsConnectionState>>((ref) {
  return ref.watch(wsClientProvider).connectionState;
});

final pushServiceProvider = Provider<PushNotificationService>((ref) {
  final api = ref.watch(apiClientProvider);
  return PushNotificationService(api);
});

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, List<NotificationModel>>(
  NotificationsNotifier.new,
);

class NotificationsNotifier extends Notifier<List<NotificationModel>> {
  NotificationCache get _cache => ref.read(notificationCacheProvider);
  DateTime? _lastSyncAt;
  bool _mounted = true;

  @override
  List<NotificationModel> build() {
    ref.onDispose(() {
      _mounted = false;
      _debounce?.cancel();
    });
    _loadFromCache();
    return [];
  }

  Future<void> _loadFromCache() async {
    final results = await Future.wait([
      _cache.loadNotifications(),
      _cache.loadLastSyncAt(),
    ]);
    if (!_mounted) return;
    final cached = results[0] as List<NotificationModel>;
    _lastSyncAt = results[1] as DateTime?;

    if (cached.isNotEmpty && state.isEmpty) {
      state = cached;
    }
  }

  Timer? _debounce;

  void _persistCache() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _cache.saveNotifications(state);
    });
  }

  void handleWsMessage(WsMessage message) {
    if (!_mounted) return;
    switch (message) {
      case WsSyncFull(:final notifications):
        if (_lastSyncAt != null && state.isNotEmpty) {
          // Reconnect with since: merge new data into existing state
          final existingIds = {for (final n in state) n.id};
          final merged = [...state];
          for (final n in notifications) {
            if (existingIds.contains(n.id)) {
              // Update existing notification with latest state
              final idx = merged.indexWhere((e) => e.id == n.id);
              if (idx >= 0) merged[idx] = n;
            } else {
              merged.add(n);
            }
          }
          merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          state = merged;
        } else {
          // First connect: replace entirely
          state = notifications;
        }
        _lastSyncAt = DateTime.now().toUtc();
        _cache.saveLastSyncAt(_lastSyncAt!);
      case WsNotificationNew(:final notification):
        state = [notification, ...state];
      case WsNotificationUpdated(:final notification):
        state = state.map((n) {
          return n.id == notification.id ? notification : n;
        }).toList();
      default:
        return; // skip cache write for unknown messages
    }
    _persistCache();
  }

  void respondToNotification(String id, String actionValue) {
    final wsClient = ref.read(wsClientProvider);
    final response = ActionResponse(
      notificationId: id,
      action: actionValue,
      timestamp: DateTime.now().toUtc(),
    );

    wsClient.send(WsMessage.actionResponse(response: response));

    // Optimistically update local state
    state = state.map((n) {
      if (n.id == id) {
        return n.copyWith(
          status: NotificationStatus.actioned,
          actionedValue: actionValue,
          actionedAt: DateTime.now().toUtc(),
        );
      }
      return n;
    }).toList();
    _persistCache();
  }

  void dismissNotification(String id) {
    final previous = state;
    state = state.where((n) => n.id != id).toList();
    _persistCache();
    _dismissOnServer(id, previous);
  }

  Future<void> _dismissOnServer(String id, List<NotificationModel> previous) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.patchNotificationStatus(id, 'dismissed');
    } catch (e) {
      debugPrint('[Notifications] Dismiss sync failed: $e');
      if (!_mounted) return;
      state = previous;
      _persistCache();
    }
  }
}

final pendingNotificationsProvider = Provider<List<NotificationModel>>((ref) {
  final all = ref.watch(notificationsProvider);
  return all.where((n) => n.status == NotificationStatus.pending).toList();
});
