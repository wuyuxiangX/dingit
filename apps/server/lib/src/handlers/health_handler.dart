import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../services/notification_store.dart';
import '../services/ws_manager.dart';

class HealthHandler {
  final NotificationStore _store;
  final WsManager _wsManager;
  final DateTime _startTime;

  HealthHandler({
    required NotificationStore store,
    required WsManager wsManager,
  })  : _store = store,
        _wsManager = wsManager,
        _startTime = DateTime.now();

  Router get router {
    final router = Router();
    router.get('/health', _health);
    return router;
  }

  Future<Response> _health(Request request) async {
    final uptime = DateTime.now().difference(_startTime).inSeconds;

    return Response.ok(
      jsonEncode({
        'status': 'ok',
        'uptime_seconds': uptime,
        'connected_clients': _wsManager.connectedClients,
        'pending_notifications': _store.count(),
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
