// Unit tests for the warehouse use cases.
//
// Validates: Requirements 2.1–2.8, 3.1–3.7
// Reference: .kiro/specs/coldshare-platform/requirements.md#Requirement 2, 3
//
// Each use case is tested with its FakeWarehouseRepository to verify:
// - Correct delegation to the repository
// - Domain-level validation (remainingCapacity <= totalCapacity)
// - Proper return of Either results

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polarna/core/errors/failures.dart';
import 'package:polarna/features/warehouse/domain/entities/warehouse_entity.dart';
import 'package:polarna/features/warehouse/domain/entities/warehouse_search_filter.dart';
import 'package:polarna/features/warehouse/domain/usecases/register_warehouse_usecase.dart';
import 'package:polarna/features/warehouse/domain/usecases/search_warehouses_usecase.dart';
import 'package:polarna/features/warehouse/domain/usecases/toggle_warehouse_status_usecase.dart';
import 'package:polarna/features/warehouse/domain/usecases/update_warehouse_usecase.dart';

import 'fakes/fake_warehouse_repository.dart';

WarehouseEntity _makeWarehouse({
  String id = 'wh-1',
  double totalCapacity = 100.0,
  double remainingCapacity = 50.0,
}) =>
    WarehouseEntity(
      id: id,
      mitraId: 'mitra-1',
      name: 'Gudang Dingin A',
      address: 'Jl. Raya No. 1, Jakarta',
      latitude: -6.2,
      longitude: 106.8,
      totalCapacity: totalCapacity,
      remainingCapacity: remainingCapacity,
      pricePerM3PerDay: 50000,
      temperatureCategory: TemperatureCategory.chilled,
      temperatureThreshold: 4.0,
      photoUrls: const ['https://example.com/photo1.jpg'],
      isActive: true,
      iotNodeId: 'node-1',
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 1),
    );

