import 'package:flutter/material.dart';

/// Raw color tokens — brightness-agnostic primitives.
///
/// These are the only place in the codebase that should contain `Color(0x...)`
/// literals. Everything else (ColorScheme, DingitPalette, widgets) must
/// reference these constants so the design system has a single source of
/// truth.
///
/// Naming convention: `<hue><weight>` where weight follows a loose 50/100/…/900
/// scale (higher = darker for neutrals, more saturated for accents). `Dark`
/// suffixed tokens are the dark-mode counterparts only — they exist so dark
/// mode doesn't have to invent its own literals.
///
/// Do NOT import this file from widgets. Import `dingit_palette.dart` or read
/// from `Theme.of(context).colorScheme` instead.
class AppTokens {
  AppTokens._();

  // ── Neutral — light ────────────────────────────────────────────────────
  /// Near-black text/primary in light mode.
  static const ink = Color(0xFF111111);
  /// Secondary text in light mode.
  static const inkMuted = Color(0xFF3A3A3C);
  /// Tertiary text / faint chrome in light mode.
  static const inkFaint = Color(0xFF8A8A8E);

  /// Scaffold background in light mode (coolest surface).
  static const paper = Color(0xFFFAFAFA);
  /// Warm container surface (settings pages, detail page scaffold).
  static const paperWarm = Color(0xFFF2F0ED);
  /// Elevated surface (cards, sheets) in light mode.
  static const surface = Color(0xFFFFFFFF);

  static const divider = Color(0xFFE8E6E3);
  static const cardBorder = Color(0xFFEDEBE8);

  // ── Neutral — dark ─────────────────────────────────────────────────────
  /// Primary text in dark mode.
  static const inkDark = Color(0xFFFFFFFF);
  /// Secondary text in dark mode.
  static const inkMutedDark = Color(0xFFE5E5EA);
  /// Tertiary text / faint chrome in dark mode.
  static const inkFaintDark = Color(0xFFB0B0B5);

  /// Scaffold background in dark mode.
  static const paperDark = Color(0xFF0B0B0B);
  /// Container surface (settings scaffold, warm regions) in dark mode.
  static const paperWarmDark = Color(0xFF151517);
  /// Elevated surface (cards, sheets) in dark mode.
  static const surfaceDark = Color(0xFF1C1C1E);

  static const dividerDark = Color(0x1FFFFFFF);
  static const cardBorderDark = Color(0x14FFFFFF);

  // ── Brand accent ───────────────────────────────────────────────────────
  /// Brand blue — used for CTAs, selected states, active icons.
  static const accent = Color(0xFF0A84FF);
  /// Dark-mode brand blue — slightly brighter so contrast stays ≥ 4.5:1 on
  /// `paperDark`. Matches Apple's dark-mode system blue.
  static const accentDark = Color(0xFF2E9BFF);
  /// Semi-transparent brand accent used for soft CTA backgrounds.
  static const accentSoft = Color(0x140A84FF);
  static const accentSoftDark = Color(0x292E9BFF);

  // ── Semantic ───────────────────────────────────────────────────────────
  static const destructive = Color(0xFFFF453A);
  static const destructiveDark = Color(0xFFFF6961);
  static const success = Color(0xFF30D158);
  static const successDark = Color(0xFF32D74B);
  static const warning = Color(0xFFFFD60A);
  static const warningDark = Color(0xFFFFD426);

  // ── Shadows (light mode only — dark mode uses surface tint instead) ────
  static const shadow1 = Color(0x08000000);
  static const shadow2 = Color(0x12000000);
  static const shadow3 = Color(0x1E000000);
  static const shadowNone = Color(0x00000000);
}
