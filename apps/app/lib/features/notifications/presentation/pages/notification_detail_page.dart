import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:dingit_shared/dingit_shared.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/icon_resolver.dart';
import '../../providers/notifications_provider.dart';

class NotificationDetailPage extends ConsumerWidget {
  final String notificationId;
  final NotificationModel? notification;

  const NotificationDetailPage({
    super.key,
    required this.notificationId,
    this.notification,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Prefer passed notification (from history), fallback to in-memory list
    final notifications = ref.watch(notificationsProvider);
    final notification = this.notification ??
        notifications
            .cast<NotificationModel?>()
            .firstWhere((n) => n?.id == notificationId, orElse: () => null);

    if (notification == null) {
      return Scaffold(
        backgroundColor: AppColors.paperWarm,
        appBar: _buildAppBar(context),
        body: Center(
          child: Text(
            'Notification not found',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final theme = Theme.of(context).textTheme;
    final isPending = notification.status == NotificationStatus.pending;

    return Scaffold(
      backgroundColor: AppColors.paperWarm,
      body: CustomScrollView(
        slivers: [
          // -- Collapsing app bar with source header --
          SliverAppBar(
            backgroundColor: AppColors.paperWarm,
            elevation: 0,
            scrolledUnderElevation: 0,
            pinned: true,
            leading: IconButton(
              icon: const Icon(LucideIcons.arrowLeft, size: 20),
              color: AppColors.ink,
              onPressed: () => context.pop(),
            ),
            actions: [
              _StatusChip(status: notification.status),
              const SizedBox(width: 16),
            ],
          ),

          // -- Content --
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Source + priority row
                Row(
                  children: [
                    if (notification.icon case final icon?
                        when icon.isNotEmpty) ...[
                      Icon(resolveNotificationIcon(icon), size: 15, color: AppColors.accent),
                      const SizedBox(width: 6),
                    ],
                    if (notification.source.isNotEmpty)
                      Text(
                        notification.source.toUpperCase(),
                        style: theme.titleSmall?.copyWith(
                          letterSpacing: 1.5,
                          fontSize: 11,
                          color: AppColors.accent,
                        ),
                      ),
                    const Spacer(),
                    _PriorityIndicator(priority: notification.priority),
                  ],
                ),

                const SizedBox(height: 16),

                // Title — editorial serif
                Text(
                  notification.title,
                  style: GoogleFonts.dmSerifDisplay(
                    fontSize: 28,
                    fontWeight: FontWeight.w400,
                    color: AppColors.ink,
                    height: 1.15,
                  ),
                ),

                const SizedBox(height: 20),

                // Timestamp row
                _TimestampRow(notification: notification),

                const SizedBox(height: 28),

                // Divider
                const Divider(height: 1, color: AppColors.divider),

                const SizedBox(height: 28),

                // Body — full text
                Text(
                  notification.body,
                  style: theme.bodyLarge?.copyWith(
                    height: 1.75,
                    fontSize: 16,
                    color: AppColors.inkMuted,
                  ),
                ),

                // Metadata section
                if (notification.metadata != null &&
                    notification.metadata!.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  _MetadataSection(metadata: notification.metadata!),
                ],

                // Action response info
                if (notification.actionedValue != null) ...[
                  const SizedBox(height: 32),
                  _ActionedInfo(notification: notification),
                ],

                // Actions
                if (isPending && notification.actions.isNotEmpty) ...[
                  const SizedBox(height: 36),
                  _ActionButtons(
                    notification: notification,
                    onAction: (value) {
                      ref
                          .read(notificationsProvider.notifier)
                          .respondToNotification(notification.id, value);
                      context.pop();
                    },
                  ),
                ],

                const SizedBox(height: 20),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(LucideIcons.arrowLeft, size: 20),
        color: AppColors.ink,
        onPressed: () => context.pop(),
      ),
    );
  }

}

// -- Status chip --

class _StatusChip extends StatelessWidget {
  final NotificationStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      NotificationStatus.pending => ('Pending', AppColors.accent),
      NotificationStatus.actioned => ('Actioned', AppColors.success),
      NotificationStatus.dismissed => ('Dismissed', AppColors.inkFaint),
      NotificationStatus.expired => ('Expired', AppColors.warning),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// -- Priority indicator --

class _PriorityIndicator extends StatelessWidget {
  final String priority;
  const _PriorityIndicator({required this.priority});

  @override
  Widget build(BuildContext context) {
    if (priority == 'normal') return const SizedBox.shrink();

    final (label, color, icon) = switch (priority) {
      'urgent' => ('Urgent', AppColors.destructive, LucideIcons.alertCircle),
      'high' => ('High', AppColors.warning, LucideIcons.arrowUp),
      'low' => ('Low', AppColors.inkFaint, LucideIcons.arrowDown),
      _ => ('Normal', AppColors.inkFaint, LucideIcons.minus),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}

// -- Timestamp row --

class _TimestampRow extends StatelessWidget {
  final NotificationModel notification;
  const _TimestampRow({required this.notification});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final created = formatFullDate(notification.timestamp);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.clock3, size: 13, color: AppColors.inkFaint),
            const SizedBox(width: 6),
            Text(created, style: theme.bodyMedium),
          ],
        ),
        if (notification.actionedAt case final actionedAt?) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(LucideIcons.checkCircle2, size: 13, color: AppColors.success),
              const SizedBox(width: 6),
              Text(
                'Actioned ${formatFullDate(actionedAt)}',
                style: theme.bodyMedium?.copyWith(color: AppColors.success),
              ),
            ],
          ),
        ],
      ],
    );
  }

}

// -- Metadata section --

class _MetadataSection extends StatelessWidget {
  final Map<String, dynamic> metadata;
  const _MetadataSection({required this.metadata});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            'METADATA',
            style: theme.labelMedium?.copyWith(
              color: AppColors.inkFaint,
              fontSize: 11,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow1,
                blurRadius: 8,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              children: [
                for (final (i, entry) in metadata.entries.indexed) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.only(left: 16),
                      child: Divider(
                          height: 0.5, thickness: 0.5, color: AppColors.divider),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(
                            entry.key,
                            style: theme.bodyMedium?.copyWith(
                              color: AppColors.inkFaint,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${entry.value}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.ink,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// -- Actioned info --

class _ActionedInfo extends StatelessWidget {
  final NotificationModel notification;
  const _ActionedInfo({required this.notification});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.checkCircle2, size: 18, color: AppColors.success),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Action taken',
                  style: theme.bodyMedium?.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  notification.actionedValue ?? '',
                  style: theme.bodyMedium?.copyWith(color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -- Action buttons --

class _ActionButtons extends StatelessWidget {
  final NotificationModel notification;
  final void Function(String value) onAction;
  const _ActionButtons({required this.notification, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (i, action) in notification.actions.indexed) ...[
          if (i > 0) const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () => onAction(action.value),
              style: FilledButton.styleFrom(
                backgroundColor: action.destructive
                    ? AppColors.destructive
                    : AppColors.ink,
                foregroundColor: AppColors.paper,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(action.label),
            ),
          ),
        ],
      ],
    );
  }
}
