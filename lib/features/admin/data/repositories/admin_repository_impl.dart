import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../domain/entities/platform_summary.dart';
import '../../domain/repositories/admin_repository.dart';
import '../datasources/admin_remote_datasource.dart';

typedef _RemoteCall<T> = Future<T> Function();

/// Concrete [AdminRepository] implementation.
///
/// Responsibilities:
///   - Guard every network call with [NetworkInfo.isConnected].
///   - Convert [AppException] → [Failure] using [_call] so individual methods
///     stay focused on their happy path.
class AdminRepositoryImpl implements AdminRepository {
  final AdminRemoteDataSource _remote;
  final NetworkInfo _networkInfo;

  const AdminRepositoryImpl({
    required AdminRemoteDataSource remote,
    required NetworkInfo networkInfo,
  })  : _remote = remote,
        _networkInfo = networkInfo;

  // ---------------------------------------------------------------------------
  // User management
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, Unit>> activateUser(String userId) {
    return _call<Unit>(() async {
      await _remote.activateUser(userId);
      return unit;
    });
  }

  @override
  Future<Either<Failure, Unit>> deactivateUser(String userId) {
    return _call<Unit>(() async {
      await _remote.deactivateUser(userId);
      return unit;
    });
  }

  // ---------------------------------------------------------------------------
  // Platform summary
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, PlatformSummary>> getPlatformSummary() {
    return _call<PlatformSummary>(() => _remote.getPlatformSummary());
  }

  // ---------------------------------------------------------------------------
  // User listing
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, List<UserEntity>>> getAllUsers() {
    return _call<List<UserEntity>>(() async {
      final models = await _remote.getAllUsers();
      return List<UserEntity>.from(models);
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
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
