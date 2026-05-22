import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/services/account_store.dart';
import '../../data/providers/auth_data_providers.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/reset_password_usecase.dart';
import '../../domain/usecases/sign_in_usecase.dart';
import '../../domain/usecases/sign_out_usecase.dart';
import '../../domain/usecases/sign_up_usecase.dart';

/// Central auth state notifier.
///
/// Exposes the canonical `authProvider` of type
/// `StateNotifierProvider<AuthNotifier, AsyncValue<UserEntity?>>` that the
/// router (`lib/core/router/app_router.dart`) reads. The public shape
/// (`AsyncValue<UserEntity?>` where `null` = unauthenticated) is preserved
/// so existing consumers keep working.
///
/// Responsibilities:
///   * bootstrap the current user at startup and subscribe to Firebase's
///     auth-state stream so the router reacts to sign-in/out events,
///   * expose one `Either<Failure, T>` method per auth action
///     (`signIn`, `signUp`, `signOut`, `resetPassword`,
///     `resendEmailVerification`) that the UI calls directly,
///   * filter unverified accounts from the public state so the router does
///     not redirect a user who failed the email-verification gate.
class AuthNotifier extends StateNotifier<AsyncValue<UserEntity?>> {
  AuthNotifier(this._ref) : super(const AsyncValue<UserEntity?>.loading()) {
    _bootstrap();
  }

  final Ref _ref;
  StreamSubscription<UserEntity?>? _sub;

  // ---------------------------------------------------------------------------
  // Bootstrap
  // ---------------------------------------------------------------------------

  Future<void> _bootstrap() async {
    try {
      final repo = await _ref.read(authRepositoryProvider.future);

      // Subscribe to auth-state changes first so we don't miss the initial
      // emission from Firebase.
      _sub = repo.authStateChanges.listen(
        (user) {
          if (!mounted) return;
          state = AsyncValue<UserEntity?>.data(_gate(user));
        },
        onError: (Object e, StackTrace st) {
          if (mounted) state = AsyncValue<UserEntity?>.error(e, st);
        },
      );

      // Seed the initial state synchronously (covers the warm-start case
      // where Firebase Auth already has a cached user).
      final result = await repo.getCurrentUser();
      if (!mounted) return;
      state = result.fold(
        (_) => const AsyncValue<UserEntity?>.data(null),
        (user) => AsyncValue<UserEntity?>.data(_gate(user)),
      );
    } catch (e, st) {
      if (mounted) state = AsyncValue<UserEntity?>.error(e, st);
    }
  }

  /// Blocks unverified accounts from being exposed as "authenticated".
  ///
  /// A user may appear in [AuthRepository.authStateChanges] immediately
  /// after a successful Firebase sign-in even when their email has not
  /// been verified (the repository surfaces this as
  /// [EmailNotVerifiedFailure]).  Gating here keeps the router on `/login`
  /// while still allowing `resendEmailVerification` to work, since the
  /// underlying Firebase user remains signed in.
  UserEntity? _gate(UserEntity? user) {
    if (user == null) return null;
    if (!user.isEmailVerified) return null;
    return user;
  }

  Future<AuthRepository> _repo() =>
      _ref.read(authRepositoryProvider.future);

  // ---------------------------------------------------------------------------
  // Public actions
  // ---------------------------------------------------------------------------

  /// Attempts to sign a user in with [email] and [password].
  Future<Either<Failure, UserEntity>> signIn({
    required String email,
    required String password,
  }) async {
    final repo = await _repo();
    final result = await SignInUseCase(repo).call(
      SignInParams(email: email, password: password),
    );
    result.fold(
      (_) {},
      (user) {
        if (mounted) state = AsyncValue<UserEntity?>.data(_gate(user));
        // Save credentials for quick account switching (demo feature).
        _saveAccountForSwitching(
          email: email,
          password: password,
          fullName: user.fullName,
          role: user.role.name,
        );
      },
    );
    return result;
  }

  /// Persists account credentials for the quick-switch feature.
  Future<void> _saveAccountForSwitching({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    try {
      final store = await _ref.read(accountStoreProvider.future);
      await store.saveAccount(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
      );
    } catch (_) {
      // Non-critical — silently ignore failures.
    }
  }

  /// Registers a new account.
  ///
  /// On success the newly-created Firebase user is signed out so the caller
  /// can redirect to `/login` — per requirement 1.10, login is only
  /// permitted once the email has been verified.
  Future<Either<Failure, UserEntity>> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required UserRole role,
  }) async {
    final repo = await _repo();
    final result = await SignUpUseCase(repo).call(
      SignUpParams(
        email: email,
        password: password,
        fullName: fullName,
        phoneNumber: phoneNumber,
        role: role,
      ),
    );
    if (result.isRight()) {
      // Firebase auto-signs-in the newly-created user; immediately sign
      // them out so the verification flow is enforced.
      await repo.signOut();
      if (mounted) {
        state = const AsyncValue<UserEntity?>.data(null);
      }
    }
    return result;
  }

  /// Signs the current user out.
  Future<Either<Failure, Unit>> signOut() async {
    final repo = await _repo();
    final result = await SignOutUseCase(repo).call();
    if (result.isRight() && mounted) {
      state = const AsyncValue<UserEntity?>.data(null);
    }
    return result;
  }

  /// Requests a password-reset email.
  Future<Either<Failure, Unit>> resetPassword({
    required String email,
  }) async {
    final repo = await _repo();
    return ResetPasswordUseCase(repo).call(
      ResetPasswordParams(email: email),
    );
  }

  /// Resends the verification email for the currently signed-in (but
  /// unverified) Firebase user.
  Future<Either<Failure, Unit>> resendEmailVerification() async {
    final repo = await _repo();
    return repo.sendEmailVerification();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Canonical auth provider consumed by the router and every page.
final authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<UserEntity?>>(
  (ref) => AuthNotifier(ref),
);
