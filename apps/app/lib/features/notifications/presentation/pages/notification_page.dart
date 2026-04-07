import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/websocket/ws_client.dart';
import '../../../settings/providers/settings_provider.dart';
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
      _initPushWhenReady();
    });
  }

  Future<void> _initPushWhenReady() async {
    // Wait for settings to be loaded before initializing push
    for (var i = 0; i < 20; i++) {
      final settings = ref.read(settingsProvider);
      if (settings.isLoaded && settings.serverUrl.isNotEmpty) {
        ref.read(pushServiceProvider).initialize();
        return;
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingNotificationsProvider);
    final topNotification = pending.isNotEmpty ? pending.first : null;
    final notifier = ref.read(notificationsProvider.notifier);

    void dismissTop() => notifier.dismissNotification(topNotification!.id);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.push('/settings'),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(LucideIcons.settings, size: 20, color: AppColors.ink),
                    ),
                  ),
                  const Spacer(),
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
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.push('/history'),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(LucideIcons.history, size: 20, color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: CardStack(
                notifications: pending,
                onAction: (notification, action) {
                  notifier.respondToNotification(notification.id, action);
                },
                onDismiss: (notification) {
                  notifier.dismissNotification(notification.id);
                },
                onTap: (notification) {
                  context.push('/notification/${notification.id}');
                },
              ),
            ),

            ActionBar(
              notification: topNotification,
              onAction: topNotification != null
                  ? (actionValue) => notifier.respondToNotification(topNotification.id, actionValue)
                  : null,
              onDismiss: topNotification != null ? dismissTop : null,
              onNext: pending.length > 1 ? dismissTop : null,
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
