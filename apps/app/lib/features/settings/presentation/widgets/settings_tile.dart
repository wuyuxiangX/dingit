import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/theme_context_ext.dart';

/// Shared Settings widgets + text styles.
///
/// These used to live as private `_Foo` types inside `settings_page.dart`.
/// They got promoted to `SettingsFoo` so the new `appearance_page.dart` and
/// `language_page.dart` sub-pages can reuse them and keep visual parity with
/// the main Settings page.

// ── Text styles ────────────────────────────────────────────────────────

TextStyle settingsLabelStyle(BuildContext context) =>
    GoogleFonts.plusJakartaSans(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: context.colors.onSurface,
    );

TextStyle settingsHintStyle(BuildContext context) =>
    GoogleFonts.plusJakartaSans(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: context.palette.inkFaint,
    );

TextStyle settingsSectionTitleStyle(BuildContext context) =>
    GoogleFonts.plusJakartaSans(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: context.palette.inkFaint,
    );

// ── Section title ──────────────────────────────────────────────────────

class SettingsSectionTitle extends StatelessWidget {
  final String title;
  const SettingsSectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Text(title, style: settingsSectionTitleStyle(context)),
    );
  }
}

// ── Grouped card container ─────────────────────────────────────────────

class SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const SettingsCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: palette.shadow1,
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

// ── Indented divider inside card ───────────────────────────────────────

class SettingsTileDivider extends StatelessWidget {
  const SettingsTileDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Divider(
        height: 0.5,
        thickness: 0.5,
        color: context.colors.outlineVariant,
      ),
    );
  }
}

// ── Tappable action tile ───────────────────────────────────────────────

class SettingsActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  final Widget? trailing;
  final Color? iconColor;
  final Color? labelColor;

  const SettingsActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLoading = false,
    this.trailing,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final ic = iconColor ?? context.colors.onSurface;
    final lc = labelColor ?? context.colors.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: isLoading
                      ? SizedBox(
                          key: const ValueKey('spin'),
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: ic,
                          ),
                        )
                      : Icon(
                          icon,
                          key: const ValueKey('icon'),
                          size: 18,
                          color: ic,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: lc,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

// ── Disclosure trailing ────────────────────────────────────────────────

/// Trailing widget for a "push-into-sub-page" tile: shows the currently
/// selected value in faint text, followed by a chevron. Use this as the
/// `trailing` of a [SettingsActionTile] so the tile reads e.g.
/// `🎨 Appearance              Dark  ›`.
class SettingsDisclosureValue extends StatelessWidget {
  final String value;
  const SettingsDisclosureValue(this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: palette.inkFaint,
          ),
        ),
        const SizedBox(width: 6),
        Icon(
          Icons.chevron_right_rounded,
          size: 20,
          color: palette.inkFaint,
        ),
      ],
    );
  }
}
