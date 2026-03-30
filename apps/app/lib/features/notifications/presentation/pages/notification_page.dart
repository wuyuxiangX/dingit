import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    // Connect WebSocket after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(wsClientProvider).connect();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingNotificationsProvider);
    final topNotification = pending.isNotEmpty ? pending.first : null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () {},
        ),
        title: Column(
          children: [
            const Text('Notifications'),
            _ConnectionStatus(),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              // Reconnect WebSocket to resync
              ref.read(wsClientProvider).disconnect();
              ref.read(wsClientProvider).connect();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Card count
          if (pending.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${pending.length} pending',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),

          // Card stack
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
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
          ),

          // Action bar
          SafeArea(
            child: ActionBar(
              notification: topNotification,
              onAction: topNotification != null
                  ? (actionValue) {
                      ref
                          .read(notificationsProvider.notifier)
                          .respondToNotification(
                              topNotification.id, actionValue);
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
          ),
        ],
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
        final (color, text) = switch (state) {
          WsConnectionState.connected => (AppColors.success, 'Connected'),
          WsConnectionState.connecting => (AppColors.warning, 'Connecting...'),
          WsConnectionState.disconnected => (AppColors.error, 'Disconnected'),
        };

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              text,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        );
      },
    );
  }
}
