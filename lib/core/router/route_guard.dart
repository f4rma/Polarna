import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/entities/user_entity.dart';
import '../constants/route_constants.dart';

/// Paths that do NOT require authentication.
const Set<String> _publicPaths = <String>{
  RouteConstants.login,
  RouteConstants.register,
  RouteConstants.forgotPassword,
};

/// Canonical home path for a given role.
String roleHome(UserRole role) {
  switch (role) {
    case UserRole.umkm:
      return RouteConstants.umkmHome;
    case UserRole.mitra:
      return RouteConstants.mitraDashboard;
    case UserRole.admin:
      return RouteConstants.adminDashboard;
  }
}

/// Whether a path inside a role-scoped prefix is allowed for [role].
///
/// Shared paths (`/`, auth pages, `/warehouse/:id`) return `true` regardless
/// of role.
bool isAllowedForRole(String path, UserRole role) {
  if (path.startsWith('/admin')) return role == UserRole.admin;
  if (path.startsWith('/mitra')) return role == UserRole.mitra;
  if (path.startsWith('/umkm')) return role == UserRole.umkm;
  return true;
}

/// Pure routing policy for the app router.
///
/// Returns the destination path to redirect to, or `null` to stay on
/// [location].
///
/// Rules (see `design.md §Navigation`):
/// - While [authState] is loading: no redirect (splash keeps showing).
/// - Unauthenticated + public path: no redirect.
/// - Unauthenticated + any other path (incl. splash): redirect to `/login`.
/// - Authenticated on splash or auth page: redirect to role home.
/// - Authenticated on a role-scoped path for the wrong role: redirect to
///   role home.
/// - Otherwise: no redirect.
String? computeRedirect({
  required AsyncValue<UserEntity?> authState,
  required String location,
}) {
  if (authState.isLoading) return null;

  final user = authState.valueOrNull;
  final isAuthed = user != null;
  final isPublic = _publicPaths.contains(location);
  final isSplash = location == RouteConstants.splash;

  // --- Unauthenticated ------------------------------------------------------
  if (!isAuthed) {
    if (isPublic) return null;
    return RouteConstants.login;
  }

  // --- Authenticated --------------------------------------------------------
  final home = roleHome(user.role);

  if (isSplash || isPublic) return home;
  if (!isAllowedForRole(location, user.role)) return home;

  return null;
}
