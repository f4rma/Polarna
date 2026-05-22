import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/user_entity.dart';

/// Contract for the authentication data layer.
///
/// The implementation lives under `data/repositories/` and wraps
/// Firebase Auth + Firestore. All operations return
/// `Either<Failure, T>` so the domain layer never throws.
abstract class AuthRepository {
  /// Emits the currently signed-in user (or `null` when signed out)
  /// whenever the auth state changes.
  Stream<UserEntity?> get authStateChanges;

  /// Sign in with email and password.
  Future<Either<Failure, UserEntity>> signIn({
    required String email,
    required String password,
  });

  /// Create a new account.
  Future<Either<Failure, UserEntity>> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required UserRole role,
  });

  /// Sign out the current user.
  Future<Either<Failure, Unit>> signOut();

  /// Send a password-reset email to [email].
  Future<Either<Failure, Unit>> resetPassword({required String email});

  /// Returns the cached current user, or `null` when signed out.
  Future<Either<Failure, UserEntity?>> getCurrentUser();

  /// Send an email-verification link to the signed-in user.
  Future<Either<Failure, Unit>> sendEmailVerification();
}
