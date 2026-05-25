import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/telemetry_entity.dart';
import '../../domain/repositories/telemetry_repository.dart';
import '../datasources/telemetry_remote_datasource.dart';

/// Concrete [TelemetryRepository] implementation.
///
/// Responsibilities:
///   - Guard every remote call with [NetworkInfo.isConnected].
///   - Centralise [AppException] → [Failure] mapping via [_call].
///   - Pass through the real-time stream directly (errors propagate as
///     stream errors per the repository contract).
class TelemetryRepositoryImpl implements TelemetryRepository {
  final TelemetryRemoteDataSource _remote;
  final NetworkInfo _networkInfo;

  const TelemetryRepositoryImpl({
    required TelemetryRemoteDataSource remote,
    required NetworkInfo networkInfo,
  })  : _remote = remote,
        _networkInfo = networkInfo;

  // ---------------------------------------------------------------------------
  // Stream (pass-through)
  // ---------------------------------------------------------------------------

  @override
  Stream<TelemetryRecord> watchLatestTelemetry(String warehouseId) {
    return _remote.watchLatestTelemetry(warehouseId);
  }

  // ---------------------------------------------------------------------------
  // Futures
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, List<TelemetryRecord>>> getHistory({
    required String warehouseId,
    required DateTime from,
    required DateTime to,
  }) {
    return _call<List<TelemetryRecord>>(
      () => _remote.getHistory(warehouseId: warehouseId, from: from, to: to),
    );
  }

  @override
  Future<Either<Failure, TelemetryRecord?>> getLatest(String warehouseId) {
    return _call<TelemetryRecord?>(() => _remote.getLatest(warehouseId));
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Generic network-aware remote-call wrapper.
  Future<Either<Failure, T>> _call<T>(Future<T> Function() action) async {
    if (!await _networkInfo.isConnected) {
      return const Left(NoInternetFailure());
    }
    try {
      return Right(await action());
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
}
