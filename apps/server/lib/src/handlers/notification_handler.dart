import 'dart:convert';

import 'package:notify_shared/notify_shared.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../services/notification_store.dart';
import '../services/ws_manager.dart';

class NotificationHandler {
  final NotificationStore _store;
  final WsManager _wsManager;

  NotificationHandler({
    required NotificationStore store,
    required WsManager wsManager,
  })  : _store = store,
        _wsManager = wsManager;

  Router get router {
    final router = Router();

    router.post('/api/notifications', _create);
    router.get('/api/notifications', _list);
    router.get('/api/notifications/<id>', _getById);

    return router;
  }

  Future<Response> _create(Request request) async {
    try {
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final title = json['title'] as String?;
      final bodyText = json['body'] as String?;
      final source = json['source'] as String? ?? 'unknown';

      if (title == null || bodyText == null) {
        return Response(400,
            body: jsonEncode({'error': 'title and body are required'}),
            headers: {'Content-Type': 'application/json'});
      }

      final actions = (json['actions'] as List<dynamic>?)
              ?.map((a) =>
                  NotificationAction.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [];

      final notification = _store.add(
        title: title,
        body: bodyText,
        source: source,
        actions: actions,
        callbackUrl: json['callback_url'] as String?,
        metadata: json['metadata'] as Map<String, dynamic>?,
      );

      // Push to all connected clients
      _wsManager.broadcast(
        WsMessage.notificationNew(notification: notification),
      );

      return Response(201,
          body: jsonEncode({
            'id': notification.id,
            'status': notification.status.name,
            'timestamp': notification.timestamp.toIso8601String(),
          }),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response(400,
          body: jsonEncode({'error': e.toString()}),
          headers: {'Content-Type': 'application/json'});
    }
  }

  Future<Response> _list(Request request) async {
    final statusParam = request.url.queryParameters['status'];
    final limit =
        int.tryParse(request.url.queryParameters['limit'] ?? '') ?? 50;
    final offset =
        int.tryParse(request.url.queryParameters['offset'] ?? '') ?? 0;

    NotificationStatus? status;
    if (statusParam != null) {
      status = NotificationStatus.values
          .where((s) => s.name == statusParam)
          .firstOrNull;
    }

    final notifications = _store.list(
      status: status,
      limit: limit,
      offset: offset,
    );

    return Response.ok(
      jsonEncode({
        'notifications': notifications.map((n) => n.toJson()).toList(),
        'total': _store.count(status: status),
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _getById(Request request, String id) async {
    final notification = _store.get(id);
    if (notification == null) {
      return Response(404,
          body: jsonEncode({'error': 'Not found'}),
          headers: {'Content-Type': 'application/json'});
    }

    return Response.ok(
      jsonEncode(notification.toJson()),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
