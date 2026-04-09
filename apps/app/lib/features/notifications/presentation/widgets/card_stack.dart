import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:dingit_shared/dingit_shared.dart';

import '../../../../app/locale/locale_context_ext.dart';
import '../../../../app/theme/theme_context_ext.dart';
import 'notification_card.dart';

class CardStack extends StatefulWidget {
  final List<NotificationModel> notifications;
  final void Function(NotificationModel notification, String action) onAction;
  final void Function(NotificationModel notification) onDismiss;
  final void Function(NotificationModel notification)? onTap;

  const CardStack({
    super.key,
    required this.notifications,
    required this.onAction,
    required this.onDismiss,
    this.onTap,
  });

  @override
  State<CardStack> createState() => _CardStackState();
}

class _CardStackState extends State<CardStack>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  Animation<Offset>? _slideAnimation;
  Animation<double>? _rotationAnimation;
  bool _isDragging = false;
  Offset _dragOffset = Offset.zero;
  // Captured at _onPanStart so that the animation completion callback operates
  // on the card the user actually started dragging, even if `widget.notifications`
  // mutates mid-animation (e.g. a new notification arrives via WebSocket).
  NotificationModel? _draggingCard;

  static const _maxVisible = 3;
  static const _swipeThreshold = 100.0;
  static const _peekHeight = 12.0;
  static const _narrowPerCard = 6.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    _isDragging = true;
    _dragOffset = Offset.zero;
    _draggingCard = widget.notifications.isNotEmpty
        ? widget.notifications.first
        : null;
    HapticFeedback.selectionClick();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    setState(() => _dragOffset += details.delta);
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;

    final velocity = details.velocity.pixelsPerSecond.dx;
    final isHighSpeedFling = velocity.abs() > 800.0;

    if (_dragOffset.dx.abs() > _swipeThreshold ||
        (isHighSpeedFling && _dragOffset.dx.abs() > 30)) {
      _animateSwipeAway(_dragOffset.dx > 0);
    } else {
      _animateSnapBack();
    }
  }

  void _animateSwipeAway(bool toRight) {
    HapticFeedback.lightImpact();

    final screenWidth = MediaQuery.sizeOf(context).width;
    final targetX = toRight ? screenWidth * 1.5 : -screenWidth * 1.5;

    _slideAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset(targetX, _dragOffset.dy),
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _rotationAnimation = Tween<double>(
      begin: _dragOffset.dx * 0.0008,
      end: (toRight ? 1 : -1) * 0.15,
    ).animate(_animController);

    _animController.forward(from: 0).then((_) {
      // Use the card captured in _onPanStart — NOT widget.notifications.first —
      // otherwise a notification that arrived mid-animation could be dismissed
      // instead of the one the user swiped. Both left and right swipes map to
      // dismiss so users never trigger a hidden action by accident.
      final card = _draggingCard;
      if (card != null) {
        widget.onDismiss(card);
      }
      _reset();
    });
  }

  void _animateSnapBack() {
    _slideAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _rotationAnimation = Tween<double>(
      begin: _dragOffset.dx * 0.0008,
      end: 0,
    ).animate(_animController);

    _animController.forward(from: 0).then((_) => _reset());
  }

  void _reset() {
    setState(() {
      _dragOffset = Offset.zero;
      _slideAnimation = null;
      _rotationAnimation = null;
    });
    _animController.reset();
    _draggingCard = null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.checkCircle2,
                size: 48, color: context.palette.success),
            const SizedBox(height: 16),
            Text(
              context.l10n.notificationEmptyTitle,
              style: context.typo.headlineLarge?.copyWith(fontSize: 28),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.notificationEmptyBody,
              style: context.typo.bodyMedium,
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => context.push('/history'),
              child: Text(
                context.l10n.notificationEmptyViewHistory,
                style: context.typo.bodyMedium?.copyWith(
                      color: context.colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      );
    }

    final count = min(_maxVisible, widget.notifications.length);
    final total = widget.notifications.length;

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxCardWidth = min(constraints.maxWidth, 420.0);
              final frontBottom = (_maxVisible - 1) * _peekHeight + 8;

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxCardWidth),
                  child: AnimatedBuilder(
                    animation: _animController,
                    builder: (context, _) {
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (int i = count - 1; i >= 0; i--)
                            _buildCard(i, count, frontBottom),
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '1',
                style: context.typo.labelMedium?.copyWith(
                      color: context.colors.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
              ),
              Text(
                ' / $total',
                style: context.typo.labelMedium?.copyWith(
                      color: context.palette.inkFaint,
                      fontSize: 13,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard(int index, int count, double frontBottom) {
    final isTop = index == 0;
    final dragProgress = min(1.0, _dragOffset.dx.abs() / _swipeThreshold);

    final hPad = 16.0 + (index * _narrowPerCard);
    final bottom = frontBottom - (index * _peekHeight);

    if (isTop) {
      final offset = _slideAnimation?.value ?? _dragOffset;
      final rotation = _rotationAnimation?.value ?? _dragOffset.dx * 0.0008;

      return Positioned(
        top: 0,
        left: hPad + offset.dx,
        right: hPad - offset.dx,
        bottom: bottom + offset.dy * 0.1,
        child: Transform.rotate(
          angle: rotation,
          child: GestureDetector(
            onTap: () => widget.onTap?.call(widget.notifications[index]),
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: NotificationCard(notification: widget.notifications[index]),
          ),
        ),
      );
    }

    final animHPad = hPad - (_narrowPerCard * dragProgress);
    final animBottom = bottom + (_peekHeight * dragProgress);
    final opacity = index == count - 1 ? 0.7 + (0.3 * dragProgress) : 1.0;

    return Positioned(
      top: 0,
      left: animHPad,
      right: animHPad,
      bottom: animBottom,
      child: Opacity(
        opacity: opacity,
        child: NotificationCard(notification: widget.notifications[index]),
      ),
    );
  }
}
