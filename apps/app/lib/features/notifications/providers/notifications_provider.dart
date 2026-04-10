import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dingit_shared/dingit_shared.dart';

import '../../../core/api/api_client.dart';
import '../../../core/push/badge_service.dart';
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
  // Auto-connect once settings have been hydrated from storage AND the
  // user has configured a server URL. Without the serverUrl guard the
  // client would spin in a reconnect loop against an empty URL after
  // Sign Out, or on first launch before the user has entered a URL.
  if (settings.isLoaded && settings.serverUrl.isNotEmpty) {
    client.connect();
  }
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

  // Delayed-commit state: a dismiss is stored locally as
  // NotificationStatus.dismissed immediately, then actually PATCHed to the
  // server after this many seconds. During the window, the user can undo it.
  static const _commitDelay = Duration(seconds: 3);

  final Map<String, Timer> _pendingCommits = {};
  final Map<String, _Snapshot> _preCommit = {};
  final Set<String> _inFlightDismiss = {};
  final _errorController = StreamController<String>.broadcast();

  /// UI-facing stream of human-readable error messages for failed commits.
  Stream<String> get errorStream => _errorController.stream;

  @override
  List<NotificationModel> build() {
    ref.onDispose(() {
      _mounted = false;
      _debounce?.cancel();
      _badgeDebounce?.cancel();
      for (final t in _pendingCommits.values) {
        t.cancel();
      }
      _pendingCommits.clear();
      _preCommit.clear();
      _errorController.close();
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
    _syncBadge();
  }

  /// Sync iOS app icon badge to the current pending notification count.
  /// Called after every state mutation so the badge always matches what
  /// the user would see if they opened the app.
  ///
  /// Debounced: a rapid burst of WS updates (e.g. on reconnect) used to
  /// fire N platform-channel calls per burst. 200ms is short enough the
  /// user never notices, long enough to collapse a full sync into one
  /// call.
  Timer? _badgeDebounce;
  void _syncBadge() {
    _badgeDebounce?.cancel();
    _badgeDebounce = Timer(const Duration(milliseconds: 200), () {
      final pendingCount = state
          .where((n) => n.status == NotificationStatus.pending)
          .length;
      BadgeService.setCount(pendingCount);
    });
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
    _syncBadge();
  }

  /// Respond to a notification with an action value (e.g. "approve").
  ///
  /// Optimistically updates local state to actioned, then sends an HTTP
  /// PATCH as the single source of truth. The server broadcasts a
  /// `notification.updated` message over the hub after the write succeeds,
  /// so every other connected client sees the change in realtime via the
  /// same path as any other update. On failure we roll back just this
  /// notification and surface a human-readable error on [errorStream].
  ///
  /// We deliberately do NOT also send the action over the WebSocket.
  /// Previously we did both, and because the server fanned out to
  /// `callbackSvc.Deliver` on both the WS handler and the HTTP handler,
  /// customer webhooks fired twice per action. One path, one side effect.
  void respondToNotification(String id, String actionValue) {
    final current = _findById(id);
    if (current == null) return;

    _preCommit[id] = _Snapshot(
      status: current.status,
      actionedValue: current.actionedValue,
      actionedAt: current.actionedAt,
    );

    // Optimistic local update
    state = state.map((n) {
      if (n.id != id) return n;
      return n.copyWith(
        status: NotificationStatus.actioned,
        actionedValue: actionValue,
        actionedAt: DateTime.now().toUtc(),
      );
    }).toList();
    _persistCache();
    _syncBadge();

    // HTTP is the authoritative, retryable source of truth. The server
    // rebroadcasts `notification.updated` to the hub after the write,
    // so other clients still see the change in realtime.
    _commitAction(id, actionValue);
  }

  Future<void> _commitAction(String id, String actionValue) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.patchNotificationStatus(
        id,
        'actioned',
        actionedValue: actionValue,
      );
      _preCommit.remove(id);
    } catch (e) {
      debugPrint('[Notifications] Action commit failed: $e');
      if (!_mounted) return;
      final snap = _preCommit.remove(id);
      if (snap != null) _rollbackOne(id, snap);
      _errorController.add('操作失败：${_humanError(e)}');
    }
  }

  /// Dismiss a notification with delayed commit + undo support.
  ///
  /// The notification is immediately marked as dismissed locally (so the
  /// pending-card stack hides it) and a [_commitDelay] timer is armed. If
  /// [undoDismiss] is called before the timer fires, the notification is
  /// restored to its prior status without ever hitting the server. If the
  /// timer fires, the PATCH is sent; failures trigger a precise single-row
  /// rollback and a user-facing error.
  void dismissNotification(String id) {
    final current = _findById(id);
    if (current == null) return;

    // Save snapshot for undo / rollback
    _preCommit[id] = _Snapshot(
      status: current.status,
      actionedValue: current.actionedValue,
      actionedAt: current.actionedAt,
    );

    // Soft delete: set status to dismissed. pendingNotificationsProvider
    // filters these out, so the UI hides the card instantly.
    state = state.map((n) {
      if (n.id != id) return n;
      return n.copyWith(status: NotificationStatus.dismissed);
    }).toList();
    _persistCache();
    _syncBadge();

    // Replace any existing pending timer for this id (idempotent repeat)
    _pendingCommits[id]?.cancel();
    _pendingCommits[id] = Timer(_commitDelay, () {
      _commitDismiss(id);
    });
  }

  /// Cancel a pending dismiss and restore the notification to its original
  /// status. Safe to call any time before the delay elapses; a no-op if the
  /// dismiss has already committed.
  void undoDismiss(String id) {
    _pendingCommits[id]?.cancel();
    _pendingCommits.remove(id);
    final snap = _preCommit.remove(id);
    if (snap == null) return;
    _rollbackOne(id, snap);
  }

  Future<void> _commitDismiss(String id) async {
    _pendingCommits.remove(id);
    if (_inFlightDismiss.contains(id)) return; // dedup concurrent commits
    _inFlightDismiss.add(id);
    try {
      final api = ref.read(apiClientProvider);
      await api.patchNotificationStatus(id, 'dismissed');
      _preCommit.remove(id);
    } catch (e) {
      debugPrint('[Notifications] Dismiss commit failed: $e');
      if (!_mounted) return;
      final snap = _preCommit.remove(id);
      if (snap != null) _rollbackOne(id, snap);
      _errorController.add('取消失败：${_humanError(e)}');
    } finally {
      _inFlightDismiss.remove(id);
    }
  }

  /// Precisely restore a single notification to a prior snapshot, without
  /// touching any other entries in state (unlike a full `state = previous`
  /// rollback which could clobber intervening edits).
  void _rollbackOne(String id, _Snapshot snap) {
    state = state.map((n) {
      if (n.id != id) return n;
      return n.copyWith(
        status: snap.status,
        actionedValue: snap.actionedValue,
        actionedAt: snap.actionedAt,
      );
    }).toList();
    _persistCache();
    _syncBadge();
  }

  String _humanError(Object e) {
    final msg = e.toString();
    if (msg.contains('TimeoutException')) return '请求超时';
    if (msg.contains('SocketException')) return '无法连接服务器';
    return '请重试';
  }

  NotificationModel? _findById(String id) {
    for (final n in state) {
      if (n.id == id) return n;
    }
    return null;
  }
}

/// Lightweight snapshot used to roll back a notification's status fields
/// after a failed optimistic update.
class _Snapshot {
  final NotificationStatus status;
  final String? actionedValue;
  final DateTime? actionedAt;
  _Snapshot({
    required this.status,
    this.actionedValue,
    this.actionedAt,
  });
}

final pendingNotificationsProvider = Provider<List<NotificationModel>>((ref) {
  final all = ref.watch(notificationsProvider);
  return all.where((n) => n.status == NotificationStatus.pending).toList();
});
