import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:dingit_shared/dingit_shared.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum WsConnectionState { disconnected, connecting, connected }

class WsClient {
  /// How long a single connect attempt is allowed to hang before we give
  /// up and mark the attempt failed. Previously 15s, which made a bad
  /// server URL dominate the app's first 60+ seconds of startup while the
  /// backoff played out. 5s matches the health-check timeout used in the
  /// Settings page's `_testConnection` and is long enough for a healthy
  /// Wi-Fi handshake.
  static const _connectTimeout = Duration(seconds: 5);

  /// Cap on the exponential backoff reconnect loop. After this many
  /// consecutive failures we stop auto-reconnecting and sit in
  /// `disconnected`. The user can force a reconnect by saving the
  /// settings page (which calls `reconnectWithUrl`), which resets the
  /// counter. Without this cap the client would spin forever against an
  /// unreachable URL, draining battery and log volume.
  static const _maxReconnectAttempts = 5;

  String url;
  String? apiKey;
  final void Function(WsMessage message) onMessage;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  int _reconnectAttempts = 0;
  bool _disposed = false;

  final connectionState = ValueNotifier(WsConnectionState.disconnected);

  DateTime? lastSyncAt;

  WsClient({required this.url, this.apiKey, required this.onMessage, this.lastSyncAt});

  /// Disconnect and reconnect with a new URL and/or API key.
  Future<void> reconnectWithUrl(String newUrl, {String? newApiKey}) async {
    url = newUrl;
    if (newApiKey != null) apiKey = newApiKey;
    _cleanup();
    _reconnectAttempts = 0;
    await connect();
  }

  Future<void> connect() async {
    if (_disposed) return;
    if (connectionState.value == WsConnectionState.connecting) return;
    connectionState.value = WsConnectionState.connecting;

    try {
      // Clean up any previous connection before creating a new one
      await _subscription?.cancel();
      _subscription = null;
      try {
        _channel?.sink.close();
      } catch (_) {}
      _channel = null;

      var uri = Uri.parse(url);
      final extraQuery = <String, String>{};
      if (lastSyncAt != null) {
        extraQuery['since'] = lastSyncAt!.toUtc().toIso8601String();
      }
      // Pass the API key as both a header (IOWebSocketChannel on mobile)
      // AND a query param (browser WebSocket API, which cannot set upgrade
      // headers). The server strips `api_key` from request logs so it
      // never ends up on disk. Without this the server cannot tell this
      // client apart from an unauthenticated attacker.
      if (apiKey != null && apiKey!.isNotEmpty) {
        extraQuery['api_key'] = apiKey!;
      }
      if (extraQuery.isNotEmpty) {
        uri = uri.replace(queryParameters: {
          ...uri.queryParameters,
          ...extraQuery,
        });
      }
      final headers = <String, dynamic>{};
      if (apiKey != null && apiKey!.isNotEmpty) {
        headers['X-API-Key'] = apiKey;
      }
      _channel = IOWebSocketChannel.connect(uri, headers: headers);
      await _channel!.ready.timeout(_connectTimeout);

      if (_disposed) {
        _channel?.sink.close();
        _channel = null;
        return;
      }

      connectionState.value = WsConnectionState.connected;
      _reconnectAttempts = 0;

      _startPing();

      _subscription = _channel!.stream.listen(
        _handleData,
        onDone: () {
          if (_disposed) return;
          connectionState.value = WsConnectionState.disconnected;
          _scheduleReconnect();
        },
        onError: (_) {
          if (_disposed) return;
          connectionState.value = WsConnectionState.disconnected;
          _scheduleReconnect();
        },
      );
    } catch (e) {
      debugPrint('[WsClient] Connection failed: $e');
      // Clean up the failed channel
      try {
        _channel?.sink.close();
      } catch (_) {}
      _channel = null;
      if (_disposed) return;
      connectionState.value = WsConnectionState.disconnected;
      _scheduleReconnect();
    }
  }

  void send(WsMessage message) {
    if (_disposed || connectionState.value != WsConnectionState.connected) return;
    try {
      _channel?.sink.add(jsonEncode(message.toJson()));
    } catch (e) {
      debugPrint('[WsClient] Send error: $e');
    }
  }

  void _handleData(dynamic data) {
    if (_disposed) return;
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
      if (_disposed) return;
      send(const WsMessage.ping());
    });
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint(
        '[WsClient] Giving up after $_reconnectAttempts attempts. '
        'Will retry when settings are saved.',
      );
      return;
    }

    final delay = min(30, pow(2, _reconnectAttempts).toInt());
    _reconnectAttempts++;

    debugPrint('[WsClient] Reconnecting in ${delay}s (attempt $_reconnectAttempts)');
    _reconnectTimer = Timer(Duration(seconds: delay), connect);
  }

  /// Internal cleanup without marking as disposed — used for reconnection.
  void _cleanup() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    connectionState.value = WsConnectionState.disconnected;
  }

  void disconnect() {
    _disposed = true;
    _cleanup();
  }
}
