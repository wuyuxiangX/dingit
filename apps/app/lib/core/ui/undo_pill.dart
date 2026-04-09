import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../app/theme/app_colors.dart';

/// Show a dismissible bottom-center pill with an optional undo action.
///
/// The pill self-removes after [duration] or when the undo button is tapped.
/// Only one pill is visible at a time — calling this while another pill is
/// live replaces the old one (the same contract as
/// `ScaffoldMessenger.removeCurrentSnackBar + showSnackBar`).
///
/// The pill is rendered through the root [Overlay] so it floats above any
/// scaffold chrome. Colors are picked from `Theme.of(context).brightness`:
///
/// * Light: white surface + ink text + blue accent "撤销"
/// * Dark:  ink surface + white text + blue accent "撤销"
///
/// Pass [icon] / [iconColor] to switch to an error or warning variant,
/// e.g. `icon: LucideIcons.alertCircle, iconColor: Theme.of(context).colorScheme.error`.
///
/// [undoLabel] + [onUndo] must be provided together (or both omitted) —
/// when omitted, the divider and action button are hidden and the pill
/// becomes a pure status toast.
void showUndoPill(
  BuildContext context, {
  required String message,
  String? undoLabel,
  VoidCallback? onUndo,
  IconData icon = LucideIcons.check,
  Color? iconColor,
  Duration duration = const Duration(seconds: 4),
}) {
  assert(
    (undoLabel == null) == (onUndo == null),
    'undoLabel and onUndo must be provided together',
  );

  // Tear down any previous pill before showing the new one.
  _currentEntry?.remove();
  _currentEntry = null;

  final overlay = Overlay.of(context, rootOverlay: true);
  final isDark = Theme.of(context).brightness == Brightness.dark;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _UndoPillOverlay(
      message: message,
      undoLabel: undoLabel,
      onUndo: onUndo,
      icon: icon,
      iconColor: iconColor,
      duration: duration,
      isDark: isDark,
      onFinished: () {
        entry.remove();
        if (identical(_currentEntry, entry)) {
          _currentEntry = null;
        }
      },
    ),
  );
  _currentEntry = entry;
  overlay.insert(entry);
}

// Single live pill at any time — matches Material SnackBar semantics.
OverlayEntry? _currentEntry;

// ─────────────────────────────────────────────────────────────────────────

class _UndoPillOverlay extends StatefulWidget {
  final String message;
  final String? undoLabel;
  final VoidCallback? onUndo;
  final IconData icon;
  final Color? iconColor;
  final Duration duration;
  final bool isDark;
  final VoidCallback onFinished;

  const _UndoPillOverlay({
    required this.message,
    required this.undoLabel,
    required this.onUndo,
    required this.icon,
    required this.iconColor,
    required this.duration,
    required this.isDark,
    required this.onFinished,
  });

  @override
  State<_UndoPillOverlay> createState() => _UndoPillOverlayState();
}

class _UndoPillOverlayState extends State<_UndoPillOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..forward();
    _timer = Timer(widget.duration, _close);
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    if (!mounted) {
      widget.onFinished();
      return;
    }
    await _ctl.reverse();
    widget.onFinished();
  }

  void _handleUndo() {
    widget.onUndo?.call();
    _close();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final pillColor = isDark ? AppColors.ink : AppColors.surface;
    final textColor = isDark ? Colors.white : AppColors.ink;
    final defaultIconColor = isDark ? Colors.white : AppColors.inkMuted;
    final dividerColor = isDark ? Colors.white24 : AppColors.divider;
    final border = isDark ? null : Border.all(color: AppColors.cardBorder);
    final shadows = <BoxShadow>[
      BoxShadow(
        color: isDark ? AppColors.shadow3 : AppColors.shadow2,
        blurRadius: isDark ? 24 : 28,
        offset: const Offset(0, 8),
      ),
    ];
    final hasUndo = widget.undoLabel != null && widget.onUndo != null;

    return Positioned.fill(
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: AnimatedBuilder(
              animation: _ctl,
              builder: (_, child) {
                final t = _ctl.value.clamp(0.0, 1.0);
                final slideT = Curves.easeOutCubic.transform(t);
                return Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, (1 - slideT) * 24),
                    child: child,
                  ),
                );
              },
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: pillColor,
                    borderRadius: BorderRadius.circular(999),
                    border: border,
                    boxShadow: shadows,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.icon,
                        size: 16,
                        color: widget.iconColor ?? defaultIconColor,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.message,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (hasUndo) ...[
                        const SizedBox(width: 14),
                        Container(
                          width: 1,
                          height: 14,
                          color: dividerColor,
                        ),
                        const SizedBox(width: 14),
                        GestureDetector(
                          onTap: _handleUndo,
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            widget.undoLabel!,
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
