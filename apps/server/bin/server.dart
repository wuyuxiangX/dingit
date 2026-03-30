import 'dart:io';

import 'package:notify_shared/notify_shared.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:notify_server/src/handlers/health_handler.dart';
import 'package:notify_server/src/handlers/notification_handler.dart';
import 'package:notify_server/src/middleware/cors_middleware.dart';
import 'package:notify_server/src/middleware/logger_middleware.dart';
import 'package:notify_server/src/services/callback_service.dart';
import 'package:notify_server/src/services/notification_store.dart';
import 'package:notify_server/src/services/ws_manager.dart';

void main(List<String> args) async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;

  // Services
  final store = NotificationStore();
  final callbackService = CallbackService();

  late final WsManager wsManager;
  wsManager = WsManager(
    store: store,
    onActionResponse: (ActionResponse response) async {
      print('[Server] Action response: ${response.notificationId} -> ${response.action}');

      final notification = store.updateStatus(
        response.notificationId,
        NotificationStatus.actioned,
        actionedValue: response.action,
      );

      if (notification != null) {
        // Broadcast status update to all clients
        wsManager.broadcast(
          WsMessage.notificationUpdated(notification: notification),
        );

        // Deliver callback
        if (notification.callbackUrl != null) {
          callbackService.deliver(
            notification: notification,
            response: response,
          );
        }
      }
    },
  );

  // Handlers
  final notificationHandler = NotificationHandler(
    store: store,
    wsManager: wsManager,
  );
  final healthHandler = HealthHandler(
    store: store,
    wsManager: wsManager,
  );

  // WebSocket handler
  final wsHandler = webSocketHandler((WebSocketChannel channel, String? protocol) {
    print('[Server] New WebSocket client connected');
    wsManager.addClient(channel);
  });

  // Router
  final app = Router();

  // Mount REST routes
  app.mount('/', notificationHandler.router.call);
  app.mount('/', healthHandler.router.call);

  // WebSocket route
  app.get('/ws', wsHandler);

  // Pipeline
  final handler = const Pipeline()
      .addMiddleware(loggerMiddleware())
      .addMiddleware(corsMiddleware())
      .addHandler(app.call);

  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  print('🚀 Notify Hub Server running on http://localhost:${server.port}');
  print('   REST API: http://localhost:${server.port}/api/notifications');
  print('   WebSocket: ws://localhost:${server.port}/ws');
  print('   Health: http://localhost:${server.port}/health');
}
