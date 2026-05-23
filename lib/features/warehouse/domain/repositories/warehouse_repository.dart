import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/warehouse_entity.dart';
import '../entities/warehouse_search_filter.dart';

/// Abstract data contract between the warehouse domain and data layers.
///
/// Implementations live in `data/repositories/warehouse_repository_impl.dart`
/// and translate domain entities to/from Firestore models.
abstract class WarehouseRepository {
  /// Registers a new warehouse for a Mitra.
  ///
  /// The [warehouse.id], [warehouse.createdAt], and [warehouse.updatedAt]
  /// fields may be overwritten by the data layer.
  Future<Either<Failure, WarehouseEntity>> registerWarehouse(
    WarehouseEntity warehouse,
  );

  /// Updates an existing warehouse. The data layer MUST enforce the
  /// invariant `remainingCapacity <= totalCapacity` (Requirement 2.6).
  Future<Either<Failure, WarehouseEntity>> updateWarehouse(
    WarehouseEntity warehouse,
  );

  /// Searches warehouses by the given [filter].
  Future<Either<Failure, List<WarehouseEntity>>> searchWarehouses(
    WarehouseSearchFilter filter,
  );

  /// Flips a warehouse's active status. Inactive warehouses SHALL NOT
  /// appear in search results (Requirements 2.7, 2.8).
  Future<Either<Failure, Unit>> toggleStatus({
    required String warehouseId,
    required bool isActive,
  });

  /// Fetches a single warehouse by its document id.
  Future<Either<Failure, WarehouseEntity>> getById(String id);

  /// Fetches all warehouses belonging to a Mitra.
  Future<Either<Failure, List<WarehouseEntity>>> getByMitraId(String mitraId);

  /// Live updates for a single warehouse — primarily used to reflect
  /// changes to [WarehouseEntity.remainingCapacity] in real time.
  Stream<WarehouseEntity> watchById(String id);

  /// Writes a new [newRemainingCapacity] value after enforcing the
  /// `remainingCapacity <= totalCapacity` invariant (Requirement 2.6).
  Future<Either<Failure, WarehouseEntity>> updateRemainingCapacity({
    required String warehouseId,
    required double newRemainingCapacity,
  });
}
