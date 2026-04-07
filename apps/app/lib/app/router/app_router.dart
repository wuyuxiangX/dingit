import 'package:go_router/go_router.dart';

import '../../features/notifications/presentation/pages/notification_detail_page.dart';
import '../../features/notifications/presentation/pages/notification_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const NotificationPage(),
    ),
    GoRoute(
      path: '/notification/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return NotificationDetailPage(notificationId: id);
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
  ],
);
