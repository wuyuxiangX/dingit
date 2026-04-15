import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../app/locale/locale_context_ext.dart';
import '../../../../app/theme/theme_context_ext.dart';
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
          // Float above the 80px ActionBar at the bottom of this page.
          bottomPadding: 120,
        );
      });

      ref.listenManual(settingsProvider, (prev, next) {
        if (!next.isLoaded || next.serverUrl.isEmpty) return;
        final pushService = ref.read(pushServiceProvider);
        // First run: no prior settings and no cached token — run the
        // full initialize() (permission, token fetch, register).
        if (prev == null) {
          pushService.initialize();
          return;
        }
        final changed = prev.serverUrl != next.serverUrl ||
            prev.apiKey != next.apiKey ||
            prev.dndEnabled != next.dndEnabled ||
            prev.dndStart != next.dndStart ||
            prev.dndEnd != next.dndEnd;
        if (changed) {
          // Re-register against the (possibly new) server with the
          // latest DND window. Uses the cached token when available so
          // we skip Firebase permission + token fetch on every save.
          pushService.updateRegistration();
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
      message: context.l10n.notificationDismissedPill,
      undoLabel: context.l10n.notificationUndoAction,
      onUndo: () => notifier.undoDismiss(id),
      // Match NotificationsNotifier._commitDelay so the pill fades out
      // at the same moment the delayed PATCH fires.
      duration: const Duration(seconds: 3),
      // Float above the 80px ActionBar at the bottom of this page.
      bottomPadding: 120,
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
                      child: Icon(LucideIcons.settings,
                          size: 20, color: context.colors.onSurface),
                    ),
                  ),
                  const Spacer(),
                  Column(
                    children: [
                      Text(
                        context.l10n.appTitle,
                        style: context.typo.headlineLarge?.copyWith(fontSize: 22),
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
                      child: Icon(LucideIcons.history,
                          size: 20, color: context.colors.onSurface),
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
    final palette = context.palette;
    final colors = context.colors;

    return ValueListenableBuilder<WsConnectionState>(
      valueListenable: stateNotifier,
      builder: (context, state, _) {
        final l10n = context.l10n;
        final (color, label) = switch (state) {
          WsConnectionState.connected =>
            (palette.success, l10n.notificationConnectionConnected),
          WsConnectionState.connecting =>
            (palette.warning, l10n.notificationConnectionConnecting),
          WsConnectionState.disconnected =>
            (colors.error, l10n.notificationConnectionDisconnected),
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
            Text(label, style: context.typo.labelSmall),
          ],
        );
      },
    );
  }
}
