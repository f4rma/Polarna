// Unit tests for the pure routing guard in `lib/core/router/route_guard.dart`.
//
// Validates: Requirements 1.8, 1.9, 10.1
// Reference: .kiro/specs/coldshare-platform/requirements.md
//
// The tests exercise `computeRedirect` directly (no GoRouter, no widget
// tree, no ProviderContainer) so they run in milliseconds and stay
// deterministic. Task 4.2 specifically asks for coverage of:
//   * redirect to `/login` when unauthenticated
//   * access to Admin pages denied for non-admin roles

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polarna/core/router/route_guard.dart';
import 'package:polarna/features/auth/domain/entities/user_entity.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

UserEntity _user(UserRole role) => UserEntity(
      uid: 'u',
      email: 'e@x.id',
      fullName: 'n',
      phoneNumber: '+62800000',
      role: role,
      isEmailVerified: true,
      isActive: true,
      createdAt: DateTime.utc(2024),
    );

AsyncValue<UserEntity?> _authed(UserRole role) =>
    AsyncValue<UserEntity?>.data(_user(role));

const AsyncValue<UserEntity?> _unauthed = AsyncValue<UserEntity?>.data(null);
const AsyncValue<UserEntity?> _loading = AsyncValue<UserEntity?>.loading();

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('computeRedirect — unauthenticated', () {
    const redirectsToLogin = <String>[
      '/',
      '/umkm/home',
      '/mitra/dashboard',
      '/admin/dashboard',
      '/warehouse/abc',
    ];
    for (final loc in redirectsToLogin) {
      test('$loc → /login', () {
        expect(
          computeRedirect(authState: _unauthed, location: loc),
          '/login',
        );
      });
    }

    const publicStays = <String>['/login', '/register', '/forgot-password'];
    for (final loc in publicStays) {
      test('$loc stays (null)', () {
        expect(
          computeRedirect(authState: _unauthed, location: loc),
          isNull,
        );
      });
    }
  });

  group('computeRedirect — loading', () {
    const locations = <String>['/', '/login', '/admin/dashboard'];
    for (final loc in locations) {
      test('$loc → null while loading', () {
        expect(
          computeRedirect(authState: _loading, location: loc),
          isNull,
        );
      });
    }
  });

  group('computeRedirect — authed UMKM', () {
    final state = _authed(UserRole.umkm);
    const toHome = <String>[
      '/',
      '/login',
      '/register',
      '/forgot-password',
      '/mitra/dashboard',
      '/admin/dashboard',
      '/admin/users',
    ];
    for (final loc in toHome) {
      test('$loc → /umkm/home', () {
        expect(
          computeRedirect(authState: state, location: loc),
          '/umkm/home',
        );
      });
    }

    const allowed = <String>[
      '/umkm/home',
      '/umkm/monitoring/abc',
      '/umkm/profile',
      '/warehouse/xyz',
    ];
    for (final loc in allowed) {
      test('$loc stays (null)', () {
        expect(
          computeRedirect(authState: state, location: loc),
          isNull,
        );
      });
    }
  });

  group('computeRedirect — authed Mitra', () {
    final state = _authed(UserRole.mitra);
    const toHome = <String>[
      '/',
      '/login',
      '/umkm/home',
      '/admin/dashboard',
    ];
    for (final loc in toHome) {
      test('$loc → /mitra/dashboard', () {
        expect(
          computeRedirect(authState: state, location: loc),
          '/mitra/dashboard',
        );
      });
    }

    const allowed = <String>[
      '/mitra/dashboard',
      '/mitra/warehouses',
      '/warehouse/xyz',
    ];
    for (final loc in allowed) {
      test('$loc stays (null)', () {
        expect(
          computeRedirect(authState: state, location: loc),
          isNull,
        );
      });
    }
  });

  group('computeRedirect — authed Admin', () {
    final state = _authed(UserRole.admin);
    const toHome = <String>[
      '/',
      '/login',
      '/umkm/home',
      '/mitra/dashboard',
    ];
    for (final loc in toHome) {
      test('$loc → /admin/dashboard', () {
        expect(
          computeRedirect(authState: state, location: loc),
          '/admin/dashboard',
        );
      });
    }

    const allowed = <String>[
      '/admin/dashboard',
      '/admin/users',
      '/admin/warehouses',
      '/warehouse/xyz',
    ];
    for (final loc in allowed) {
      test('$loc stays (null)', () {
        expect(
          computeRedirect(authState: state, location: loc),
          isNull,
        );
      });
    }
  });

  group('Admin-only access denied for non-admin roles', () {
    const adminPaths = <String>[
      '/admin/dashboard',
      '/admin/users',
      '/admin/warehouses',
      '/admin/incidents',
    ];
    for (final role in [UserRole.umkm, UserRole.mitra]) {
      for (final path in adminPaths) {
        test('${role.name} blocked from $path', () {
          expect(
            computeRedirect(authState: _authed(role), location: path),
            roleHome(role),
          );
        });
      }
    }
  });
}