void main() {
  // ---------------------------------------------------------------------------
  // RegisterWarehouseUseCase
  // ---------------------------------------------------------------------------
  group('RegisterWarehouseUseCase', () {
    test('success: valid params → Right(entity), repo called once', () async {
      final repo = FakeWarehouseRepository();
      final expected = _makeWarehouse();
      repo.registerWarehouseResponses.add(Right(expected));

      final useCase = RegisterWarehouseUseCase(repo);
      final result = await useCase.call(
        const RegisterWarehouseParams(
          mitraId: 'mitra-1',
          name: 'Gudang Dingin A',
          address: 'Jl. Raya No. 1, Jakarta',
          latitude: -6.2,
          longitude: 106.8,
          totalCapacity: 100.0,
          remainingCapacity: 50.0,
          pricePerM3PerDay: 50000,
          temperatureCategory: TemperatureCategory.chilled,
          temperatureThreshold: 4.0,
          photoUrls: ['https://example.com/photo1.jpg'],
          iotNodeId: 'node-1',
        ),
      );

      expect(result, Right<Failure, WarehouseEntity>(expected));
      expect(repo.registerWarehouseCalls, hasLength(1));
    });

    test(
        'failure: remainingCapacity > totalCapacity → '
        'Left(InvalidRemainingCapacityFailure), repo NOT called', () async {
      final repo = FakeWarehouseRepository();
      final useCase = RegisterWarehouseUseCase(repo);

      final result = await useCase.call(
        const RegisterWarehouseParams(
          mitraId: 'mitra-1',
          name: 'Gudang Dingin A',
          address: 'Jl. Raya No. 1, Jakarta',
          latitude: -6.2,
          longitude: 106.8,
          totalCapacity: 100.0,
          remainingCapacity: 150.0, // exceeds totalCapacity
          pricePerM3PerDay: 50000,
          temperatureCategory: TemperatureCategory.chilled,
          temperatureThreshold: 4.0,
          photoUrls: ['https://example.com/photo1.jpg'],
        ),
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<InvalidRemainingCapacityFailure>()),
        (_) => fail('Expected Left'),
      );
      // Repository should NOT have been called
      expect(repo.registerWarehouseCalls, isEmpty);
    });

    test('entity passed to repo has id empty and timestamps set to ~now',
        () async {
      final repo = FakeWarehouseRepository();
      final expected = _makeWarehouse();
      repo.registerWarehouseResponses.add(Right(expected));

      final useCase = RegisterWarehouseUseCase(repo);
      final before = DateTime.now().toUtc();

      await useCase.call(
        const RegisterWarehouseParams(
          mitraId: 'mitra-1',
          name: 'Gudang Dingin A',
          address: 'Jl. Raya No. 1, Jakarta',
          latitude: -6.2,
          longitude: 106.8,
          totalCapacity: 100.0,
          remainingCapacity: 50.0,
          pricePerM3PerDay: 50000,
          temperatureCategory: TemperatureCategory.chilled,
          temperatureThreshold: 4.0,
          photoUrls: ['https://example.com/photo1.jpg'],
        ),
      );

      final after = DateTime.now().toUtc();
      final passedEntity = repo.registerWarehouseCalls.single;

      expect(passedEntity.id, '');
      expect(passedEntity.createdAt.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(passedEntity.createdAt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
      expect(passedEntity.updatedAt.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(passedEntity.updatedAt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // UpdateWarehouseUseCase
  // ---------------------------------------------------------------------------
  group('UpdateWarehouseUseCase', () {
    test('success: valid entity → Right(updated entity), repo called once',
        () async {
      final repo = FakeWarehouseRepository();
      final warehouse = _makeWarehouse();
      final updated = warehouse.copyWith(name: 'Updated Name');
      repo.updateWarehouseResponses.add(Right(updated));

      final useCase = UpdateWarehouseUseCase(repo);
      final result = await useCase.call(
        UpdateWarehouseParams(warehouse: warehouse),
      );

      expect(result, Right<Failure, WarehouseEntity>(updated));
      expect(repo.updateWarehouseCalls, hasLength(1));
    });

    test(
        'failure: remainingCapacity > totalCapacity → '
        'Left(InvalidRemainingCapacityFailure), repo NOT called', () async {
      final repo = FakeWarehouseRepository();
      final warehouse = _makeWarehouse(
        totalCapacity: 100.0,
        remainingCapacity: 200.0, // exceeds totalCapacity
      );

      final useCase = UpdateWarehouseUseCase(repo);
      final result = await useCase.call(
        UpdateWarehouseParams(warehouse: warehouse),
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<InvalidRemainingCapacityFailure>()),
        (_) => fail('Expected Left'),
      );
      expect(repo.updateWarehouseCalls, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // SearchWarehousesUseCase
  // ---------------------------------------------------------------------------
  group('SearchWarehousesUseCase', () {
    test('delegates filter to repo, returns the list', () async {
      final repo = FakeWarehouseRepository();
      final warehouses = [_makeWarehouse(), _makeWarehouse(id: 'wh-2')];
      repo.searchWarehousesResponses.add(Right(warehouses));

      const filter = WarehouseSearchFilter(
        category: TemperatureCategory.chilled,
        minCapacityM3: 10.0,
      );

      final useCase = SearchWarehousesUseCase(repo);
      final result = await useCase.call(
        const SearchWarehousesParams(filter: filter),
      );

      expect(result, Right<Failure, List<WarehouseEntity>>(warehouses));
      expect(repo.searchWarehousesCalls, hasLength(1));
      expect(repo.searchWarehousesCalls.single, filter);
    });

    test('empty result → Right([])', () async {
      final repo = FakeWarehouseRepository();
      repo.searchWarehousesResponses.add(const Right([]));

      const filter = WarehouseSearchFilter(radiusKm: 50.0);

      final useCase = SearchWarehousesUseCase(repo);
      final result = await useCase.call(
        const SearchWarehousesParams(filter: filter),
      );

      expect(result, const Right<Failure, List<WarehouseEntity>>([]));
    });
  });

  // ---------------------------------------------------------------------------
  // ToggleWarehouseStatusUseCase
  // ---------------------------------------------------------------------------
  group('ToggleWarehouseStatusUseCase', () {
    test('delegates warehouseId + isActive to repo, returns Right(unit)',
        () async {
      final repo = FakeWarehouseRepository();
      repo.toggleStatusResponses.add(const Right(unit));

      final useCase = ToggleWarehouseStatusUseCase(repo);
      final result = await useCase.call(
        const ToggleWarehouseStatusParams(
          warehouseId: 'wh-1',
          isActive: false,
        ),
      );

      expect(result, const Right<Failure, Unit>(unit));
      expect(repo.toggleStatusCalls, hasLength(1));
      expect(repo.toggleStatusCalls.single.warehouseId, 'wh-1');
      expect(repo.toggleStatusCalls.single.isActive, false);
    });

    test('failure → Left(ServerFailure)', () async {
      final repo = FakeWarehouseRepository();
      repo.toggleStatusResponses.add(const Left(ServerFailure()));

      final useCase = ToggleWarehouseStatusUseCase(repo);
      final result = await useCase.call(
        const ToggleWarehouseStatusParams(
          warehouseId: 'wh-1',
          isActive: true,
        ),
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('Expected Left'),
      );
    });
  });
}
