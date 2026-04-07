import 'package:go_router/go_router.dart';
import 'package:dingit_shared/dingit_shared.dart';

import '../../features/notifications/presentation/pages/notification_detail_page.dart';
import '../../features/notifications/presentation/pages/notification_history_page.dart';
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
        final extra = state.extra is NotificationModel ? state.extra as NotificationModel : null;
        return NotificationDetailPage(notificationId: id, notification: extra);
      },
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => const NotificationHistoryPage(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
  ],
);
