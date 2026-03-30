import 'package:shelf/shelf.dart';

Middleware loggerMiddleware() {
  return createMiddleware(
    requestHandler: (Request request) {
      final time = DateTime.now().toIso8601String().substring(11, 19);
      print('[$time] ${request.method} ${request.requestedUri.path}');
      return null;
    },
  );
}
