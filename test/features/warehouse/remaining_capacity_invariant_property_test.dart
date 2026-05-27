// Property tests for the remaining-vs-total capacity invariant at the
// warehouse domain/use-case layer.
//
// Validates: Requirements 2.6
// Reference: .kiro/specs/coldshare-platform/requirements.md#Requirement 2
//
// Property 6: Invariant Sisa Kapasitas Tidak Melebihi Total
//   For every (total, remaining) pair:
//     - remaining <= total  →  RegisterWarehouseUseCase / UpdateWarehouseUseCase
//                              proceed (returns Right with an entity)
//     - remaining  > total  →  both use cases reject with
//                              InvalidRemainingCapacityFailure whose message
//                              mentions "Sisa kapasitas" and the totalCapacity
//                              value, and the repository is NOT called.

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
// `glados` re-exports `package:test/test.dart`, which collides with
// `flutter_test`. Hide the duplicates so the flutter_test versions win.
// ignore: depend_on_referenced_packages
import 'package:glados/glados.dart' hide test, group, expect;
import 'package:polarna/core/errors/failures.dart';
import 'package:polarna/features/warehouse/domain/entities/warehouse_entity.dart';
import 'package:polarna/features/warehouse/domain/entities/warehouse_search_filter.dart';
import 'package:polarna/features/warehouse/domain/repositories/warehouse_repository.dart';
import 'package:polarna/features/warehouse/domain/usecases/register_warehouse_usecase.dart';
import 'package:polarna/features/warehouse/domain/usecases/update_warehouse_usecase.dart';

// ---------------------------------------------------------------------------
// Fake repository — echoes the input entity back and counts calls so tests
// can assert that the use case short-circuits before hitting the data layer
// when the invariant is violated.
// ---------------------------------------------------------------------------
class _FakeRepo implements WarehouseRepository {
  int registerCalls = 0;
  int updateCalls = 0;

  @override
  Future<Either<Failure, WarehouseEntity>> registerWarehouse(
    WarehouseEntity warehouse,
  ) async {
    registerCalls++;
    return Right(warehouse);
  }

  @override
  Future<Either<Failure, WarehouseEntity>> updateWarehouse(
    WarehouseEntity warehouse,
  ) async {
    updateCalls++;
    return Right(warehouse);
  }

  // Unused by these tests — fail loudly if accidentally invoked.
  @override
  Future<Either<Failure, List<WarehouseEntity>>> searchWarehouses(
          WarehouseSearchFilter filter) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, Unit>> toggleStatus({
    required String warehouseId,
    required bool isActive,
  }) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, WarehouseEntity>> getById(String id) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, List<WarehouseEntity>>> getByMitraId(String mitraId) =>
      throw UnimplementedError();
  @override
  Stream<WarehouseEntity> watchById(String id) => throw UnimplementedError();
  @override
  Future<Either<Failure, WarehouseEntity>> updateRemainingCapacity({
    required String warehouseId,
    required double newRemainingCapacity,
  }) =>
      throw UnimplementedError();
}

// ---------------------------------------------------------------------------
// Helpers.
// ---------------------------------------------------------------------------

/// Uniform `double` in `[min, max]` (both inclusive) with millionth-step
/// granularity — plenty of resolution for boundary exploration.
Generator<double> _doubleInRange(double min, double max) {
  return any
      .intInRange(0, 1000001) // [0, 1_000_000] inclusive
      .map((n) => min + (max - min) * (n / 1000000.0));
}

WarehouseEntity _mkEntity({required double total, required double remaining}) {
  final now = DateTime.utc(2024);
  return WarehouseEntity(
    id: 'id-1',
    mitraId: 'mitra-1',
    name: 'Gudang Uji',
    address: 'Jl. Uji 1',
    latitude: 0.0,
    longitude: 100.0,
    totalCapacity: total,
    remainingCapacity: remaining,
    pricePerM3PerDay: 1000.0,
    temperatureCategory: TemperatureCategory.frozen,
    temperatureThreshold: 0.0,
    photoUrls: const [],
    isActive: true,
    iotNodeId: null,
    createdAt: now,
    updatedAt: now,
  );
}

RegisterWarehouseParams _mkParams({
  required double total,
  required double remaining,
}) =>
    RegisterWarehouseParams(
      mitraId: 'mitra-1',
      name: 'Gudang Uji',
      address: 'Jl. Uji 1',
      latitude: 0.0,
      longitude: 100.0,
      totalCapacity: total,
      remainingCapacity: remaining,
      pricePerM3PerDay: 1000.0,
      temperatureCategory: TemperatureCategory.frozen,
      temperatureThreshold: 0.0,
      photoUrls: const [],
    );

