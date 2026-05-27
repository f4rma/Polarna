// Property tests for account lock-out after consecutive failed logins.
//
// Validates: Requirements 1.11
// Reference: .kiro/specs/coldshare-platform/requirements.md#Requirement 1
//
// Property 3: Penguncian Akun Setelah Percobaan Gagal
//   WHEN pengguna gagal login sebanyak 5 kali berturut-turut, THE
//   Auth_Service SHALL mengunci akun selama 15 menit dan menampilkan pesan
//   "Akun dikunci sementara. Coba lagi dalam 15 menit".
//
// The tests wire `AuthRepositoryImpl` against hand-rolled in-memory fakes
// (no `shared_preferences`, no Firebase, no mockito/codegen) so every
// iteration stays hermetic and fast.

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
// `glados` re-exports `package:test/test.dart`, which collides with
// `flutter_test`. Hide the duplicates so the flutter_test versions win.
// ignore: depend_on_referenced_packages
import 'package:glados/glados.dart' hide test, group, expect;
import 'package:polarna/core/constants/app_constants.dart';
import 'package:polarna/core/errors/exceptions.dart';
import 'package:polarna/core/errors/failures.dart';
import 'package:polarna/core/network/network_info.dart';
import 'package:polarna/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:polarna/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:polarna/features/auth/data/models/user_model.dart';
import 'package:polarna/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:polarna/features/auth/domain/entities/user_entity.dart';

// ---------------------------------------------------------------------------
// In-memory fakes
// ---------------------------------------------------------------------------

String _normalize(String email) => email.trim().toLowerCase();

/// In-memory replacement for [AuthLocalDataSourceImpl]. Mirrors the real
/// implementation's key-normalisation and lock-expiry semantics.
class FakeAuthLocalDataSource implements AuthLocalDataSource {
  final Map<String, int> _attempts = {};
  final Map<String, DateTime> _lockUntil = {};

  @override
  Future<int> getFailedAttempts(String email) async =>
      _attempts[_normalize(email)] ?? 0;

  @override
  Future<int> incrementFailedAttempts(String email) async {
    final k = _normalize(email);
    final next = (_attempts[k] ?? 0) + 1;
    _attempts[k] = next;
    return next;
  }

  @override
  Future<void> resetFailedAttempts(String email) async {
    final k = _normalize(email);
    _attempts.remove(k);
    _lockUntil.remove(k);
  }

  @override
  Future<DateTime?> getLockUntil(String email) async {
    final until = _lockUntil[_normalize(email)];
    if (until == null) return null;
    if (!DateTime.now().toUtc().isBefore(until)) return null;
    return until;
  }

  @override
  Future<void> setLockUntil(String email, DateTime lockUntil) async {
    _lockUntil[_normalize(email)] = lockUntil.toUtc();
  }
}

/// Remote data source that always signals "credentials rejected".
class AlwaysFailingAuthRemote implements AuthRemoteDataSource {
  @override
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    throw const InvalidCredentialsException();
  }

  @override
  Stream<UserEntity?> authStateChanges() => const Stream.empty();

  @override
  Future<UserModel?> getCurrentUser() async => null;

  @override
  Future<void> resetPassword({required String email}) =>
      throw UnimplementedError();

  @override
  Future<void> sendEmailVerification() => throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();

  @override
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required UserRole role,
  }) =>
      throw UnimplementedError();
}

class AlwaysConnectedNetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;

  @override
  Stream<bool> get onConnectivityChanged => const Stream.empty();
}

// ---------------------------------------------------------------------------
// Helpers & generators
// ---------------------------------------------------------------------------

AuthRepositoryImpl _buildRepo() => AuthRepositoryImpl(
      remote: AlwaysFailingAuthRemote(),
      local: FakeAuthLocalDataSource(),
      networkInfo: AlwaysConnectedNetworkInfo(),
    );

Future<Either<Failure, UserEntity>> _attempt(
  AuthRepositoryImpl repo, {
  String email = 'user@example.com',
  String password = 'wrong-password',
}) =>
    repo.signIn(email: email, password: password);

