import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/incident_log_entity.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/notification_datasource.dart';

typedef _RemoteCall<T> = Future<T> Function();

/// Concrete [NotificationRepository] implementation.
///
/// Responsibilities:
///   - Guard every remote call with [NetworkInfo.isConnected].
///   - Centralise [AppException] → [Failure] mapping via [_call].
class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationDataSource _dataSource;
  final NetworkInfo _networkInfo;

  const NotificationRepositoryImpl({
    required NotificationDataSource dataSource,
    required NetworkInfo networkInfo,
  })  : _dataSource = dataSource,
        _networkInfo = networkInfo;

  @override
  Future<Either<Failure, List<IncidentLogEntity>>> getIncidentLogs({
    String? warehouseId,
    DateTime? from,
    DateTime? to,
  }) {
    return _call<List<IncidentLogEntity>>(() async {
      final list = await _dataSource.getIncidentLogs(
        warehouseId: warehouseId,
        from: from,
        to: to,
      );
      return List<IncidentLogEntity>.from(list);
    });
  }

  @override
  Future<Either<Failure, IncidentLogEntity>> createIncidentLog(
    IncidentLogEntity log,
  ) {
    return _call<IncidentLogEntity>(() => _dataSource.createIncidentLog(log));
  }

  @override
  Future<Either<Failure, Unit>> resolveIncident(String logId) {
    return _call<Unit>(() async {
      await _dataSource.resolveIncident(logId, DateTime.now().toUtc());
      return unit;
    });
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Generic network-aware remote-call wrapper.
  Future<Either<Failure, T>> _call<T>(_RemoteCall<T> action) async {
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