void main() {
  // Total ∈ [1, 999_999]. Remaining in valid pair = total * fraction,
  // fraction ∈ [0, 1], so remaining ∈ [0, total] by construction.
  final validPairGen = any.combine2(
    _doubleInRange(1.0, 999999.0),
    _doubleInRange(0.0, 1.0),
    (double total, double fraction) => (total, total * fraction),
  );

  // Violating: remaining = total + excess where excess ∈ [1e-4, 999_999].
  final violatingPairGen = any.combine2(
    _doubleInRange(1.0, 999999.0),
    _doubleInRange(1e-4, 999999.0),
    (double total, double excess) => (total, total + excess),
  );

  group('Property 6: Invariant Sisa Kapasitas - Requirement 2.6', () {
    // -----------------------------------------------------------------------
    // RegisterWarehouseUseCase
    // -----------------------------------------------------------------------
    group('RegisterWarehouseUseCase', () {
      Glados(validPairGen).test('accepts pairs where remaining <= total',
          (pair) async {
        final (total, remaining) = pair;
        expect(remaining, lessThanOrEqualTo(total));
        final repo = _FakeRepo();
        final useCase = RegisterWarehouseUseCase(repo);
        final result = await useCase(
          _mkParams(total: total, remaining: remaining),
        );
        expect(result.isRight(), isTrue,
            reason: 'Expected Right for total=$total, remaining=$remaining');
        expect(repo.registerCalls, 1,
            reason: 'Repository should be invoked on valid input');
      });

      Glados(violatingPairGen).test('rejects pairs where remaining > total',
          (pair) async {
        final (total, remaining) = pair;
        expect(remaining, greaterThan(total));
        final repo = _FakeRepo();
        final useCase = RegisterWarehouseUseCase(repo);
        final result = await useCase(
          _mkParams(total: total, remaining: remaining),
        );
        expect(result.isLeft(), isTrue,
            reason: 'Expected Left for total=$total, remaining=$remaining');
        result.fold(
          (f) {
            expect(f, isA<InvalidRemainingCapacityFailure>());
            expect(f.message, contains('Sisa kapasitas'));
            expect(f.message, contains(total.toString()));
            expect((f as InvalidRemainingCapacityFailure).totalCapacity,
                equals(total));
          },
          (_) => fail('Expected Left but got Right'),
        );
        expect(repo.registerCalls, 0,
            reason: 'Repository must NOT be called when invariant violated');
      });
    });

    // -----------------------------------------------------------------------
    // UpdateWarehouseUseCase
    // -----------------------------------------------------------------------
    group('UpdateWarehouseUseCase', () {
      Glados(validPairGen).test('accepts entities where remaining <= total',
          (pair) async {
        final (total, remaining) = pair;
        expect(remaining, lessThanOrEqualTo(total));
        final repo = _FakeRepo();
        final useCase = UpdateWarehouseUseCase(repo);
        final result = await useCase(UpdateWarehouseParams(
          warehouse: _mkEntity(total: total, remaining: remaining),
        ));
        expect(result.isRight(), isTrue,
            reason: 'Expected Right for total=$total, remaining=$remaining');
        expect(repo.updateCalls, 1);
      });

      Glados(violatingPairGen).test('rejects entities where remaining > total',
          (pair) async {
        final (total, remaining) = pair;
        expect(remaining, greaterThan(total));
        final repo = _FakeRepo();
        final useCase = UpdateWarehouseUseCase(repo);
        final result = await useCase(UpdateWarehouseParams(
          warehouse: _mkEntity(total: total, remaining: remaining),
        ));
        expect(result.isLeft(), isTrue);
        result.fold(
          (f) {
            expect(f, isA<InvalidRemainingCapacityFailure>());
            expect(f.message, contains('Sisa kapasitas'));
            expect(f.message, contains(total.toString()));
            expect((f as InvalidRemainingCapacityFailure).totalCapacity,
                equals(total));
          },
          (_) => fail('Expected Left but got Right'),
        );
        expect(repo.updateCalls, 0,
            reason: 'Repository must NOT be called when invariant violated');
      });
    });

    // -----------------------------------------------------------------------
    // Fixed boundary checks.
    // -----------------------------------------------------------------------
    group('Boundary cases', () {
      test('remaining == total is accepted (invariant is <=)', () async {
        final repo = _FakeRepo();
        final reg = await RegisterWarehouseUseCase(repo)(
          _mkParams(total: 500.0, remaining: 500.0),
        );
        final upd = await UpdateWarehouseUseCase(repo)(UpdateWarehouseParams(
          warehouse: _mkEntity(total: 500.0, remaining: 500.0),
        ));
        expect(reg.isRight(), isTrue);
        expect(upd.isRight(), isTrue);
        expect(repo.registerCalls, 1);
        expect(repo.updateCalls, 1);
      });

      test('remaining just above total is rejected', () async {
        const total = 500.0;
        final remaining = total + 0.0001;
        final repo = _FakeRepo();
        final reg = await RegisterWarehouseUseCase(repo)(
          _mkParams(total: total, remaining: remaining),
        );
        final upd = await UpdateWarehouseUseCase(repo)(UpdateWarehouseParams(
          warehouse: _mkEntity(total: total, remaining: remaining),
        ));
        expect(reg.isLeft(), isTrue);
        expect(upd.isLeft(), isTrue);
        expect(repo.registerCalls, 0);
        expect(repo.updateCalls, 0);
      });

      test('remaining == 0 is always accepted', () async {
        final repo = _FakeRepo();
        final reg = await RegisterWarehouseUseCase(repo)(
          _mkParams(total: 1.0, remaining: 0.0),
        );
        final upd = await UpdateWarehouseUseCase(repo)(UpdateWarehouseParams(
          warehouse: _mkEntity(total: 999999.0, remaining: 0.0),
        ));
        expect(reg.isRight(), isTrue);
        expect(upd.isRight(), isTrue);
      });
    });
  });
}
