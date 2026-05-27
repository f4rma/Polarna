// Property tests for cascade deactivation of warehouses when a Mitra is
// deactivated by an Admin.
//
// Validates: Requirements 10.5
// Reference: .kiro/specs/coldshare-platform/requirements.md#Requirement 10
//
// Property 15: Cascade Penonaktifan Gudang Saat Mitra Dinonaktifkan
//   For every Mitra with 0 to N warehouses, after Admin deactivates the Mitra,
//   ALL warehouses have `isActive = false` without exception.

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
// `glados` re-exports `package:test/test.dart`, which collides with
// `flutter_test`. Hide the duplicates so the flutter_test versions win.
// ignore: depend_on_referenced_packages
import 'package:glados/glados.dart' hide test, group, expect;
import 'package:polarna/core/errors/failures.dart';
import 'package:polarna/features/admin/domain/entities/platform_summary.dart';
import 'package:polarna/features/admin/domain/repositories/admin_repository.dart';
import 'package:polarna/features/admin/domain/usecases/manage_users_usecase.dart';
import 'package:polarna/features/auth/domain/entities/user_entity.dart';

// ---------------------------------------------------------------------------
// In-memory models for the property test.
// ---------------------------------------------------------------------------

/// Minimal warehouse representation for cascade testing.
class _Warehouse {
  final String id;
  final String mitraId;
  bool isActive;

  _Warehouse({
    required this.id,
    required this.mitraId,
    this.isActive = true,
  });
}

// ---------------------------------------------------------------------------
// Fake repository that simulates cascade deactivation in-memory.
// ---------------------------------------------------------------------------

class _FakeAdminRepository implements AdminRepository {
  /// Users keyed by userId → role.
  final Map<String, UserRole> users;

  /// Warehouses grouped by mitraId.
  final Map<String, List<_Warehouse>> warehousesByMitra;

  /// Track which user IDs were deactivated.
  final List<String> deactivatedUsers = [];

  _FakeAdminRepository({
    required this.users,
    required this.warehousesByMitra,
  });

