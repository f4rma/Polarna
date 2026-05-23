import 'package:dartz/dartz.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/warehouse_entity.dart';
import '../../domain/entities/warehouse_search_filter.dart';
import '../../domain/repositories/warehouse_repository.dart';
import '../datasources/warehouse_remote_datasource.dart';

typedef _RemoteCall<T> = Future<T> Function();

/// Concrete [WarehouseRepository] implementation.
///
/// Responsibilities:
///   - Run field-level validation (GPS bounds, capacity range, price range,
///     name length, temperature-threshold precision, photo count) before
///     touching the network, surfacing a specific [WarehouseFailure] when
///     input is malformed.
///   - Enforce the `remainingCapacity <= totalCapacity` invariant
///     (Requirement 2.6) on register and update.
///   - Guard every remote call with [NetworkInfo.isConnected].
///   - Centralise [AppException] → [Failure] mapping via [_call].
class WarehouseRepositoryImpl implements WarehouseRepository {
  final WarehouseRemoteDataSource _remote;
  final NetworkInfo _networkInfo;

  const WarehouseRepositoryImpl({
    required WarehouseRemoteDataSource remote,
    required NetworkInfo networkInfo,
  })  : _remote = remote,
        _networkInfo = networkInfo;

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, WarehouseEntity>> registerWarehouse(
    WarehouseEntity warehouse,
  ) async {
    final validation = _validateEntity(warehouse);
    if (validation != null) return Left(validation);
    return _call<WarehouseEntity>(() => _remote.registerWarehouse(warehouse));
  }

  @override
  Future<Either<Failure, WarehouseEntity>> updateWarehouse(
    WarehouseEntity warehouse,
  ) async {
    final validation = _validateEntity(warehouse);
    if (validation != null) return Left(validation);
    return _call<WarehouseEntity>(() => _remote.updateWarehouse(warehouse));
  }

  @override
  Future<Either<Failure, Unit>> toggleStatus({
    required String warehouseId,
    required bool isActive,
  }) {
    return _call<Unit>(() async {
      await _remote.toggleStatus(
        warehouseId: warehouseId,
        isActive: isActive,
      );
      return unit;
    });
  }

  @override
  Future<Either<Failure, WarehouseEntity>> updateRemainingCapacity({
    required String warehouseId,
    required double newRemainingCapacity,
  }) async {
    if (!await _networkInfo.isConnected) {
      return const Left(NoInternetFailure());
    }
    try {
      final result = await _remote.updateRemainingCapacity(
        warehouseId: warehouseId,
        newRemainingCapacity: newRemainingCapacity,
      );
      return Right(result);
    } on InvalidRemainingCapacityException catch (e) {
      return Left(
        InvalidRemainingCapacityFailure(totalCapacity: e.totalCapacity),
      );
    } on WarehouseNotFoundException catch (e) {
      return Left(ServerFailure(e.message));
    } on NoInternetException {
      return const Left(NoInternetFailure());
    } on TimeoutException {
      return const Left(TimeoutFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, WarehouseEntity>> getById(String id) {
    return _call<WarehouseEntity>(() => _remote.getById(id));
  }

  @override
  Future<Either<Failure, List<WarehouseEntity>>> getByMitraId(String mitraId) {
    return _call<List<WarehouseEntity>>(() async {
      final list = await _remote.getByMitraId(mitraId);
      return List<WarehouseEntity>.from(list);
    });
  }

  @override
  Future<Either<Failure, List<WarehouseEntity>>> searchWarehouses(
    WarehouseSearchFilter filter,
  ) {
    return _call<List<WarehouseEntity>>(() async {
      final list = await _remote.searchWarehouses(filter);
      return List<WarehouseEntity>.from(list);
    });
  }

  @override
  Stream<WarehouseEntity> watchById(String id) {
    // The repository interface intentionally returns a raw Stream (no
    // Either).  Errors propagate as stream errors; the presentation layer
    // converts them into user-facing messages.
    return _remote.watchById(id);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Generic network-aware remote-call wrapper.
  ///
  /// Centralises the `AppException → Failure` mapping so the public
  /// methods stay focused on their happy path.  Callers that require
  /// per-exception handling (see [updateRemainingCapacity]) can opt out
  /// and catch exceptions themselves.
  Future<Either<Failure, T>> _call<T>(_RemoteCall<T> action) async {
    if (!await _networkInfo.isConnected) {
      return const Left(NoInternetFailure());
    }
    try {
      return Right(await action());
    } on InvalidRemainingCapacityException catch (e) {
      return Left(
        InvalidRemainingCapacityFailure(totalCapacity: e.totalCapacity),
      );
    } on WarehouseNotFoundException catch (e) {
      return Left(ServerFailure(e.message));
    } on NoInternetException {
      return const Left(NoInternetFailure());
    } on TimeoutException {
      return const Left(TimeoutFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  /// Runs field-level validation on [w] and returns a specific
  /// [WarehouseFailure] for the first problem encountered, or `null`
  /// when all fields are valid.  Used by both [registerWarehouse] and
  /// [updateWarehouse] so the two entry points share identical guard
  /// logic.
  Failure? _validateEntity(WarehouseEntity w) {
    // GPS bounds → dedicated failure per Requirement 2.2.
    final gpsResult =
        Validators.validateGpsCoordinates(w.latitude, w.longitude);
    if (!gpsResult.isValid) {
      return const InvalidGpsCoordinatesFailure();
    }

    // Remaining ≤ total invariant (Requirement 2.6).
    if (w.remainingCapacity > w.totalCapacity ||
        w.remainingCapacity < 0) {
      return InvalidRemainingCapacityFailure(totalCapacity: w.totalCapacity);
    }

    // Collect remaining field-level errors so the caller can surface them
    // all at once.
    final invalid = <String>[
      if (!Validators.validateWarehouseName(w.name).isValid) 'name',
      if (!Validators.validateWarehouseCapacity(w.totalCapacity).isValid)
        'totalCapacity',
      if (!Validators.validateWarehousePrice(w.pricePerM3PerDay).isValid)
        'pricePerM3PerDay',
      if (!Validators.validateTemperatureThreshold(w.temperatureThreshold)
          .isValid)
        'temperatureThreshold',
      if (w.photoUrls.isEmpty ||
          w.photoUrls.length > AppConstants.maxWarehousePhotos)
        'photoUrls',
      if (w.address.trim().isEmpty) 'address',
    ];
    if (invalid.isNotEmpty) {
      return InvalidWarehouseInputFailure(fields: invalid);
    }
    return null;
  }
}
