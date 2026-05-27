// Unit tests for the auth use cases.
//
// Validates: Requirements 1.1, 1.4, 1.5, 1.6, 1.8
// Reference: .kiro/specs/coldshare-platform/requirements.md#Requirement 1
//
// Focus: each use case is a thin pass-through. The tests verify that the
// repository is called exactly once with the same arguments supplied to the
// use case and that the repository's [Either] is returned unchanged.

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polarna/core/errors/failures.dart';
import 'package:polarna/features/auth/domain/entities/user_entity.dart';
import 'package:polarna/features/auth/domain/usecases/reset_password_usecase.dart';
import 'package:polarna/features/auth/domain/usecases/sign_in_usecase.dart';
import 'package:polarna/features/auth/domain/usecases/sign_out_usecase.dart';
import 'package:polarna/features/auth/domain/usecases/sign_up_usecase.dart';

import 'fakes/fake_auth_repository.dart';

UserEntity _makeUser({bool verified = true}) => UserEntity(
      uid: 'uid-1',
      email: 'user@example.com',
      fullName: 'Test User',
      phoneNumber: '+6281234567890',
      role: UserRole.umkm,
      isEmailVerified: verified,
      isActive: true,
      createdAt: DateTime.utc(2024, 1, 1),
    );

void main() {
  group('SignInUseCase', () {
    test('delegates email and password to repo.signIn', () async {
      final repo = FakeAuthRepository();
      addTearDown(repo.dispose);
      final user = _makeUser();
      repo.signInResponses.add(Right(user));

      final useCase = SignInUseCase(repo);
      final result = await useCase.call(
        const SignInParams(email: 'user@example.com', password: 'StrongPass1'),
      );

      expect(result, Right<Failure, UserEntity>(user));
      expect(repo.signInCalls, hasLength(1));
      expect(repo.signInCalls.single.email, 'user@example.com');
      expect(repo.signInCalls.single.password, 'StrongPass1');
    });

    test('propagates Left from the repository', () async {
      final repo = FakeAuthRepository();
      addTearDown(repo.dispose);
      repo.signInResponses.add(const Left(InvalidCredentialsFailure()));

      final result = await SignInUseCase(repo).call(
        const SignInParams(email: 'user@example.com', password: 'bad'),
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<InvalidCredentialsFailure>()),
        (_) => fail('Expected Left'),
      );
    });
  });

  group('SignUpUseCase', () {
    test('delegates every parameter to repo.signUp', () async {
      final repo = FakeAuthRepository();
      addTearDown(repo.dispose);
      final user = _makeUser(verified: false);
      repo.signUpResponses.add(Right(user));

      final params = const SignUpParams(
        email: 'new@example.com',
        password: 'StrongPass1',
        fullName: 'New User',
        phoneNumber: '+6281234567890',
        role: UserRole.mitra,
      );

      final result = await SignUpUseCase(repo).call(params);

      expect(result, Right<Failure, UserEntity>(user));
      expect(repo.signUpCalls, hasLength(1));
      final call = repo.signUpCalls.single;
      expect(call.email, params.email);
      expect(call.password, params.password);
      expect(call.fullName, params.fullName);
      expect(call.phoneNumber, params.phoneNumber);
      expect(call.role, params.role);
    });

    test('propagates Left from the repository', () async {
      final repo = FakeAuthRepository();
      addTearDown(repo.dispose);
      repo.signUpResponses.add(const Left(EmailAlreadyInUseFailure()));

      final result = await SignUpUseCase(repo).call(
        const SignUpParams(
          email: 'taken@example.com',
          password: 'StrongPass1',
          fullName: 'Someone',
          phoneNumber: '+6281234567890',
          role: UserRole.umkm,
        ),
      );

      result.fold(
        (f) => expect(f, isA<EmailAlreadyInUseFailure>()),
        (_) => fail('Expected Left'),
      );
    });
  });

  group('SignOutUseCase', () {
    test('delegates to repo.signOut', () async {
      final repo = FakeAuthRepository();
      addTearDown(repo.dispose);
      repo.signOutResponses.add(const Right(unit));

      final result = await SignOutUseCase(repo).call();

      expect(result, const Right<Failure, Unit>(unit));
      expect(repo.signOutCallCount, 1);
    });
  });

  group('ResetPasswordUseCase', () {
    test('delegates email to repo.resetPassword', () async {
      final repo = FakeAuthRepository();
      addTearDown(repo.dispose);
      repo.resetPasswordResponses.add(const Right(unit));

      final result = await ResetPasswordUseCase(repo).call(
        const ResetPasswordParams(email: 'u@example.com'),
      );

      expect(result, const Right<Failure, Unit>(unit));
      expect(repo.resetPasswordCalls, hasLength(1));
      expect(repo.resetPasswordCalls.single.email, 'u@example.com');
    });

    test('propagates ResetLinkExpiredFailure from the repository', () async {
      final repo = FakeAuthRepository();
      addTearDown(repo.dispose);
      repo.resetPasswordResponses.add(const Left(ResetLinkExpiredFailure()));

      final result = await ResetPasswordUseCase(repo).call(
        const ResetPasswordParams(email: 'u@example.com'),
      );

      result.fold(
        (f) => expect(f, isA<ResetLinkExpiredFailure>()),
        (_) => fail('Expected Left'),
      );
    });
  });
}