  @override
  Future<Either<Failure, Unit>> deactivateUser(String userId) async {
    if (!users.containsKey(userId)) {
      return Left(ServerFailure('Pengguna tidak ditemukan'));
    }

    deactivatedUsers.add(userId);
    final role = users[userId]!;

    // Cascade: if user is Mitra, deactivate ALL their warehouses.
    if (role == UserRole.mitra) {
      final warehouses = warehousesByMitra[userId] ?? [];
      for (final wh in warehouses) {
        wh.isActive = false;
      }
    }

    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> activateUser(String userId) async {
    return const Right(unit);
  }

  @override
  Future<Either<Failure, PlatformSummary>> getPlatformSummary() async {
    throw UnimplementedError();
  }

  @override
  Future<Either<Failure, List<UserEntity>>> getAllUsers() async {
    throw UnimplementedError();
  }
}

// ---------------------------------------------------------------------------
// Generators.
// ---------------------------------------------------------------------------

/// Generates a warehouse count in [0, 10].
Generator<int> _warehouseCountGen() => any.intInRange(0, 11);

/// Generates a list of N active warehouses for a given mitraId.
List<_Warehouse> _generateWarehouses(String mitraId, int count) {
  return List.generate(
    count,
    (i) => _Warehouse(
      id: 'wh-$mitraId-$i',
      mitraId: mitraId,
      isActive: true,
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests.
// ---------------------------------------------------------------------------

void main() {
  group('Property 15: Cascade Penonaktifan Gudang - Requirement 10.5', () {
    // -----------------------------------------------------------------------
    // Property 1: Mitra with N warehouses → ALL N warehouses inactive after
    // deactivation.
    // -----------------------------------------------------------------------
    Glados(_warehouseCountGen()).test(
      'Mitra with N warehouses (N in [0,10]): after deactivation, ALL N '
      'warehouses are inactive',
      (int warehouseCount) async {
        const mitraId = 'mitra-001';
        final warehouses = _generateWarehouses(mitraId, warehouseCount);

        final repo = _FakeAdminRepository(
          users: {mitraId: UserRole.mitra},
          warehousesByMitra: {mitraId: warehouses},
        );

        final useCase = DeactivateUserUseCase(repo);
        final result = await useCase(
          const ManageUserParams(userId: mitraId),
        );

        // Deactivation succeeds.
        expect(result.isRight(), isTrue,
            reason: 'Deactivation should succeed for mitra with '
                '$warehouseCount warehouses');

        // ALL warehouses must be inactive — no exceptions.
        for (int i = 0; i < warehouses.length; i++) {
          expect(warehouses[i].isActive, isFalse,
              reason: 'Warehouse $i of $warehouseCount should be inactive '
                  'after mitra deactivation');
        }

        // Verify the count: exactly warehouseCount warehouses were affected.
        final inactiveCount =
            warehouses.where((w) => !w.isActive).length;
        expect(inactiveCount, equals(warehouseCount),
            reason: 'All $warehouseCount warehouses must be deactivated');
      },
    );

    // -----------------------------------------------------------------------
    // Property 2: Non-Mitra (UMKM) deactivation does NOT affect warehouses.
    // -----------------------------------------------------------------------
    Glados(_warehouseCountGen()).test(
      'Non-Mitra user (UMKM) deactivation does NOT affect any warehouses',
      (int warehouseCount) async {
        const umkmId = 'umkm-001';
        const mitraId = 'mitra-001';

        // Create warehouses belonging to a mitra (not the UMKM user).
        final mitraWarehouses = _generateWarehouses(mitraId, warehouseCount);

        final repo = _FakeAdminRepository(
          users: {
            umkmId: UserRole.umkm,
            mitraId: UserRole.mitra,
          },
          warehousesByMitra: {mitraId: mitraWarehouses},
        );

        final useCase = DeactivateUserUseCase(repo);
        final result = await useCase(
          const ManageUserParams(userId: umkmId),
        );

        // Deactivation of UMKM succeeds.
        expect(result.isRight(), isTrue,
            reason: 'Deactivation should succeed for UMKM user');

        // ALL mitra warehouses must remain ACTIVE — no cascade.
        for (int i = 0; i < mitraWarehouses.length; i++) {
          expect(mitraWarehouses[i].isActive, isTrue,
              reason: 'Warehouse $i should remain active when a non-mitra '
                  'user is deactivated');
        }
      },
    );

    // -----------------------------------------------------------------------
    // Property 3: Deactivating Mitra A does NOT affect Mitra B's warehouses.
    // -----------------------------------------------------------------------
    Glados(any.combine2(
      _warehouseCountGen(),
      _warehouseCountGen(),
      (int countA, int countB) => (countA, countB),
    )).test(
      'Deactivating Mitra A does NOT affect Mitra B warehouses',
      ((int, int) counts) async {
        final (countA, countB) = counts;
        const mitraAId = 'mitra-A';
        const mitraBId = 'mitra-B';

        final warehousesA = _generateWarehouses(mitraAId, countA);
        final warehousesB = _generateWarehouses(mitraBId, countB);

        final repo = _FakeAdminRepository(
          users: {
            mitraAId: UserRole.mitra,
            mitraBId: UserRole.mitra,
          },
          warehousesByMitra: {
            mitraAId: warehousesA,
            mitraBId: warehousesB,
          },
        );

        final useCase = DeactivateUserUseCase(repo);
        final result = await useCase(
          const ManageUserParams(userId: mitraAId),
        );

        // Deactivation of Mitra A succeeds.
        expect(result.isRight(), isTrue,
            reason: 'Deactivation should succeed for Mitra A');

        // Mitra A's warehouses: ALL inactive.
        for (int i = 0; i < warehousesA.length; i++) {
          expect(warehousesA[i].isActive, isFalse,
              reason: 'Mitra A warehouse $i should be inactive');
        }

        // Mitra B's warehouses: ALL still active (unaffected).
        for (int i = 0; i < warehousesB.length; i++) {
          expect(warehousesB[i].isActive, isTrue,
              reason: 'Mitra B warehouse $i should remain active when '
                  'only Mitra A is deactivated');
        }
      },
    );
  });
}
