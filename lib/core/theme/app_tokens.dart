// Design tokens for the Polarna app.
//
// Pure-data classes — no widgets, no logic. Every color, spacing, radius,
// duration and elevation used across the app is defined here so refactors
// stay mechanical and themes stay consistent.

import 'package:flutter/material.dart';

/// Brand and semantic colors. All values are opaque unless documented.
class AppColors {
  AppColors._();

  // --- Brand --------------------------------------------------------------
  static const Color primary = Color(0xFF1A3C50); // deep navy
  static const Color primaryLight = Color(0xFF2E5F8A); // medium navy
  static const Color accent = Color(0xFF00BCD4); // cyan CTA
  static const Color accentAlt = Color(0xFF4FB8AE); // teal highlight

  // --- Surfaces -----------------------------------------------------------
  static const Color backgroundLight = Color(0xFFF5F7F3);
  static const Color backgroundDark = Color(0xFF0F1F2E);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1A2F42);
  static const Color surfaceDarkElevated = Color(0xFF22394F);

  // --- Borders ------------------------------------------------------------
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color borderDark = Color(0xFF2A4558);

  // --- Text ---------------------------------------------------------------
  static const Color textPrimaryLight = Color(0xFF0F1F2E);
  static const Color textSecondaryLight = Color(0xFF5A6B7A);
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFA8B8C4);

  // --- Semantic -----------------------------------------------------------
  static const Color success = Color(0xFF10B981);
  static const Color successSoft = Color(0xFFD1FAE5);
  static const Color error = Color(0xFFEF4444);
  static const Color errorSoft = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSoft = Color(0xFFFEF3C7);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoSoft = Color(0x1A3B82F6); // 10% info

  // --- Neutral fills (used by chips/badges) -------------------------------
  static const Color neutralSoft = Color(0xFFE5E7EB);
  static const Color neutralStrong = Color(0xFF6B7280);
}

/// 4-pt-based spacing scale.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double mega = 48;
}

/// Corner radius scale.
class AppRadius {
  AppRadius._();

  static const double tight = 4;
  static const double small = 8;
  static const double input = 12;
  static const double card = 16;
  static const double pill = 24;
  static const double full = 999;
}

/// Animation durations — keep short to feel snappy on low-end devices.
class AppDurations {
  AppDurations._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
}

/// Soft, low-cost shadows. Re-used across primitives.
class AppElevation {
  AppElevation._();

  /// Subtle card lift used on light surfaces.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  /// Cyan glow used by Mitra dark-theme primary CTA.
  static const List<BoxShadow> accentGlow = [
    BoxShadow(
      color: Color(0x6600BCD4),
      blurRadius: 24,
      offset: Offset(0, 6),
    ),
  ];
}
