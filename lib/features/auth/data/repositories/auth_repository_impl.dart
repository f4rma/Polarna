import 'package:dartz/dartz.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

typedef _RemoteCall<T> = Future<T> Function();

/// Concrete [AuthRepository] implementation.
///
/// Responsibilities:
///   - Guard every network call with [NetworkInfo.isConnected].
///   - Convert [AppException] → [Failure] using [_call] so individual methods
///     stay focused on their happy path.
///   - Enforce the account-lockout policy on [signIn] (5 consecutive failed
///     attempts → 15 minute lock) using [AuthLocalDataSource].
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;
  final NetworkInfo _networkInfo;

  const AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required AuthLocalDataSource local,
    required NetworkInfo networkInfo,
  })  : _remote = remote,
        _local = local,
        _networkInfo = networkInfo;

  // ---------------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------------

  @override
  Stream<UserEntity?> get authStateChanges => _remote.authStateChanges();

  // ---------------------------------------------------------------------------
  // Sign in (with account-lockout policy)
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, UserEntity>> signIn({
    required String email,
    required String password,
  }) async {
    if (!await _networkInfo.isConnected) {
      return const Left(NoInternetFailure());
    }

    // 1. Honour an existing local lock before contacting Firebase.
    final lockedResult = await _checkLocalLock(email);
    if (lockedResult != null) return Left(lockedResult);

    // 2. Try the remote call.
    try {
      final user = await _remote.signIn(email: email, password: password);
      await _local.resetFailedAttempts(email);
      return Right(user);
    } on InvalidCredentialsException {
      return Left(await _registerFailedAttempt(email));
    } on EmailNotVerifiedException {
      // Do NOT count verification failures towards the lock-out counter.
      return const Left(EmailNotVerifiedFailure());
    } on NoInternetException {
      return const Left(NoInternetFailure());
    } on AccountLockedException catch (e) {
      return Left(AccountLockedFailure(remainingMinutes: e.remainingMinutes));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  // ---------------------------------------------------------------------------
  // Sign up / Sign out / Reset / Current / Verify
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, UserEntity>> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required UserRole role,
  }) {
    return _call<UserEntity>(() => _remote.signUp(
          email: email,
          password: password,
          fullName: fullName,
          phoneNumber: phoneNumber,
          role: role,
        ));
  }

  @override
  Future<Either<Failure, Unit>> signOut() {
    return _call<Unit>(() async {
      await _remote.signOut();
      return unit;
    });
  }

  @override
  Future<Either<Failure, Unit>> resetPassword({required String email}) {
    return _call<Unit>(() async {
      await _remote.resetPassword(email: email);
      return unit;
    });
  }

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() {
    return _call<UserEntity?>(() => _remote.getCurrentUser());
  }

  @override
  Future<Either<Failure, Unit>> sendEmailVerification() {
    return _call<Unit>(() async {
      await _remote.sendEmailVerification();
      return unit;
    });
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Generic network-aware remote-call wrapper.
  ///
  /// Keeps individual methods free of `try/catch` sprawl by centralising the
  /// `AppException → Failure` mapping.  Not used by [signIn] because the
  /// lock-out policy requires branch-specific handling.
  Future<Either<Failure, T>> _call<T>(_RemoteCall<T> action) async {
    if (!await _networkInfo.isConnected) {
      return const Left(NoInternetFailure());
    }
    try {
      return Right(await action());
    } on EmailAlreadyInUseException {
      return const Left(EmailAlreadyInUseFailure());
    } on InvalidCredentialsException {
      return const Left(InvalidCredentialsFailure());
    } on EmailNotVerifiedException {
      return const Left(EmailNotVerifiedFailure());
    } on ResetLinkExpiredException {
      return const Left(ResetLinkExpiredFailure());
    } on AccountLockedException catch (e) {
      return Left(AccountLockedFailure(remainingMinutes: e.remainingMinutes));
    } on NoInternetException {
      return const Left(NoInternetFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  /// Returns an [AccountLockedFailure] if [email] is still inside an active
  /// lock-out window; otherwise `null`.  `getLockUntil` already returns
  /// `null` when the stored window has elapsed, so this method only
  /// computes the user-facing remaining-minutes value.
  Future<AccountLockedFailure?> _checkLocalLock(String email) async {
    final lockUntil = await _local.getLockUntil(email);
    if (lockUntil == null) return null;

    final remaining = lockUntil.difference(DateTime.now().toUtc());
    // Round up so "29 s remaining" reads as "1 minute" instead of "0".
    final minutes = remaining.inSeconds <= 0
        ? 0
        : ((remaining.inSeconds + 59) ~/ 60);
    return AccountLockedFailure(remainingMinutes: minutes);
  }

  /// Increments the failed-attempt counter for [email]; if it reaches
  /// [AppConstants.maxFailedLoginAttempts] the account is locked for
  /// [AppConstants.accountLockDurationMinutes] minutes.
  Future<AuthFailure> _registerFailedAttempt(String email) async {
    final attempts = await _local.incrementFailedAttempts(email);

    if (attempts >= AppConstants.maxFailedLoginAttempts) {
      final lockUntil = DateTime.now().toUtc().add(
            const Duration(minutes: AppConstants.accountLockDurationMinutes),
          );
      await _local.setLockUntil(email, lockUntil);
      return const AccountLockedFailure(
        remainingMinutes: AppConstants.accountLockDurationMinutes,
      );
    }
    return const InvalidCredentialsFailure();
  }
}
