// Typography scale — uses Flutter's default Roboto font family to keep the
// app lightweight (no google_fonts dependency).

import 'package:flutter/material.dart';

/// Canonical text styles used across the app. Mirrors the Polarna design
/// system guide (24/20/16/16/14/12/12).
class AppTextStyles {
  AppTextStyles._();

  static const TextStyle heading1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );
  static const TextStyle heading2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );
  static const TextStyle heading3 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );
  static const TextStyle bodyRegular = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );
  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.5,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );
}

/// Builds a Material 3 [TextTheme] using [AppTextStyles] coloured for the
/// active brightness. Slot mapping:
///   - displayLarge   → heading1
///   - headlineMedium → heading2
///   - titleLarge     → heading3
///   - bodyLarge      → bodyLarge
///   - bodyMedium     → bodyRegular
///   - labelMedium    → labelMedium
///   - bodySmall      → caption
TextTheme buildTextTheme(Color primary, Color secondary) {
  return TextTheme(
    displayLarge: AppTextStyles.heading1.copyWith(color: primary),
    headlineMedium: AppTextStyles.heading2.copyWith(color: primary),
    titleLarge: AppTextStyles.heading3.copyWith(color: primary),
    bodyLarge: AppTextStyles.bodyLarge.copyWith(color: primary),
    bodyMedium: AppTextStyles.bodyRegular.copyWith(color: primary),
    labelMedium: AppTextStyles.labelMedium.copyWith(color: secondary),
    bodySmall: AppTextStyles.caption.copyWith(color: secondary),
  );
}
