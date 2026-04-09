import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'dingit_palette.dart';
import 'tokens/app_tokens.dart';

/// Central theme factory. Both [light] and [dark] are built from the same
/// raw token table (see `tokens/app_tokens.dart`) and share the same
/// typographic helper so the two flavors can't drift.
abstract final class AppTheme {
  // Display font — editorial, high contrast.
  static final _displayFont = GoogleFonts.dmSerifDisplay;
  // Body font — clean, highly legible.
  static final _bodyFont = GoogleFonts.plusJakartaSans;

  // ── Public API ─────────────────────────────────────────────────────────

  static ThemeData get light {
    final scheme = _lightScheme;
    return _buildTheme(
      scheme: scheme,
      palette: DingitPalette.light(),
      scaffoldBackground: AppTokens.paper,
    );
  }

  static ThemeData get dark {
    final scheme = _darkScheme;
    return _buildTheme(
      scheme: scheme,
      palette: DingitPalette.dark(),
      scaffoldBackground: AppTokens.paperDark,
    );
  }

  // ── Color schemes ──────────────────────────────────────────────────────

  /// Hand-tuned light `ColorScheme`. We explicitly override every slot we
  /// care about instead of relying on `ColorScheme.fromSeed` so the
  /// editorial colors the designer picked are preserved byte-for-byte.
  static final _lightScheme = ColorScheme(
    brightness: Brightness.light,
    // Brand CTA — the blue in buttons, active chips, links.
    primary: AppTokens.accent,
    onPrimary: AppTokens.surface,
    primaryContainer: AppTokens.accentSoft,
    onPrimaryContainer: AppTokens.accent,
    // Secondary — near-black text, also used as "fill" for selected
    // monochrome elements (historically the `ink` color).
    secondary: AppTokens.ink,
    onSecondary: AppTokens.paper,
    secondaryContainer: AppTokens.paperWarm,
    onSecondaryContainer: AppTokens.ink,
    tertiary: AppTokens.inkMuted,
    onTertiary: AppTokens.paper,
    error: AppTokens.destructive,
    onError: AppTokens.surface,
    // Surfaces — three-step elevation.
    surface: AppTokens.surface,
    onSurface: AppTokens.ink,
    onSurfaceVariant: AppTokens.inkMuted,
    surfaceContainerLowest: AppTokens.paper,
    surfaceContainerLow: AppTokens.paper,
    surfaceContainer: AppTokens.paperWarm,
    surfaceContainerHigh: AppTokens.surface,
    surfaceContainerHighest: AppTokens.surface,
    outline: AppTokens.cardBorder,
    outlineVariant: AppTokens.divider,
    shadow: AppTokens.shadow3,
    // Inverse — used by SnackBar / undo pill variants.
    inverseSurface: AppTokens.ink,
    onInverseSurface: AppTokens.paper,
    inversePrimary: AppTokens.accentDark,
  );

  /// Hand-tuned dark `ColorScheme`. Dark primary is raised to `accentDark`
  /// so contrast vs `paperDark` clears WCAG AA.
  static final _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppTokens.accentDark,
    onPrimary: AppTokens.paperDark,
    primaryContainer: AppTokens.accentSoftDark,
    onPrimaryContainer: AppTokens.accentDark,
    secondary: AppTokens.inkDark,
    onSecondary: AppTokens.paperDark,
    secondaryContainer: AppTokens.surfaceDark,
    onSecondaryContainer: AppTokens.inkDark,
    tertiary: AppTokens.inkMutedDark,
    onTertiary: AppTokens.paperDark,
    error: AppTokens.destructiveDark,
    onError: AppTokens.paperDark,
    surface: AppTokens.surfaceDark,
    onSurface: AppTokens.inkDark,
    onSurfaceVariant: AppTokens.inkMutedDark,
    surfaceContainerLowest: AppTokens.paperDark,
    surfaceContainerLow: AppTokens.paperDark,
    surfaceContainer: AppTokens.paperWarmDark,
    surfaceContainerHigh: AppTokens.surfaceDark,
    surfaceContainerHighest: AppTokens.surfaceDark,
    outline: AppTokens.cardBorderDark,
    outlineVariant: AppTokens.dividerDark,
    shadow: AppTokens.shadowNone,
    inverseSurface: AppTokens.inkMutedDark,
    onInverseSurface: AppTokens.ink,
    inversePrimary: AppTokens.accent,
  );

  // ── Shared builders ────────────────────────────────────────────────────

  static ThemeData _buildTheme({
    required ColorScheme scheme,
    required DingitPalette palette,
    required Color scaffoldBackground,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBackground,
      extensions: [palette],
      textTheme: _buildTextTheme(scheme, palette),
      appBarTheme: _buildAppBarTheme(scheme, scaffoldBackground),
    );
  }

  /// One `TextTheme` builder, driven by the scheme/palette. Previously the
  /// light and dark flavors each duplicated ~40 lines of near-identical
  /// `TextStyle` boilerplate — a classic source of drift.
  static TextTheme _buildTextTheme(ColorScheme scheme, DingitPalette palette) {
    return TextTheme(
      // Page title — serif, editorial feel.
      headlineLarge: _displayFont(
        fontSize: 32,
        fontWeight: FontWeight.w400,
        color: scheme.onSurface,
        height: 1.1,
      ),
      // Card title.
      titleLarge: _bodyFont(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
        height: 1.25,
        letterSpacing: -0.3,
      ),
      // Card subtitle / source eyebrow.
      titleSmall: _bodyFont(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: palette.inkFaint,
        letterSpacing: 1.2,
      ),
      // Card body.
      bodyLarge: _bodyFont(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: scheme.onSurfaceVariant,
        height: 1.6,
        letterSpacing: 0.1,
      ),
      // Secondary text.
      bodyMedium: _bodyFont(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: palette.inkFaint,
        height: 1.4,
      ),
      // Labels / date tags / button labels.
      labelMedium: _bodyFont(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: palette.inkFaint,
        letterSpacing: 0.8,
      ),
      // Small meta.
      labelSmall: _bodyFont(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: palette.inkFaint,
        letterSpacing: 0.6,
      ),
    );
  }

  static AppBarTheme _buildAppBarTheme(ColorScheme scheme, Color bg) {
    return AppBarTheme(
      backgroundColor: bg,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: _displayFont(
        fontSize: 24,
        fontWeight: FontWeight.w400,
        color: scheme.onSurface,
      ),
      iconTheme: IconThemeData(color: scheme.onSurface, size: 20),
    );
  }
}
