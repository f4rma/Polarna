// Unit tests for [AuthNotifier].
//
// Validates: Requirements 1.1, 1.4, 1.5, 1.6, 1.8, 1.10, 1.11, 1.12
// Reference: .kiro/specs/coldshare-platform/requirements.md#Requirement 1
//
// Covers:
//   - Sign-in success (verified user) / unverified-user gating / failure
//     modes (invalid credentials, locked account, unverified email).
//   - Sign-up success (auto-signs-out the fresh Firebase user) and failure.
//   - Sign-out resets the exposed state to `data(null)`.
//   - Reset password success/failure.
//   - Resend email verification success/failure.
//   - `authStateChanges` bootstrap / live updates (gated on verified flag).
//
// A hand-rolled fake repository is injected via the `authRepositoryProvider`
// override. No Firebase, no mockito, no build_runner.

import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polarna/core/errors/failures.dart';
import 'package:polarna/features/auth/data/providers/auth_data_providers.dart';
import 'package:polarna/features/auth/domain/entities/user_entity.dart';
import 'package:polarna/features/auth/presentation/providers/auth_provider.dart';

import 'fakes/fake_auth_repository.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

UserEntity _makeUser({
  String uid = 'uid-1',
  String email = 'user@example.com',
  bool verified = true,
  UserRole role = UserRole.umkm,
}) {
  return UserEntity(
    uid: uid,
    email: email,
    fullName: 'Test User',
    phoneNumber: '+6281234567890',
    role: role,
    isEmailVerified: verified,
    isActive: true,
    createdAt: DateTime.utc(2024, 1, 1),
  );
}

/// Builds a [ProviderContainer] with the auth repository overridden to
/// [repo] and wires cleanup via [addTearDown].
ProviderContainer _makeContainer(FakeAuthRepository repo) {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWith((ref) async => repo),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(repo.dispose);
  return container;
}

