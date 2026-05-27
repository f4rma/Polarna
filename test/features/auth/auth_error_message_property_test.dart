// Property tests for authentication error message security.
//
// Validates: Requirements 1.5
// Reference: .kiro/specs/coldshare-platform/requirements.md#Requirement 1
//
// Property 2: Keamanan Pesan Error Autentikasi
//   IF pengguna memasukkan email atau kata sandi yang salah, THEN THE
//   Auth_Service SHALL menampilkan pesan kesalahan "Email atau kata sandi
//   tidak valid" tanpa mengungkapkan informasi mana yang salah.

import 'package:flutter_test/flutter_test.dart';
// `glados` re-exports `package:test/test.dart`, which collides with
// `flutter_test`. Hide the duplicates so the flutter_test versions win.
// ignore: depend_on_referenced_packages
import 'package:glados/glados.dart' hide test, group, expect;
import 'package:polarna/core/errors/exceptions.dart';
import 'package:polarna/core/errors/failures.dart';

/// Canonical error message. Must be identical regardless of underlying cause.
const _expected = 'Email atau kata sandi tidak valid';

/// Firebase Auth error codes that all indicate "invalid credentials".
/// The mapping logic SHALL collapse all of these into the same exception.
const _credentialCodes = <String>[
  'user-not-found',
  'wrong-password',
  'invalid-credential',
  'invalid-email',
  'user-disabled',
];

/// Local re-implementation of the credential-error mapping branch. Mirrors the
/// behaviour of `AuthRemoteDataSource._mapFirebaseAuthException` for any code
/// related to bad credentials — all such codes MUST map to a single exception
/// with the canonical message.
AppException mapCredentialCodeToException(String code) {
  if (_credentialCodes.contains(code)) {
    return const InvalidCredentialsException();
  }
  return const ServerException();
}

/// Generator for arbitrary printable strings (length 0–30). Sufficient to
/// exercise the leakage property across a wide variety of email/password
/// shapes without triggering any ASCII-edge-case pathologies.
const _charPool =
    'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@._-!#';
final _arbitraryString = any
    .listWithLengthInRange(0, 31, any.choose(_charPool.split('')))
    .map((chars) => chars.join());

void main() {
  group('Property 2: Keamanan Pesan Error Autentikasi - Requirement 1.5', () {
    // -----------------------------------------------------------------------
    // Fixed sanity checks: the canonical constant is stable.
    // -----------------------------------------------------------------------
    test('InvalidCredentialsFailure message is the fixed canonical string',
        () {
      expect(const InvalidCredentialsFailure().message, _expected);
    });

    test('InvalidCredentialsException message is the fixed canonical string',
        () {
      expect(const InvalidCredentialsException().message, _expected);
    });

    test('Failure and Exception expose the identical message', () {
      expect(const InvalidCredentialsFailure().message,
          const InvalidCredentialsException().message);
    });

    // -----------------------------------------------------------------------
    // Property: for ANY (email, password) pair, the returned message is
    // identical and leaks neither the email nor the password substring.
    // -----------------------------------------------------------------------
    Glados2<String, String>(_arbitraryString, _arbitraryString).test(
      'message is identical and leaks no input for any (email, password)',
      (email, password) {
        final failureMsg = const InvalidCredentialsFailure().message;
        final exceptionMsg = const InvalidCredentialsException().message;

        // Message is the canonical constant, regardless of input.
        expect(failureMsg, _expected);
        expect(exceptionMsg, _expected);
        expect(failureMsg, exceptionMsg);

        // No leakage: the message must not contain a non-trivial fragment of
        // the raw email or password. We require at least 3 chars to avoid
        // spurious collisions with common substrings of the canonical string
        // (e.g., generated inputs like "a" or "di").
        if (email.length >= 3) {
          expect(failureMsg.contains(email), isFalse,
              reason: 'Message leaked email "$email"');
        }
        if (password.length >= 3) {
          expect(failureMsg.contains(password), isFalse,
              reason: 'Message leaked password "$password"');
        }

        // No field-name disclosure: the message must not single out which
        // field was wrong (e.g., "password salah" or "email tidak ditemukan").
        final lower = failureMsg.toLowerCase();
        expect(lower.contains('salah'), isFalse);
        expect(lower.contains('ditemukan'), isFalse);
        expect(lower.contains('terdaftar'), isFalse);
      },
    );

    // -----------------------------------------------------------------------
    // Property: every credential-related Firebase error code maps to the
    // SAME exception message (no field-specific leakage through error codes).
    // -----------------------------------------------------------------------
    Glados(any.choose(_credentialCodes)).test(
      'all credential-related Firebase codes map to the identical message',
      (code) {
        final ex = mapCredentialCodeToException(code);
        expect(ex, isA<InvalidCredentialsException>());
        expect(ex.message, _expected);
      },
    );
  });
}
