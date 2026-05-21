// Light (UMKM) and dark (Mitra/Admin) themes for the Polarna app.

import 'package:flutter/material.dart';

import 'app_tokens.dart';
import 'app_typography.dart';

/// Factory class — never instantiated.
class AppTheme {
  AppTheme._();

  /// UMKM light theme — clean white surfaces, navy text, cyan accents.
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surfaceLight,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.textPrimaryLight,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      textTheme: buildTextTheme(
        AppColors.textPrimaryLight,
        AppColors.textSecondaryLight,
      ),
      inputDecorationTheme: _inputTheme(
        fillColor: AppColors.surfaceLight,
        borderColor: AppColors.borderLight,
        focusColor: AppColors.primary,
      ),
      filledButtonTheme: _filledButtonTheme(
        bgColor: AppColors.primary,
        fgColor: Colors.white,
      ),
      outlinedButtonTheme: _outlinedButtonTheme(AppColors.primary),
      textButtonTheme: _textButtonTheme(AppColors.primary),
      cardTheme: _cardTheme(),
      appBarTheme: _appBarTheme(
        bg: AppColors.surfaceLight,
        fg: AppColors.textPrimaryLight,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
        space: 0,
      ),
    );
  }

  /// Mitra dark theme — deep navy bg, cyan glow CTAs, teal highlights.
  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
      primary: AppColors.accent,
      secondary: AppColors.accentAlt,
      surface: AppColors.surfaceDark,
      error: AppColors.error,
      onPrimary: AppColors.primary,
      onSecondary: Colors.white,
      onSurface: AppColors.textPrimaryDark,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      textTheme: buildTextTheme(
        AppColors.textPrimaryDark,
        AppColors.textSecondaryDark,
      ),
      inputDecorationTheme: _inputTheme(
        fillColor: AppColors.surfaceDark,
        borderColor: AppColors.borderDark,
        focusColor: AppColors.accent,
      ),
      filledButtonTheme: _filledButtonTheme(
        bgColor: AppColors.accent,
        fgColor: AppColors.primary,
      ),
      outlinedButtonTheme: _outlinedButtonTheme(AppColors.accent),
      textButtonTheme: _textButtonTheme(AppColors.accent),
      cardTheme: _cardTheme(color: AppColors.surfaceDark),
      appBarTheme: _appBarTheme(
        bg: AppColors.backgroundDark,
        fg: AppColors.textPrimaryDark,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderDark,
        thickness: 1,
        space: 0,
      ),
    );
  }

  // --- Private theme builders -------------------------------------------

  static InputDecorationTheme _inputTheme({
    required Color fillColor,
    required Color borderColor,
    required Color focusColor,
  }) {
    OutlineInputBorder border(Color color, {double width = 1}) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md + 2,
      ),
      enabledBorder: border(borderColor),
      focusedBorder: border(focusColor, width: 1.5),
      errorBorder: border(AppColors.error),
      focusedErrorBorder: border(AppColors.error, width: 1.5),
      disabledBorder: border(borderColor.withValues(alpha: 0.5)),
      hintStyle: AppTextStyles.bodyRegular.copyWith(
        color: AppColors.textSecondaryLight.withValues(alpha: 0.6),
      ),
    );
  }

  static FilledButtonThemeData _filledButtonTheme({
    required Color bgColor,
    required Color fgColor,
  }) {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: fgColor,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
        textStyle: AppTextStyles.bodyLarge.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme(Color color) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size.fromHeight(50),
        side: BorderSide(color: color, width: 1.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
        textStyle: AppTextStyles.bodyLarge.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme(Color color) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: color,
        textStyle: AppTextStyles.bodyRegular.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static CardThemeData _cardTheme({Color? color}) {
    return CardThemeData(
      color: color,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      margin: EdgeInsets.zero,
    );
  }

  static AppBarTheme _appBarTheme({required Color bg, required Color fg}) {
    return AppBarTheme(
      backgroundColor: bg,
      foregroundColor: fg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: AppTextStyles.heading3.copyWith(color: fg),
      iconTheme: IconThemeData(color: fg),
    );
  }
}