/// Awaits the AuthNotifier's async bootstrap (reads `authRepositoryProvider`
/// and seeds initial state via `getCurrentUser`).
Future<void> _flushBootstrap() async {
  // Two microtasks: one for the provider future to resolve, one for
  // `getCurrentUser` / initial stream emission to land in state.
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  // -------------------------------------------------------------------------
  group('AuthNotifier.signIn', () {
    test('success with verified user → state becomes data(user)', () async {
      final repo = FakeAuthRepository();
      final user = _makeUser(verified: true);
      repo.signInResponses.add(Right(user));

      final container = _makeContainer(repo);
      // Trigger notifier creation and bootstrap.
      container.read(authProvider);
      await _flushBootstrap();

      final result = await container
          .read(authProvider.notifier)
          .signIn(email: user.email, password: 'StrongPass1');

      expect(result, Right<Failure, UserEntity>(user));
      expect(container.read(authProvider), AsyncValue<UserEntity?>.data(user));
      expect(repo.signInCalls, hasLength(1));
      expect(repo.signInCalls.single.email, user.email);
      expect(repo.signInCalls.single.password, 'StrongPass1');
    });

    test('success but unverified user → Right(user) but state stays null',
        () async {
      final repo = FakeAuthRepository();
      final unverified = _makeUser(verified: false);
      repo.signInResponses.add(Right(unverified));

      final container = _makeContainer(repo);
      container.read(authProvider);
      await _flushBootstrap();

      final result = await container
          .read(authProvider.notifier)
          .signIn(email: unverified.email, password: 'StrongPass1');

      expect(result.isRight(), isTrue);
      // Gate: unverified user MUST NOT be exposed as authenticated.
      expect(container.read(authProvider),
          const AsyncValue<UserEntity?>.data(null));
    });

    test('InvalidCredentialsFailure → Left returned, state unchanged',
        () async {
      final repo = FakeAuthRepository();
      repo.signInResponses.add(const Left(InvalidCredentialsFailure()));

      final container = _makeContainer(repo);
      container.read(authProvider);
      await _flushBootstrap();
      final stateBefore = container.read(authProvider);

      final result = await container
          .read(authProvider.notifier)
          .signIn(email: 'wrong@example.com', password: 'bad');

      expect(result, const Left<Failure, UserEntity>(InvalidCredentialsFailure()));
      expect(container.read(authProvider), stateBefore);
    });

    test('AccountLockedFailure(remainingMinutes: 15) → Left, state unchanged',
        () async {
      final repo = FakeAuthRepository();
      repo.signInResponses
          .add(const Left(AccountLockedFailure(remainingMinutes: 15)));

      final container = _makeContainer(repo);
      container.read(authProvider);
      await _flushBootstrap();
      final stateBefore = container.read(authProvider);

      final result = await container
          .read(authProvider.notifier)
          .signIn(email: 'locked@example.com', password: 'bad');

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) {
          expect(f, isA<AccountLockedFailure>());
          expect((f as AccountLockedFailure).remainingMinutes, 15);
        },
        (_) => fail('Expected Left'),
      );
      expect(container.read(authProvider), stateBefore);
    });

    test('EmailNotVerifiedFailure → Left returned', () async {
      final repo = FakeAuthRepository();
      repo.signInResponses.add(const Left(EmailNotVerifiedFailure()));

      final container = _makeContainer(repo);
      container.read(authProvider);
      await _flushBootstrap();

      final result = await container
          .read(authProvider.notifier)
          .signIn(email: 'unverified@example.com', password: 'StrongPass1');

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<EmailNotVerifiedFailure>()),
        (_) => fail('Expected Left'),
      );
    });
  });

  // -------------------------------------------------------------------------
  group('AuthNotifier.signUp', () {
    test('success → Right(user), repo.signOut called, state stays null',
        () async {
      final repo = FakeAuthRepository();
      final user = _makeUser(verified: false);
      repo.signUpResponses.add(Right(user));

      final container = _makeContainer(repo);
      container.read(authProvider);
      await _flushBootstrap();

      final result = await container.read(authProvider.notifier).signUp(
            email: user.email,
            password: 'StrongPass1',
            fullName: user.fullName,
            phoneNumber: user.phoneNumber,
            role: user.role,
          );

      expect(result, Right<Failure, UserEntity>(user));
      // signUp MUST sign the auto-signed-in Firebase user back out
      // (requirement 1.10 — login is only permitted after verification).
      expect(repo.signOutCallCount, 1);
      expect(container.read(authProvider),
          const AsyncValue<UserEntity?>.data(null));
      expect(repo.signUpCalls, hasLength(1));
      expect(repo.signUpCalls.single.email, user.email);
      expect(repo.signUpCalls.single.role, user.role);
    });

    test('EmailAlreadyInUseFailure → Left, signOut NOT called', () async {
      final repo = FakeAuthRepository();
      repo.signUpResponses.add(const Left(EmailAlreadyInUseFailure()));

      final container = _makeContainer(repo);
      container.read(authProvider);
      await _flushBootstrap();

      final result = await container.read(authProvider.notifier).signUp(
            email: 'taken@example.com',
            password: 'StrongPass1',
            fullName: 'Someone',
            phoneNumber: '+6281234567890',
            role: UserRole.umkm,
          );

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<EmailAlreadyInUseFailure>()),
        (_) => fail('Expected Left'),
      );
      expect(repo.signOutCallCount, 0);
    });
  });

  // -------------------------------------------------------------------------
  group('AuthNotifier.signOut', () {
    test('success → state becomes data(null), returns Right(unit)', () async {
      final repo = FakeAuthRepository();
      final user = _makeUser(verified: true);
      repo.getCurrentUserResponses.add(Right(user));
      repo.signOutResponses.add(const Right(unit));

      final container = _makeContainer(repo);
      container.read(authProvider);
      await _flushBootstrap();

      // Sanity: bootstrap loaded the verified user.
      expect(container.read(authProvider).value, user);

      final result = await container.read(authProvider.notifier).signOut();

      expect(result, const Right<Failure, Unit>(unit));
      expect(container.read(authProvider),
          const AsyncValue<UserEntity?>.data(null));
      expect(repo.signOutCallCount, 1);
    });
  });

  // -------------------------------------------------------------------------
  group('AuthNotifier.resetPassword', () {
    test('success → Right(unit), state unchanged', () async {
      final repo = FakeAuthRepository();
      repo.resetPasswordResponses.add(const Right(unit));

      final container = _makeContainer(repo);
      container.read(authProvider);
      await _flushBootstrap();
      final stateBefore = container.read(authProvider);

      final result = await container
          .read(authProvider.notifier)
          .resetPassword(email: 'u@example.com');

      expect(result, const Right<Failure, Unit>(unit));
      expect(container.read(authProvider), stateBefore);
      expect(repo.resetPasswordCalls.single.email, 'u@example.com');
    });

    test('NoInternetFailure → Left returned', () async {
      final repo = FakeAuthRepository();
      repo.resetPasswordResponses.add(const Left(NoInternetFailure()));

      final container = _makeContainer(repo);
      container.read(authProvider);
      await _flushBootstrap();

      final result = await container
          .read(authProvider.notifier)
          .resetPassword(email: 'u@example.com');

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<NoInternetFailure>()),
        (_) => fail('Expected Left'),
      );
    });

    test('ResetLinkExpiredFailure → Left returned', () async {
      final repo = FakeAuthRepository();
      repo.resetPasswordResponses.add(const Left(ResetLinkExpiredFailure()));

      final container = _makeContainer(repo);
      container.read(authProvider);
      await _flushBootstrap();

      final result = await container
          .read(authProvider.notifier)
          .resetPassword(email: 'u@example.com');

      result.fold(
        (f) => expect(f, isA<ResetLinkExpiredFailure>()),
        (_) => fail('Expected Left'),
      );
    });
  });

  // -------------------------------------------------------------------------
  group('AuthNotifier.resendEmailVerification', () {
    test('success → Right(unit)', () async {
      final repo = FakeAuthRepository();
      repo.sendEmailVerificationResponses.add(const Right(unit));

      final container = _makeContainer(repo);
      container.read(authProvider);
      await _flushBootstrap();

      final result = await container
          .read(authProvider.notifier)
          .resendEmailVerification();

      expect(result, const Right<Failure, Unit>(unit));
      expect(repo.sendEmailVerificationCallCount, 1);
    });

    test('failure → Left returned', () async {
      final repo = FakeAuthRepository();
      repo.sendEmailVerificationResponses
          .add(const Left(NoInternetFailure()));

      final container = _makeContainer(repo);
      container.read(authProvider);
      await _flushBootstrap();

      final result = await container
          .read(authProvider.notifier)
          .resendEmailVerification();

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<NoInternetFailure>()),
        (_) => fail('Expected Left'),
      );
    });
  });

  // -------------------------------------------------------------------------
  group('AuthNotifier.authStateChanges bootstrap', () {
    test('emits verified user → state becomes data(user)', () async {
      final repo = FakeAuthRepository();
      final container = _makeContainer(repo);
      container.read(authProvider);
      await _flushBootstrap();

      final verified = _makeUser(verified: true);
      repo.emitAuthState(verified);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(authProvider),
          AsyncValue<UserEntity?>.data(verified));
    });

    test('emits unverified user → state stays data(null) (gated)', () async {
      final repo = FakeAuthRepository();
      final container = _makeContainer(repo);
      container.read(authProvider);
      await _flushBootstrap();

      repo.emitAuthState(_makeUser(verified: false));
      await Future<void>.delayed(Duration.zero);

      expect(container.read(authProvider),
          const AsyncValue<UserEntity?>.data(null));
    });

    test('emits null (signed out) → state becomes data(null)', () async {
      final repo = FakeAuthRepository();
      final verified = _makeUser(verified: true);
      repo.getCurrentUserResponses.add(Right(verified));

      final container = _makeContainer(repo);
      container.read(authProvider);
      await _flushBootstrap();

      // Bootstrap seeded the verified user.
      expect(container.read(authProvider).value, verified);

      repo.emitAuthState(null);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(authProvider),
          const AsyncValue<UserEntity?>.data(null));
    });
  });
}
