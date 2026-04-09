import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Show a dismissible bottom-center pill with an optional undo action.
///
/// Visual style: **iOS HUD** — always a dark translucent pill with
/// backdrop blur ("frosted glass"), regardless of the app's light/dark
/// theme. This is intentional:
///
/// * iOS system HUDs (volume overlay, AirDrop success), Apple Maps toasts,
///   Safari "Added to Bookmarks", and Instagram's "Copied to clipboard"
///   all use the same dark-frosted-glass recipe.
/// * The pill is a short-lived *notification layer*, not a part of the
///   page's chrome — it should pop out, not blend in.
/// * Fixed colors sidestep the "white pill on white page" / "black pill
///   on black page" readability problem entirely.
///
/// The pill self-removes after [duration] or when the undo button is
/// tapped. Only one pill is visible at a time — calling this while
/// another pill is live replaces the old one (same contract as
/// `ScaffoldMessenger.removeCurrentSnackBar + showSnackBar`).
///
/// Pass [icon] / [iconColor] to switch to an error or warning variant —
/// only the icon changes color; the pill background, text, and layout
/// stay HUD-style.
///
/// [undoLabel] + [onUndo] must be provided together (or both omitted) —
/// when omitted, the divider and action button are hidden and the pill
/// becomes a pure status HUD.
///
/// [bottomPadding] is the distance (inside SafeArea) between the pill's
/// bottom edge and the bottom of the screen. Pages with their own fixed
/// bottom chrome (e.g. NotificationPage's ActionBar) should pass a value
/// large enough to float above that chrome.
void showUndoPill(
  BuildContext context, {
  required String message,
  String? undoLabel,
  VoidCallback? onUndo,
  IconData icon = LucideIcons.check,
  Color? iconColor,
  Duration duration = const Duration(seconds: 4),
  double bottomPadding = 20,
}) {
  assert(
    (undoLabel == null) == (onUndo == null),
    'undoLabel and onUndo must be provided together',
  );

  // Tear down any previous pill before showing the new one.
  _currentEntry?.remove();
  _currentEntry = null;

  final overlay = Overlay.of(context, rootOverlay: true);

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _UndoPillOverlay(
      message: message,
      undoLabel: undoLabel,
      onUndo: onUndo,
      icon: icon,
      iconColor: iconColor,
      duration: duration,
      bottomPadding: bottomPadding,
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

// ── Fixed HUD palette (theme-independent) ──────────────────────────────
//
// These constants intentionally do NOT read from `Theme.of(context)`.
// The HUD must look the same whether the app is in light or dark mode.

/// Translucent dark fill that the backdrop blur sits behind. 72% opaque
/// over a 24-level-dark base gives enough contrast against a white
/// scaffold AND against a near-black scaffold.
const _kPillFill = Color(0xB81C1C1E);
const _kPillBorder = Color(0x14FFFFFF);
const _kPillText = Color(0xFFFFFFFF);
const _kPillIcon = Color(0xFFFFFFFF);
const _kPillDivider = Color(0x33FFFFFF);
/// Apple's dark-mode system blue — works as an accent on a dark pill
/// regardless of the page behind it.
const _kPillAccent = Color(0xFF2E9BFF);
const _kPillShadow = Color(0x59000000);

// ─────────────────────────────────────────────────────────────────────────

class _UndoPillOverlay extends StatefulWidget {
  final String message;
  final String? undoLabel;
  final VoidCallback? onUndo;
  final IconData icon;
  final Color? iconColor;
  final Duration duration;
  final double bottomPadding;
  final VoidCallback onFinished;

  const _UndoPillOverlay({
    required this.message,
    required this.undoLabel,
    required this.onUndo,
    required this.icon,
    required this.iconColor,
    required this.duration,
    required this.bottomPadding,
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
    final hasUndo = widget.undoLabel != null && widget.onUndo != null;

    return Positioned.fill(
      child: IgnorePointer(
        // Only the undo action button should accept taps. The pill
        // itself should pass touches through to the page beneath so
        // the user can still interact with the app while a toast is
        // visible.
        ignoring: !hasUndo,
        child: SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: widget.bottomPadding),
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
                child: _PillBody(
                  message: widget.message,
                  icon: widget.icon,
                  iconColor: widget.iconColor,
                  undoLabel: widget.undoLabel,
                  onUndo: hasUndo ? _handleUndo : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PillBody extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color? iconColor;
  final String? undoLabel;
  final VoidCallback? onUndo;

  const _PillBody({
    required this.message,
    required this.icon,
    required this.iconColor,
    required this.undoLabel,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    final hasUndo = undoLabel != null && onUndo != null;

    // `ClipRRect` + `BackdropFilter` is the canonical Flutter recipe for
    // frosted-glass. The blur applies to whatever is painted below this
    // subtree in the current layer — because the pill lives in the root
    // Overlay, "below" is the actual page content.
    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: _kPillFill,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _kPillBorder, width: 0.5),
              boxShadow: const [
                BoxShadow(
                  color: _kPillShadow,
                  blurRadius: 28,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: iconColor ?? _kPillIcon,
                ),
                const SizedBox(width: 10),
                Text(
                  message,
                  style: const TextStyle(
                    color: _kPillText,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (hasUndo) ...[
                  const SizedBox(width: 14),
                  Container(
                    width: 1,
                    height: 14,
                    color: _kPillDivider,
                  ),
                  const SizedBox(width: 14),
                  GestureDetector(
                    onTap: onUndo,
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      undoLabel!,
                      style: const TextStyle(
                        color: _kPillAccent,
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
    );
  }
}
