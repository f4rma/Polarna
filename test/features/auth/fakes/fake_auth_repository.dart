// Hand-rolled fake for [AuthRepository] used by AuthNotifier and use-case
// unit tests.
//
// No mockito / build_runner — plain Dart only. Responses are enqueued by the
// test; each call pops the next queued response. If a queue is empty when a
// method is called, a [StateError] is thrown so tests fail loudly instead of
// silently degrading.

import 'dart:async';
import 'dart:collection';

import 'package:dartz/dartz.dart';
import 'package:polarna/core/errors/failures.dart';
import 'package:polarna/features/auth/domain/entities/user_entity.dart';
import 'package:polarna/features/auth/domain/repositories/auth_repository.dart';

/// Captured arguments of a single `signIn` call.
class SignInCall {
  final String email;
  final String password;
  const SignInCall(this.email, this.password);
}

/// Captured arguments of a single `signUp` call.
class SignUpCall {
  final String email;
  final String password;
  final String fullName;
  final String phoneNumber;
  final UserRole role;
  const SignUpCall({
    required this.email,
    required this.password,
    required this.fullName,
    required this.phoneNumber,
    required this.role,
  });
}

/// Captured arguments of a single `resetPassword` call.
class ResetPasswordCall {
  final String email;
  const ResetPasswordCall(this.email);
}

class FakeAuthRepository implements AuthRepository {
  // ---------------------------------------------------------------------------
  // Response queues — tests enqueue responses in the order they expect them.
  // ---------------------------------------------------------------------------

  final Queue<Either<Failure, UserEntity>> signInResponses = Queue();
  final Queue<Either<Failure, UserEntity>> signUpResponses = Queue();
  final Queue<Either<Failure, Unit>> signOutResponses = Queue();
  final Queue<Either<Failure, Unit>> resetPasswordResponses = Queue();
  final Queue<Either<Failure, Unit>> sendEmailVerificationResponses = Queue();
  final Queue<Either<Failure, UserEntity?>> getCurrentUserResponses = Queue();

  // ---------------------------------------------------------------------------
  // Invocation log — tests assert on call counts and arguments.
  // ---------------------------------------------------------------------------

  final List<SignInCall> signInCalls = [];
  final List<SignUpCall> signUpCalls = [];
  int signOutCallCount = 0;
  final List<ResetPasswordCall> resetPasswordCalls = [];
  int sendEmailVerificationCallCount = 0;
  int getCurrentUserCallCount = 0;

  // ---------------------------------------------------------------------------
  // Auth-state stream.
  // ---------------------------------------------------------------------------

  final StreamController<UserEntity?> authStateController =
      StreamController<UserEntity?>.broadcast();

  /// Convenience — emit a value on the auth-state stream.
  void emitAuthState(UserEntity? user) => authStateController.add(user);

  Future<void> dispose() => authStateController.close();

  @override
  Stream<UserEntity?> get authStateChanges => authStateController.stream;

  // ---------------------------------------------------------------------------
  // Repository API.
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, UserEntity>> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls.add(SignInCall(email, password));
    if (signInResponses.isEmpty) {
      throw StateError('No signInResponses queued for signIn($email)');
    }
    return signInResponses.removeFirst();
  }

  @override
  Future<Either<Failure, UserEntity>> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required UserRole role,
  }) async {
    signUpCalls.add(SignUpCall(
      email: email,
      password: password,
      fullName: fullName,
      phoneNumber: phoneNumber,
      role: role,
    ));
    if (signUpResponses.isEmpty) {
      throw StateError('No signUpResponses queued for signUp($email)');
    }
    return signUpResponses.removeFirst();
  }

  @override
  Future<Either<Failure, Unit>> signOut() async {
    signOutCallCount += 1;
    if (signOutResponses.isEmpty) {
      // Default to success — signUp auto-calls signOut and most tests don't
      // care about the exact outcome beyond "it ran".
      return const Right(unit);
    }
    return signOutResponses.removeFirst();
  }

  @override
  Future<Either<Failure, Unit>> resetPassword({required String email}) async {
    resetPasswordCalls.add(ResetPasswordCall(email));
    if (resetPasswordResponses.isEmpty) {
      throw StateError('No resetPasswordResponses queued');
    }
    return resetPasswordResponses.removeFirst();
  }

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async {
    getCurrentUserCallCount += 1;
    if (getCurrentUserResponses.isEmpty) {
      // Default to "signed out" so AuthNotifier bootstrap resolves cleanly
      // when a test doesn't care about the initial user.
      return const Right(null);
    }
    return getCurrentUserResponses.removeFirst();
  }

  @override
  Future<Either<Failure, Unit>> sendEmailVerification() async {
    sendEmailVerificationCallCount += 1;
    if (sendEmailVerificationResponses.isEmpty) {
      throw StateError('No sendEmailVerificationResponses queued');
    }
    return sendEmailVerificationResponses.removeFirst();
  }
}
