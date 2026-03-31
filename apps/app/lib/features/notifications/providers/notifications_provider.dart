import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dingit_shared/dingit_shared.dart';

import '../../../core/api/api_client.dart';
import '../../../core/env/env_config.dart';
import '../../../core/websocket/ws_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(baseUrl: EnvConfig.apiUrl, apiKey: EnvConfig.apiKey);
});

final wsClientProvider = Provider<WsClient>((ref) {
  final notifier = ref.read(notificationsProvider.notifier);
  final client = WsClient(
    url: EnvConfig.wsUrl,
    onMessage: notifier.handleWsMessage,
  );
  ref.onDispose(() => client.disconnect());
  return client;
});

final connectionStateProvider = Provider<ValueNotifier<WsConnectionState>>((ref) {
  return ref.watch(wsClientProvider).connectionState;
});

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, List<NotificationModel>>(
  NotificationsNotifier.new,
);

class NotificationsNotifier extends Notifier<List<NotificationModel>> {
  @override
  List<NotificationModel> build() => [];

  void handleWsMessage(WsMessage message) {
    switch (message) {
      case WsSyncFull(:final notifications):
        state = notifications;
      case WsNotificationNew(:final notification):
        state = [notification, ...state];
      case WsNotificationUpdated(:final notification):
        state = state.map((n) {
          return n.id == notification.id ? notification : n;
        }).toList();
      default:
        break;
    }
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
  }

  void dismissNotification(String id) {
    // Optimistically update local state
    state = state.map((n) {
      if (n.id == id) {
        return n.copyWith(status: NotificationStatus.dismissed);
      }
      return n;
    }).toList();

    // Sync to server via PATCH API
    final apiClient = ref.read(apiClientProvider);
    apiClient.patchNotificationStatus(id, 'dismissed');
  }

  List<NotificationModel> get pendingNotifications =>
      state.where((n) => n.status == NotificationStatus.pending).toList();
}

final pendingNotificationsProvider = Provider<List<NotificationModel>>((ref) {
  final all = ref.watch(notificationsProvider);
  return all.where((n) => n.status == NotificationStatus.pending).toList();
});
