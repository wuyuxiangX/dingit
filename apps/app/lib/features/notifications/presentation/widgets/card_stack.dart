import 'dart:math';

import 'package:flutter/material.dart';
import 'package:notify_shared/notify_shared.dart';

import 'notification_card.dart';

class CardStack extends StatefulWidget {
  final List<NotificationModel> notifications;
  final void Function(NotificationModel notification, String action) onAction;
  final void Function(NotificationModel notification) onDismiss;
  final void Function()? onNext;

  const CardStack({
    super.key,
    required this.notifications,
    required this.onAction,
    required this.onDismiss,
    this.onNext,
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

  static const _maxVisibleCards = 3;
  static const _cardVerticalOffset = 12.0;
  static const _cardScaleDecrement = 0.05;
  static const _swipeThreshold = 100.0;

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
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    setState(() {
      _dragOffset += details.delta;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;

    if (_dragOffset.dx.abs() > _swipeThreshold) {
      _animateSwipeAway(_dragOffset.dx > 0);
    } else {
      _animateSnapBack();
    }
  }

  void _animateSwipeAway(bool toRight) {
    final screenWidth = MediaQuery.of(context).size.width;
    final targetX = toRight ? screenWidth * 1.5 : -screenWidth * 1.5;

    _slideAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset(targetX, _dragOffset.dy),
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: _dragOffset.dx * 0.001,
      end: (toRight ? 1 : -1) * 0.3,
    ).animate(_animController);

    _animController.forward(from: 0).then((_) {
      if (widget.notifications.isNotEmpty) {
        final topNotification = widget.notifications.first;
        if (toRight) {
          // Swipe right = complete with first action
          if (topNotification.actions.isNotEmpty) {
            widget.onAction(topNotification, topNotification.actions.first.value);
          }
        } else {
          // Swipe left = dismiss
          widget.onDismiss(topNotification);
        }
      }
      setState(() {
        _dragOffset = Offset.zero;
        _slideAnimation = null;
        _rotationAnimation = null;
      });
      _animController.reset();
    });
  }

  void _animateSnapBack() {
    _slideAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: _dragOffset.dx * 0.001,
      end: 0,
    ).animate(_animController);

    _animController.forward(from: 0).then((_) {
      setState(() {
        _dragOffset = Offset.zero;
        _slideAnimation = null;
        _rotationAnimation = null;
      });
      _animController.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none_rounded,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No notifications',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade400,
                  ),
            ),
          ],
        ),
      );
    }

    final visibleCount = min(_maxVisibleCards, widget.notifications.length);

    return AnimatedBuilder2(
      listenable: _animController,
      builder: (context, _) {
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            for (int i = visibleCount - 1; i >= 0; i--)
              _buildCard(i, visibleCount),
          ],
        );
      },
    );
  }

  Widget _buildCard(int index, int visibleCount) {
    final isTop = index == 0;
    final scale = 1.0 - (index * _cardScaleDecrement);
    final yOffset = index * _cardVerticalOffset;

    Offset offset;
    double rotation;

    if (isTop) {
      offset = _slideAnimation?.value ?? _dragOffset;
      rotation = _rotationAnimation?.value ?? _dragOffset.dx * 0.001;
    } else {
      // Subtle movement for cards behind
      final progress = min(1.0, _dragOffset.dx.abs() / _swipeThreshold);
      final nextScale = scale + (_cardScaleDecrement * progress);
      final nextY = yOffset - (_cardVerticalOffset * progress);

      return Transform.translate(
        offset: Offset(0, nextY),
        child: Transform.scale(
          scale: nextScale,
          alignment: Alignment.topCenter,
          child: Opacity(
            opacity: index == visibleCount - 1 ? 0.5 + (0.5 * progress) : 1.0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: NotificationCard(
                notification: widget.notifications[index],
                stackIndex: index,
                totalCards: visibleCount,
              ),
            ),
          ),
        ),
      );
    }

    return Transform.translate(
      offset: Offset(offset.dx, yOffset + offset.dy * 0.3),
      child: Transform.rotate(
        angle: rotation,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onPanStart: isTop ? _onPanStart : null,
            onPanUpdate: isTop ? _onPanUpdate : null,
            onPanEnd: isTop ? _onPanEnd : null,
            child: Opacity(
              opacity: isTop
                  ? 1.0 - (min(_dragOffset.dx.abs(), _swipeThreshold) / _swipeThreshold * 0.15)
                  : 1.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: NotificationCard(
                  notification: widget.notifications[index],
                  stackIndex: index,
                  totalCards: visibleCount,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedBuilder2 extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;

  const AnimatedBuilder2({
    super.key,
    required super.listenable,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) => builder(context, null);
}
