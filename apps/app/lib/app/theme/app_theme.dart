import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  // Display font — editorial, high contrast
  static final _displayFont = GoogleFonts.dmSerifDisplay;
  // Body font — clean, highly legible
  static final _bodyFont = GoogleFonts.plusJakartaSans;

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.light(
          primary: AppColors.ink,
          secondary: AppColors.inkMuted,
          surface: AppColors.surface,
          error: AppColors.destructive,
        ),
        scaffoldBackgroundColor: AppColors.paper,
        textTheme: TextTheme(
          // Page title — serif, editorial feel
          headlineLarge: _displayFont(
            fontSize: 32,
            fontWeight: FontWeight.w400,
            color: AppColors.ink,
            height: 1.1,
          ),
          // Card title
          titleLarge: _bodyFont(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            height: 1.25,
            letterSpacing: -0.3,
          ),
          // Card subtitle / source
          titleSmall: _bodyFont(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.inkFaint,
            letterSpacing: 1.2,
          ),
          // Card body
          bodyLarge: _bodyFont(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: AppColors.inkMuted,
            height: 1.6,
            letterSpacing: 0.1,
          ),
          // Secondary text
          bodyMedium: _bodyFont(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.inkFaint,
            height: 1.4,
          ),
          // Labels / date tags / button labels
          labelMedium: _bodyFont(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.inkFaint,
            letterSpacing: 0.8,
          ),
          // Small meta
          labelSmall: _bodyFont(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: AppColors.inkFaint,
            letterSpacing: 0.6,
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.paper,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          titleTextStyle: _displayFont(
            fontSize: 24,
            fontWeight: FontWeight.w400,
            color: AppColors.ink,
          ),
          iconTheme: const IconThemeData(color: AppColors.ink, size: 20),
        ),
      );

  // Dark theme — only fully styled for Scaffold chrome and text; individual
  // pages still hard-code AppColors.xxx and will render in light colors for
  // now. The UndoPill is already theme-aware. Full dark migration for the
  // notification card stack and settings surfaces is a follow-up.
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          secondary: Color(0xFFB0B0B5),
          surface: Color(0xFF1C1C1E),
          error: AppColors.destructive,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B0B0B),
        textTheme: TextTheme(
          headlineLarge: _displayFont(
            fontSize: 32,
            fontWeight: FontWeight.w400,
            color: Colors.white,
            height: 1.1,
          ),
          titleLarge: _bodyFont(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.25,
            letterSpacing: -0.3,
          ),
          titleSmall: _bodyFont(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFB0B0B5),
            letterSpacing: 1.2,
          ),
          bodyLarge: _bodyFont(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: const Color(0xFFE5E5EA),
            height: 1.6,
            letterSpacing: 0.1,
          ),
          bodyMedium: _bodyFont(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFFB0B0B5),
            height: 1.4,
          ),
          labelMedium: _bodyFont(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFB0B0B5),
            letterSpacing: 0.8,
          ),
          labelSmall: _bodyFont(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: const Color(0xFFB0B0B5),
            letterSpacing: 0.6,
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF0B0B0B),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          titleTextStyle: _displayFont(
            fontSize: 24,
            fontWeight: FontWeight.w400,
            color: Colors.white,
          ),
          iconTheme: const IconThemeData(color: Colors.white, size: 20),
        ),
      );
}
