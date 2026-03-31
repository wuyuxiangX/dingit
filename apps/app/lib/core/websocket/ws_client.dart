import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:dingit_shared/dingit_shared.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum WsConnectionState { disconnected, connecting, connected }

class WsClient {
  String url;
  String? apiKey;
  final void Function(WsMessage message) onMessage;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  int _reconnectAttempts = 0;

  final connectionState = ValueNotifier(WsConnectionState.disconnected);

  WsClient({required this.url, this.apiKey, required this.onMessage});

  /// Disconnect and reconnect with a new URL and/or API key.
  Future<void> reconnectWithUrl(String newUrl, {String? newApiKey}) async {
    url = newUrl;
    if (newApiKey != null) apiKey = newApiKey;
    disconnect();
    _reconnectAttempts = 0;
    await connect();
  }

  Future<void> connect() async {
    if (connectionState.value == WsConnectionState.connecting) return;
    connectionState.value = WsConnectionState.connecting;

    try {
      final uri = Uri.parse(url);
      final headers = <String, dynamic>{};
      if (apiKey != null && apiKey!.isNotEmpty) {
        headers['X-API-Key'] = apiKey;
      }
      _channel = IOWebSocketChannel.connect(uri, headers: headers);
      await _channel!.ready;

      connectionState.value = WsConnectionState.connected;
      _reconnectAttempts = 0;

      _startPing();

      _subscription = _channel!.stream.listen(
        _handleData,
        onDone: () {
          connectionState.value = WsConnectionState.disconnected;
          _scheduleReconnect();
        },
        onError: (_) {
          connectionState.value = WsConnectionState.disconnected;
          _scheduleReconnect();
        },
      );
    } catch (e) {
      debugPrint('[WsClient] Connection failed: $e');
      connectionState.value = WsConnectionState.disconnected;
      _scheduleReconnect();
    }
  }

  void send(WsMessage message) {
    if (connectionState.value != WsConnectionState.connected) return;
    try {
      _channel?.sink.add(jsonEncode(message.toJson()));
    } catch (e) {
      debugPrint('[WsClient] Send error: $e');
    }
  }

  void _handleData(dynamic data) {
    try {
      final json = jsonDecode(data as String) as Map<String, dynamic>;
      final message = WsMessage.fromJson(json);

      if (message is WsPong) return;

      onMessage(message);
    } catch (e) {
      debugPrint('[WsClient] Parse error: $e');
    }
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      send(const WsMessage.ping());
    });
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();

    final delay = min(30, pow(2, _reconnectAttempts).toInt());
    _reconnectAttempts++;

    debugPrint('[WsClient] Reconnecting in ${delay}s (attempt $_reconnectAttempts)');
    _reconnectTimer = Timer(Duration(seconds: delay), connect);
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    connectionState.value = WsConnectionState.disconnected;
  }
}
