import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:dingit_shared/dingit_shared.dart';

import '../../../../app/locale/locale_context_ext.dart';
import '../../../../app/theme/theme_context_ext.dart';

class ActionBar extends StatelessWidget {
  final NotificationModel? notification;
  final void Function(String actionValue)? onAction;
  final VoidCallback? onNext;
  final VoidCallback? onDismiss;

  const ActionBar({
    super.key,
    this.notification,
    this.onAction,
    this.onNext,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final actions = notification?.actions ?? [];
    final hasContent = actions.isNotEmpty || onNext != null || onDismiss != null;

    return SizedBox(
      height: 80,
      child: hasContent
          ? Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
              child: Row(
                children: [
                  for (final action in actions)
                    Expanded(
                      child: _ActionItem(
                        label: action.label,
                        icon: _resolveIcon(action.icon, action.value),
                        destructive: action.destructive,
                        onTap: () => onAction?.call(action.value),
                      ),
                    ),
                  if (onDismiss != null)
                    Expanded(
                      child: _ActionItem(
                        label: context.l10n.actionBarDismiss,
                        icon: LucideIcons.xCircle,
                        onTap: onDismiss,
                      ),
                    ),
                  if (onNext != null)
                    Expanded(
                      child: _ActionItem(
                        label: context.l10n.actionBarNext,
                        icon: LucideIcons.arrowRight,
                        onTap: onNext,
                      ),
                    ),
                ],
              ),
            )
          : null,
    );
  }

  IconData _resolveIcon(String? iconName, String value) {
    final key = iconName ?? value.toLowerCase();
    return _iconMap[key] ?? LucideIcons.circle;
  }

  static const _iconMap = <String, IconData>{
    'check': LucideIcons.checkCircle2,
    'complete': LucideIcons.checkCircle2,
    'done': LucideIcons.checkCircle2,
    'approve': LucideIcons.checkCircle2,
    'confirm': LucideIcons.checkCircle2,
    'reject': LucideIcons.xCircle,
    'close': LucideIcons.xCircle,
    'cancel': LucideIcons.xCircle,
    'snooze': LucideIcons.clock3,
    'clock': LucideIcons.clock3,
    'later': LucideIcons.clock3,
    'delete': LucideIcons.trash2,
    'trash': LucideIcons.trash2,
    'review': LucideIcons.eye,
    'skip': LucideIcons.skipForward,
    'prioritize': LucideIcons.arrowUp,
    'backlog': LucideIcons.archive,
    'send': LucideIcons.send,
    'star': LucideIcons.star,
  };
}

class _ActionItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool destructive;
  final VoidCallback? onTap;

  const _ActionItem({
    required this.label,
    required this.icon,
    this.destructive = false,
    this.onTap,
  });

  @override
  State<_ActionItem> createState() => _ActionItemState();
}

class _ActionItemState extends State<_ActionItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.destructive
        ? context.colors.error
        : context.colors.onSurfaceVariant;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 80),
        opacity: _pressed ? 0.35 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 24, color: color),
            const SizedBox(height: 6),
            Text(
              widget.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.1,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
