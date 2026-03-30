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
}
