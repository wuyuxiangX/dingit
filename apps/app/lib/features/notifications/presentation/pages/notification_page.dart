import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/push/badge_service.dart';
import '../../../../core/ui/undo_pill.dart';
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
  bool _pushInitialized = false;
  StreamSubscription<String>? _errorSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // wsClientProvider auto-connects once settings are hydrated; no
      // manual connect() call needed here. Just touch it to ensure the
      // provider is created if nothing else has read it yet.
      ref.read(wsClientProvider);
      // Sync iOS badge to current pending count as soon as the page mounts.
      // This overrides the AppDelegate's unconditional clear-to-0 with the
      // authoritative value (what the user actually sees in the card stack).
      final pendingNow = ref.read(pendingNotificationsProvider).length;
      BadgeService.setCount(pendingNow);

      // Surface commit failures from the notifications notifier as an
      // error pill so the user knows something went wrong instead of
      // silently watching the card pop back.
      _errorSub = ref
          .read(notificationsProvider.notifier)
          .errorStream
          .listen((msg) {
        if (!mounted) return;
        showUndoPill(
          context,
          message: msg,
          icon: LucideIcons.alertCircle,
          iconColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 3),
        );
      });

      ref.listenManual(settingsProvider, (prev, next) {
        if (!_pushInitialized && next.isLoaded && next.serverUrl.isNotEmpty) {
          _pushInitialized = true;
          ref.read(pushServiceProvider).initialize();
        }
      }, fireImmediately: true);
    });
  }

  @override
  void dispose() {
    _errorSub?.cancel();
    super.dispose();
  }

  void _dismissWithUndo(String id) {
    final notifier = ref.read(notificationsProvider.notifier);
    notifier.dismissNotification(id);
    // Duration must match NotificationsNotifier._commitDelay so the pill
    // fades out just as the delayed PATCH fires.
    showUndoPill(
      context,
      message: '已取消',
      undoLabel: '撤销',
      onUndo: () => notifier.undoDismiss(id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingNotificationsProvider);
    final topNotification = pending.isNotEmpty ? pending.first : null;
    final notifier = ref.read(notificationsProvider.notifier);

    void dismissTop() => _dismissWithUndo(topNotification!.id);

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
                  _dismissWithUndo(notification.id);
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
