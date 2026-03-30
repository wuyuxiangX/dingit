import 'dart:convert';

import 'package:notify_shared/notify_shared.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'notification_store.dart';

class WsManager {
  final NotificationStore _store;
  final void Function(ActionResponse response)? onActionResponse;
  final Set<WebSocketChannel> _clients = {};

  WsManager({
    required NotificationStore store,
    this.onActionResponse,
  }) : _store = store;

  int get connectedClients => _clients.length;

  void addClient(WebSocketChannel channel) {
    _clients.add(channel);

    // Send full sync on connect
    final pending = _store.list(status: NotificationStatus.pending);
    final syncMsg = WsMessage.syncFull(notifications: pending);
    _sendTo(channel, syncMsg);

    // Listen for messages
    channel.stream.listen(
      (data) => _handleMessage(channel, data),
      onDone: () => _clients.remove(channel),
      onError: (_) => _clients.remove(channel),
    );
  }

  void broadcast(WsMessage message) {
    final json = jsonEncode(message.toJson());
    final stale = <WebSocketChannel>[];
    for (final client in _clients) {
      try {
        client.sink.add(json);
      } catch (_) {
        stale.add(client);
      }
    }
    for (final c in stale) {
      _clients.remove(c);
    }
  }

  void _handleMessage(WebSocketChannel channel, dynamic data) {
    try {
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      final message = WsMessage.fromJson(json);

      switch (message) {
        case WsActionResponse(:final response):
          onActionResponse?.call(response);
        case WsPing():
          _sendTo(channel, const WsMessage.pong());
        default:
          break;
      }
    } catch (e) {
      print('[WsManager] Error parsing message: $e');
    }
  }

  void _sendTo(WebSocketChannel channel, WsMessage message) {
    try {
      channel.sink.add(jsonEncode(message.toJson()));
    } catch (_) {
      _clients.remove(channel);
    }
  }

  void dispose() {
    for (final client in _clients) {
      client.sink.close();
    }
    _clients.clear();
  }
}
