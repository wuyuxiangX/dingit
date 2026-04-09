import 'package:flutter/material.dart';

import 'dingit_palette.dart';

/// Concise theme accessors on [BuildContext].
///
/// Usage:
/// ```dart
/// Container(
///   color: context.colors.surface,
///   child: Text(label, style: context.typo.titleLarge?.copyWith(
///     color: context.palette.inkFaint,
///   )),
/// )
/// ```
extension DingitThemeContext on BuildContext {
  /// Material 3 color roles (primary, surface, onSurface, outline, error, …).
  ColorScheme get colors => Theme.of(this).colorScheme;

  /// Custom brand/editorial palette. Never null — `AppTheme` always
  /// registers it on both light and dark `ThemeData`.
  DingitPalette get palette => Theme.of(this).extension<DingitPalette>()!;

  /// Shortcut for `Theme.of(this).textTheme`.
  TextTheme get typo => Theme.of(this).textTheme;
}
