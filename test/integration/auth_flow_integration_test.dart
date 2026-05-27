// Integration tests for the authentication flow.
//
// Validates: Requirements 1.1–1.12
// Reference: .kiro/specs/coldshare-platform/requirements.md#Requirement 1
//
// Tests the full multi-step auth flows at the provider/notifier level:
//   - Sign-up → sign-out → sign-in → verified user → state exposed
//   - Sign-in with unverified email → state stays null (gated)
//   - Sign-in with locked account → AccountLockedFailure
//   - Reset password flow → success message
//
// Uses FakeAuthRepository with ProviderContainer overrides.
// No Firebase, no mockito, no build_runner.

import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polarna/core/errors/failures.dart';
import 'package:polarna/features/auth/data/providers/auth_data_providers.dart';
import 'package:polarna/features/auth/domain/entities/user_entity.dart';
import 'package:polarna/features/auth/presentation/providers/auth_provider.dart';

import '../features/auth/fakes/fake_auth_repository.dart';

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

Future<void> _flushBootstrap() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

// ---------------------------------------------------------------------------
// Integration Tests
// ---------------------------------------------------------------------------

void main() {
  group('Auth Flow Integration — Full sign-up → sign-out → sign-in', () {
    test(
        'sign-up creates account (state stays null), '
        'then sign-in with verified user exposes state', () async {
      final repo = FakeAuthRepository();
      final unverifiedUser = _makeUser(verified: false);
      final verifiedUser = _makeUser(verified: true);

      // Step 1: Sign-up response (returns unverified user)
      repo.signUpResponses.add(Right(unverifiedUser));
      // Step 2: Sign-in response (returns verified user after email verified)
      repo.signInResponses.add(Right(verifiedUser));

      final container = _makeContainer(repo);
      container.read(authProvider);
      await _flushBootstrap();

      // --- Step 1: Sign up ---
      final signUpResult = await container.read(authProvider.notifier).signUp(
            email: unverifiedUser.email,
            password: 'StrongPass1!',
            fullName: unverifiedUser.fullName,
            phoneNumber: unverifiedUser.phoneNumber,
            role: unverifiedUser.role,
          );

      expect(signUpResult.isRight(), isTrue);
      // After sign-up, auto-sign-out is called → state is null
      expect(repo.signOutCallCount, 1);
      expect(
        container.read(authProvider),
        const AsyncValue<UserEntity?>.data(null),
      );

      // --- Step 2: Sign in with now-verified email ---
      final signInResult = await container
          .read(authProvider.notifier)
          .signIn(email: verifiedUser.email, password: 'StrongPass1!');

      expect(signInResult.isRight(), isTrue);
      expect(
        container.read(authProvider),
        AsyncValue<UserEntity?>.data(verifiedUser),
      );
    });

    test(
        'sign-in → sign-out → state returns to null', () async {
      final repo = FakeAuthRepository();
      final user = _makeUser(verified: true);

      repo.signInResponses.add(Right(user));
      repo.signOutResponses.add(const Right(unit));

      final container = _makeContainer(repo);
      container.read(authProvider);
      await _flushBootstrap();

      // Sign in
      await container
          .read(authProvider.notifier)
          .signIn(email: user.email, password: 'StrongPass1!');
      expect(container.read(authProvider).value, user);

      // Sign out
      final signOutResult =
          await container.read(authProvider.notifier).signOut();
      expect(signOutResult, const Right<Failure, Unit>(unit));
      expect(
        container.read(authProvider),
        const AsyncValue<UserEntity?>.data(null),
      );
    });
  });

  group('Auth Flow Integration — Unverified email gating', () {
    test('sign-in with unverified user → Right returned but state stays null',
        () async {
      final repo = FakeAuthRepository();
      final unverifiedUser = _makeUser(verified: false);
      repo.signInResponses.add(Right(unverifiedUser));

      final container = _makeContainer(repo);
      container.read(authProvider);
      await _flushBootstrap();

      final result = await container
          .read(authProvider.notifier)
          .signIn(email: unverifiedUser.email, password: 'StrongPass1!');

      // The use case returns the user (Right), but the notifier gates it
      expect(result.isRight(), isTrue);
      expect(
        container.read(authProvider),
        const AsyncValue<UserEntity?>.data(null),
      );
    });

    test(
        'authStateChanges emits unverified → state null, '
        'then emits verified → state exposed', () async {
      final repo = FakeAuthRepository();
      final container = _makeContainer(repo);
      container.read(authProvider);
      await _flushBootstrap();

      // Emit unverified user on stream
      repo.emitAuthState(_makeUser(verified: false));
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(authProvider),
        const AsyncValue<UserEntity?>.data(null),
      );

      // Emit verified user on stream (simulates user verifying email)
      final verified = _makeUser(verified: true);
      repo.emitAuthState(verified);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(authProvider),
        AsyncValue<UserEntity?>.data(verified),
      );
    });
  });

  group('Auth Flow Integration — Account locked', () {
    test('sign-in with locked account → AccountLockedFailure, state unchanged',
        () async {
      final repo = FakeAuthRepository();
      repo.signInResponses
          .add(const Left(AccountLockedFailure(remainingMinutes: 15)));

      final container = _makeContainer(repo);
      container.read(authProvider);
      await _flushBootstrap();

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
      expect(
        container.read(authProvider),
        const AsyncValue<UserEntity?>.data(null),
      );
    });
  });

  group('Auth Flow Integration — Reset password', () {
    test('reset password → Right(unit), state unchanged', () async {
      final repo = FakeAuthRepository();
      repo.resetPasswordResponses.add(const Right(unit));

      final container = _makeContainer(repo);
      container.read(authProvider);
      await _flushBootstrap();

      final result = await container
          .read(authProvider.notifier)
          .resetPassword(email: 'user@example.com');

      expect(result, const Right<Failure, Unit>(unit));
      // State should remain null (user not signed in)
      expect(
        container.read(authProvider),
        const AsyncValue<UserEntity?>.data(null),
      );
      expect(repo.resetPasswordCalls.single.email, 'user@example.com');
    });

    test('reset password with no internet → Left(NoInternetFailure)',
        () async {
      final repo = FakeAuthRepository();
      repo.resetPasswordResponses.add(const Left(NoInternetFailure()));

      final container = _makeContainer(repo);
      container.read(authProvider);
      await _flushBootstrap();

      final result = await container
          .read(authProvider.notifier)
          .resetPassword(email: 'user@example.com');

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<NoInternetFailure>()),
        (_) => fail('Expected Left'),
      );
    });
  });
}
