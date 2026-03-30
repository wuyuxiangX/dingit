import 'package:go_router/go_router.dart';

import '../../features/notifications/presentation/pages/notification_page.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const NotificationPage(),
    ),
  ],
);
