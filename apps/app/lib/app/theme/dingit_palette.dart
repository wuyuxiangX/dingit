import 'package:flutter/material.dart';

import 'tokens/app_tokens.dart';

/// Brand/editorial colors that Material 3 has no semantic slot for.
///
/// Boundary rule: *if Material 3 names it, it belongs on [ColorScheme]; if
/// the designer named it, it belongs here*. Consumers access these via
/// `context.palette` (see `theme_context_ext.dart`).
///
/// Registered on [ThemeData.extensions] by `AppTheme.light` / `AppTheme.dark`.
class DingitPalette extends ThemeExtension<DingitPalette> {
  const DingitPalette({
    required this.inkFaint,
    required this.accentSoft,
    required this.success,
    required this.warning,
    required this.shadow1,
    required this.shadow2,
    required this.shadow3,
  });

  /// Three-step text hierarchy's faintest stop. M3's
  /// `onSurfaceVariant` is the second step; anything lighter lives here.
  final Color inkFaint;

  /// Translucent brand blue — soft CTA backgrounds (chip fill, badge bg).
  final Color accentSoft;

  /// Semantic green. M3 only defines [ColorScheme.error]; success/warning
  /// are brand decisions.
  final Color success;
  final Color warning;

  /// Layered shadows. Light mode uses three elevation steps; dark mode
  /// collapses these to fully transparent and leans on surface-tint
  /// contrast instead (per M3 dark-elevation spec).
  final Color shadow1;
  final Color shadow2;
  final Color shadow3;

  // ── Factories ──────────────────────────────────────────────────────────

  factory DingitPalette.light() => const DingitPalette(
        inkFaint: AppTokens.inkFaint,
        accentSoft: AppTokens.accentSoft,
        success: AppTokens.success,
        warning: AppTokens.warning,
        shadow1: AppTokens.shadow1,
        shadow2: AppTokens.shadow2,
        shadow3: AppTokens.shadow3,
      );

  factory DingitPalette.dark() => const DingitPalette(
        inkFaint: AppTokens.inkFaintDark,
        accentSoft: AppTokens.accentSoftDark,
        success: AppTokens.successDark,
        warning: AppTokens.warningDark,
        // Dark mode: shadows disappear, elevation comes from surface tint.
        shadow1: AppTokens.shadowNone,
        shadow2: AppTokens.shadowNone,
        shadow3: AppTokens.shadowNone,
      );

  // ── ThemeExtension plumbing ────────────────────────────────────────────

  @override
  DingitPalette copyWith({
    Color? inkFaint,
    Color? accentSoft,
    Color? success,
    Color? warning,
    Color? shadow1,
    Color? shadow2,
    Color? shadow3,
  }) {
    return DingitPalette(
      inkFaint: inkFaint ?? this.inkFaint,
      accentSoft: accentSoft ?? this.accentSoft,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      shadow1: shadow1 ?? this.shadow1,
      shadow2: shadow2 ?? this.shadow2,
      shadow3: shadow3 ?? this.shadow3,
    );
  }

  @override
  DingitPalette lerp(ThemeExtension<DingitPalette>? other, double t) {
    if (other is! DingitPalette) return this;
    return DingitPalette(
      inkFaint: Color.lerp(inkFaint, other.inkFaint, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      shadow1: Color.lerp(shadow1, other.shadow1, t)!,
      shadow2: Color.lerp(shadow2, other.shadow2, t)!,
      shadow3: Color.lerp(shadow3, other.shadow3, t)!,
    );
  }
}
