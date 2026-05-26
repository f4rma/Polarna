import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../booking/domain/entities/booking_entity.dart';
import '../../domain/entities/revenue_summary.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_remote_datasource.dart';

typedef _RemoteCall<T> = Future<T> Function();

/// Concrete [DashboardRepository] implementation.
///
/// Responsibilities:
///   - Guard every remote call with [NetworkInfo.isConnected].
///   - Centralise [AppException] → [Failure] mapping via [_call].
///   - Delegate all Firestore aggregation logic to [DashboardRemoteDataSource].
class DashboardRepositoryImpl implements DashboardRepository {
  final DashboardRemoteDataSource _remote;
  final NetworkInfo _networkInfo;

  const DashboardRepositoryImpl({
    required DashboardRemoteDataSource remote,
    required NetworkInfo networkInfo,
  })  : _remote = remote,
        _networkInfo = networkInfo;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, RevenueSummary>> getRevenueSummary(
    String mitraId,
  ) {
    return _call<RevenueSummary>(() => _remote.getRevenueSummary(mitraId));
  }

  @override
  Future<Either<Failure, List<BookingEntity>>> getActiveTransactions(
    String mitraId,
  ) {
    return _call<List<BookingEntity>>(() async {
      final list = await _remote.getActiveTransactions(mitraId);
      return List<BookingEntity>.from(list);
    });
  }

  @override
  Future<Either<Failure, List<BookingEntity>>> getAllTransactions({
    required String mitraId,
    DateTime? from,
    DateTime? to,
  }) {
    return _call<List<BookingEntity>>(() async {
      final list = await _remote.getAllTransactions(
        mitraId: mitraId,
        from: from,
        to: to,
      );
      return List<BookingEntity>.from(list);
    });
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Generic network-aware remote-call wrapper.
  ///
  /// Centralises the `AppException → Failure` mapping so the public
  /// methods stay focused on their happy path.
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
