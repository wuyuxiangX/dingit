import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/websocket/ws_client.dart';
import '../../providers/notifications_provider.dart';
import '../widgets/action_bar.dart';
import '../widgets/card_stack.dart';

class NotificationPage extends ConsumerStatefulWidget {
  const NotificationPage({super.key});

  @override
  ConsumerState<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends ConsumerState<NotificationPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(wsClientProvider).connect();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingNotificationsProvider);
    final topNotification = pending.isNotEmpty ? pending.first : null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.push('/settings'),
                    child: Icon(LucideIcons.settings, size: 20, color: AppColors.ink),
                  ),
                  const Spacer(),
                  // Center title
                  Column(
                    children: [
                      Text(
                        'Dingit',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontSize: 22),
                      ),
                      const SizedBox(height: 2),
                      _ConnectionStatus(),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      ref.read(wsClientProvider).disconnect();
                      ref.read(wsClientProvider).connect();
                    },
                    child: Icon(LucideIcons.refreshCw, size: 18, color: AppColors.ink),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Card stack — fills all available space
            Expanded(
              child: CardStack(
                notifications: pending,
                onAction: (notification, action) {
                  ref
                      .read(notificationsProvider.notifier)
                      .respondToNotification(notification.id, action);
                },
                onDismiss: (notification) {
                  ref
                      .read(notificationsProvider.notifier)
                      .dismissNotification(notification.id);
                },
              ),
            ),

            // Action bar
            ActionBar(
              notification: topNotification,
              onAction: topNotification != null
                  ? (actionValue) {
                      ref
                          .read(notificationsProvider.notifier)
                          .respondToNotification(topNotification.id, actionValue);
                    }
                  : null,
              onNext: pending.length > 1
                  ? () {
                      ref
                          .read(notificationsProvider.notifier)
                          .dismissNotification(pending.first.id);
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionStatus extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateNotifier = ref.watch(connectionStateProvider);

    return ValueListenableBuilder<WsConnectionState>(
      valueListenable: stateNotifier,
      builder: (context, state, _) {
        final (color, label) = switch (state) {
          WsConnectionState.connected => (AppColors.success, 'Updated now'),
          WsConnectionState.connecting => (AppColors.warning, 'Connecting...'),
          WsConnectionState.disconnected => (AppColors.destructive, 'Disconnected'),
        };

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        );
      },
    );
  }
}
