// Role-aware theme provider. Returns the dark theme for Mitra/Admin and
// the light theme for UMKM (or signed-out users).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import 'app_theme.dart';

/// Selects the active [ThemeData] based on the current authenticated role.
final appThemeProvider = Provider<ThemeData>((ref) {
  final user = ref.watch(authProvider).valueOrNull;
  final role = user?.role;
  if (role == UserRole.mitra || role == UserRole.admin) {
    return AppTheme.dark();
  }
  return AppTheme.light();
});
