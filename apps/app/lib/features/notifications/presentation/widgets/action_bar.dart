import 'package:flutter/material.dart';
import 'package:notify_shared/notify_shared.dart';

import '../../../../app/theme/app_colors.dart';

class ActionBar extends StatelessWidget {
  final NotificationModel? notification;
  final void Function(String actionValue)? onAction;
  final VoidCallback? onNext;

  const ActionBar({
    super.key,
    this.notification,
    this.onAction,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final actions = notification?.actions ?? [];

    if (actions.isEmpty && onNext == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Dynamic action buttons from notification
          for (final action in actions)
            _ActionButton(
              label: action.label,
              icon: _resolveIcon(action.icon),
              color: _resolveColor(action.colorHex),
              destructive: action.destructive,
              onTap: () => onAction?.call(action.value),
            ),

          // Next button (always shown if there are more notifications)
          if (onNext != null)
            _ActionButton(
              label: 'Next',
              icon: Icons.arrow_forward_rounded,
              color: AppColors.textPrimary,
              onTap: onNext,
            ),
        ],
      ),
    );
  }

  IconData _resolveIcon(String? iconName) {
    return switch (iconName) {
      'check' || 'complete' => Icons.check_circle_outline_rounded,
      'close' || 'reject' => Icons.close_rounded,
      'snooze' || 'clock' => Icons.access_time_rounded,
      'approve' => Icons.thumb_up_outlined,
      'delete' || 'trash' => Icons.delete_outline_rounded,
      'send' => Icons.send_rounded,
      'star' => Icons.star_outline_rounded,
      _ => Icons.radio_button_unchecked_rounded,
    };
  }

  Color _resolveColor(String? hex) {
    if (hex == null || hex.isEmpty) return AppColors.textPrimary;
    try {
      final colorValue = int.parse(hex.replaceFirst('#', ''), radix: 16);
      return Color(0xFF000000 | colorValue);
    } catch (_) {
      return AppColors.textPrimary;
    }
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool destructive;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.destructive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = destructive ? AppColors.error : color;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28, color: effectiveColor),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: effectiveColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
