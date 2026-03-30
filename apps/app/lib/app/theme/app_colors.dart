import 'package:flutter/material.dart';

abstract final class AppColors {
  // Ink palette — near-black with warm undertone
  static const ink = Color(0xFF111111);
  static const inkMuted = Color(0xFF3A3A3C);
  static const inkFaint = Color(0xFF8A8A8E);

  // Paper palette
  static const paper = Color(0xFFFAFAFA);
  static const paperWarm = Color(0xFFF2F0ED);
  static const surface = Color(0xFFFFFFFF);

  // Accent — single, intentional
  static const accent = Color(0xFF0A84FF);
  static const accentSoft = Color(0x140A84FF);

  // Semantic
  static const destructive = Color(0xFFFF453A);
  static const success = Color(0xFF30D158);
  static const warning = Color(0xFFFFD60A);

  // Structural
  static const divider = Color(0xFFE8E6E3);
  static const cardBorder = Color(0xFFEDEBE8);

  // Shadows
  static const shadow1 = Color(0x08000000);
  static const shadow2 = Color(0x12000000);
  static const shadow3 = Color(0x1E000000);
}
