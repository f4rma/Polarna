// Hand-rolled fake for [WarehouseRepository] used by warehouse use-case
// unit tests.
//
// No mockito / build_runner — plain Dart only. Responses are enqueued by the
// test; each call pops the next queued response. If a queue is empty when a
// method is called, a [StateError] is thrown so tests fail loudly.

import 'dart:async';
import 'dart:collection';

import 'package:dartz/dartz.dart';
import 'package:polarna/core/errors/failures.dart';
import 'package:polarna/features/warehouse/domain/entities/warehouse_entity.dart';
import 'package:polarna/features/warehouse/domain/entities/warehouse_search_filter.dart';
import 'package:polarna/features/warehouse/domain/repositories/warehouse_repository.dart';

/// Captured arguments of a single `toggleStatus` call.
class ToggleStatusCall {
  final String warehouseId;
  final bool isActive;
  const ToggleStatusCall(this.warehouseId, this.isActive);
}

class FakeWarehouseRepository implements WarehouseRepository {
  // ---------------------------------------------------------------------------
  // Response queues
  // ---------------------------------------------------------------------------

  final Queue<Either<Failure, WarehouseEntity>> registerWarehouseResponses =
      Queue();
  final Queue<Either<Failure, WarehouseEntity>> updateWarehouseResponses =
      Queue();
  final Queue<Either<Failure, List<WarehouseEntity>>> searchWarehousesResponses =
      Queue();
  final Queue<Either<Failure, Unit>> toggleStatusResponses = Queue();
  final Queue<Either<Failure, WarehouseEntity>> getByIdResponses = Queue();
  final Queue<Either<Failure, List<WarehouseEntity>>> getByMitraIdResponses =
      Queue();
  final Queue<Either<Failure, WarehouseEntity>>
      updateRemainingCapacityResponses = Queue();

  // ---------------------------------------------------------------------------
  // Invocation log
  // ---------------------------------------------------------------------------

  final List<WarehouseEntity> registerWarehouseCalls = [];
  final List<WarehouseEntity> updateWarehouseCalls = [];
  final List<WarehouseSearchFilter> searchWarehousesCalls = [];
  final List<ToggleStatusCall> toggleStatusCalls = [];
  final List<String> getByIdCalls = [];
  final List<String> getByMitraIdCalls = [];

  // ---------------------------------------------------------------------------
  // Repository API
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, WarehouseEntity>> registerWarehouse(
    WarehouseEntity warehouse,
  ) async {
    registerWarehouseCalls.add(warehouse);
    if (registerWarehouseResponses.isEmpty) {
      throw StateError('No registerWarehouseResponses queued');
    }
    return registerWarehouseResponses.removeFirst();
  }

  @override
  Future<Either<Failure, WarehouseEntity>> updateWarehouse(
    WarehouseEntity warehouse,
  ) async {
    updateWarehouseCalls.add(warehouse);
    if (updateWarehouseResponses.isEmpty) {
      throw StateError('No updateWarehouseResponses queued');
    }
    return updateWarehouseResponses.removeFirst();
  }

  @override
  Future<Either<Failure, List<WarehouseEntity>>> searchWarehouses(
    WarehouseSearchFilter filter,
  ) async {
    searchWarehousesCalls.add(filter);
    if (searchWarehousesResponses.isEmpty) {
      throw StateError('No searchWarehousesResponses queued');
    }
    return searchWarehousesResponses.removeFirst();
  }

  @override
  Future<Either<Failure, Unit>> toggleStatus({
    required String warehouseId,
    required bool isActive,
  }) async {
    toggleStatusCalls.add(ToggleStatusCall(warehouseId, isActive));
    if (toggleStatusResponses.isEmpty) {
      throw StateError('No toggleStatusResponses queued');
    }
    return toggleStatusResponses.removeFirst();
  }

  @override
  Future<Either<Failure, WarehouseEntity>> getById(String id) async {
    getByIdCalls.add(id);
    if (getByIdResponses.isEmpty) {
      throw StateError('No getByIdResponses queued');
    }
    return getByIdResponses.removeFirst();
  }

  @override
  Future<Either<Failure, List<WarehouseEntity>>> getByMitraId(
    String mitraId,
  ) async {
    getByMitraIdCalls.add(mitraId);
    if (getByMitraIdResponses.isEmpty) {
      throw StateError('No getByMitraIdResponses queued');
    }
    return getByMitraIdResponses.removeFirst();
  }

  @override
  Stream<WarehouseEntity> watchById(String id) {
    // Not needed for use-case tests; return an empty stream.
    return const Stream.empty();
  }

  @override
  Future<Either<Failure, WarehouseEntity>> updateRemainingCapacity({
    required String warehouseId,
    required double newRemainingCapacity,
  }) async {
    if (updateRemainingCapacityResponses.isEmpty) {
      throw StateError('No updateRemainingCapacityResponses queued');
    }
    return updateRemainingCapacityResponses.removeFirst();
  }
}