/// Generator of lowercase, well-formed emails for the per-email isolation
/// property. Kept narrow so we avoid normalisation collisions.
Generator<String> _emailGen() => any
    .listWithLengthInRange(
        3, 9, any.choose('abcdefghijklmnopqrstuvwxyz0123456789'.split('')))
    .map((chars) => '${chars.join()}@ex.id');

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  const maxFail = AppConstants.maxFailedLoginAttempts; // 5
  const lockMinutes = AppConstants.accountLockDurationMinutes; // 15

  group('Property 3: Penguncian Akun - Requirement 1.11', () {
    // -----------------------------------------------------------------------
    // P3.A — attempts 1..(maxFail-1) are plain credential failures.
    // intInRange(min, max) is [min, max) → [1, 4] inclusive.
    // -----------------------------------------------------------------------
    Glados(any.intInRange(1, maxFail)).test(
      'attempts 1..${maxFail - 1} return InvalidCredentialsFailure (not locked)',
      (attemptNumber) async {
        final repo = _buildRepo();
        Either<Failure, UserEntity>? result;
        for (var i = 1; i <= attemptNumber; i++) {
          result = await _attempt(repo);
        }
        expect(result, isNotNull);
        expect(result!.isLeft(), isTrue);
        result.fold(
          (f) {
            expect(f, isA<InvalidCredentialsFailure>(),
                reason:
                    'Attempt #$attemptNumber must not be locked yet (< $maxFail)');
            expect(f, isNot(isA<AccountLockedFailure>()));
          },
          (_) => fail('Expected failure'),
        );
      },
    );

    // -----------------------------------------------------------------------
    // P3.B — the 5th attempt itself locks and reports 15 remaining minutes.
    // -----------------------------------------------------------------------
    test('the ${maxFail}th failure locks the account with $lockMinutes min',
        () async {
      final repo = _buildRepo();
      for (var i = 1; i < maxFail; i++) {
        final r = await _attempt(repo);
        r.fold(
          (f) => expect(f, isA<InvalidCredentialsFailure>()),
          (_) => fail('Expected failure on attempt $i'),
        );
      }
      final locking = await _attempt(repo);
      locking.fold(
        (f) {
          expect(f, isA<AccountLockedFailure>());
          expect((f as AccountLockedFailure).remainingMinutes, lockMinutes);
          expect(f.message, contains('Akun dikunci'));
          expect(f.message, contains('$lockMinutes menit'));
        },
        (_) => fail('Expected failure'),
      );
    });

    // -----------------------------------------------------------------------
    // P3.C — the 6th attempt is short-circuited by the local lock check.
    // -----------------------------------------------------------------------
    test('the ${maxFail + 1}th attempt is rejected by the local lock check',
        () async {
      final repo = _buildRepo();
      for (var i = 1; i <= maxFail; i++) {
        await _attempt(repo);
      }
      final sixth = await _attempt(repo);
      sixth.fold(
        (f) => expect(f, isA<AccountLockedFailure>()),
        (_) => fail('Expected failure'),
      );
    });

    // -----------------------------------------------------------------------
    // P3.D — every attempt from the 5th onwards yields AccountLockedFailure.
    // [maxFail, 20] inclusive.
    // -----------------------------------------------------------------------
    Glados(any.intInRange(maxFail, 21)).test(
      'attempts $maxFail..20 all return AccountLockedFailure',
      (m) async {
        final repo = _buildRepo();
        Either<Failure, UserEntity>? result;
        for (var i = 1; i <= m; i++) {
          result = await _attempt(repo);
        }
        expect(result!.isLeft(), isTrue);
        result.fold(
          (f) => expect(f, isA<AccountLockedFailure>(),
              reason: 'After $m failures the account must stay locked'),
          (_) => fail('Expected failure'),
        );
      },
    );

    // -----------------------------------------------------------------------
    // P3.E — failed-attempt counters are keyed per normalised email,
    // so locking one account leaves others untouched.
    // -----------------------------------------------------------------------
    Glados2<String, String>(_emailGen(), _emailGen()).test(
      'different emails have independent failed-attempt counters',
      (emailA, emailB) async {
        // Glados may generate collisions; skip when both normalise equal.
        if (_normalize(emailA) == _normalize(emailB)) return;

        final repo = _buildRepo();
        for (var i = 1; i < maxFail; i++) {
          await _attempt(repo, email: emailA);
        }
        final bResult = await _attempt(repo, email: emailB);
        bResult.fold(
          (f) {
            expect(f, isA<InvalidCredentialsFailure>(),
                reason: 'Email "$emailB" is still on attempt 1');
            expect(f, isNot(isA<AccountLockedFailure>()));
          },
          (_) => fail('Expected failure'),
        );
      },
    );

    // -----------------------------------------------------------------------
    // Fixed — case/whitespace normalisation shares a single counter.
    // -----------------------------------------------------------------------
    test('"Alice@Mail.com" and "  alice@mail.com  " share the lock counter',
        () async {
      final repo = _buildRepo();
      for (var i = 0; i < maxFail; i++) {
        await _attempt(repo, email: 'Alice@Mail.com');
      }
      final equivalent = await _attempt(repo, email: '  alice@mail.com  ');
      equivalent.fold(
        (f) => expect(f, isA<AccountLockedFailure>()),
        (_) => fail('Expected failure'),
      );
    });

    // -----------------------------------------------------------------------
    // Fixed — message-content sanity checks.
    // -----------------------------------------------------------------------
    test('InvalidCredentialsFailure.message does not mention "Akun dikunci"',
        () {
      expect(
        const InvalidCredentialsFailure().message.contains('Akun dikunci'),
        isFalse,
      );
    });
  });
}
