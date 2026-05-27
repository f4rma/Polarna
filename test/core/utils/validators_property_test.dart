// Property tests for input registration format validation (Validators).
//
// Validates: Requirements 1.1
// Reference: .kiro/specs/coldshare-platform/requirements.md#Requirement 1
//
// Property 1: Validasi Format Input Pendaftaran
//   - Email: RFC 5321, max 254 chars
//   - Password: 8–64 chars, ≥1 uppercase, ≥1 digit
//   - Full Name: not empty (after trim), max 100 chars
//   - Phone: E.164 (`^\+[1-9]\d{1,14}$`), max 15 digits

import 'package:flutter_test/flutter_test.dart';
// `glados` re-exports `package:test/test.dart`, which collides with
// `flutter_test`. Hide the duplicates so the flutter_test versions win.
// ignore: depend_on_referenced_packages
import 'package:glados/glados.dart' hide test, group, expect;
import 'package:polarna/core/constants/app_constants.dart';
import 'package:polarna/core/utils/validators.dart';

// ---------------------------------------------------------------------------
// Shared character pools (kept as constants, reused by generators).
// ---------------------------------------------------------------------------
const _lowercase = 'abcdefghijklmnopqrstuvwxyz';
const _uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const _digits = '0123456789';
const _letters = '$_lowercase$_uppercase';
const _lettersDigits = '$_letters$_digits';

List<String> _chars(String s) => s.split('');

/// Generates a string of length in `[minLen, maxLen]` (both inclusive) built
/// from the given character pool.
Generator<String> _stringInRange(int minLen, int maxLen, String pool) {
  // `listWithLengthInRange(min, max, ...)` treats `max` as EXCLUSIVE upper
  // bound, so we pass `maxLen + 1` to make it inclusive.
  return any
      .listWithLengthInRange(minLen, maxLen + 1, any.choose(_chars(pool)))
      .map((list) => list.join());
}

void main() {
  group('Property 1: Validasi Format Input Pendaftaran - Requirement 1.1', () {
    // -----------------------------------------------------------------------
    // Email — RFC 5321, max 254 characters
    // -----------------------------------------------------------------------
    group('Email (RFC 5321, max 254 chars)', () {
      // Valid email generator: local@domain.tld
      //   local  : 1–10 letters/digits
      //   domain : 1–10 letters
      //   tld    : 2–4  letters
      // Max total length: 10 + 1 + 10 + 1 + 4 = 26 chars (well under 254).
      final validEmailGen = any.combine3(
        _stringInRange(1, 10, _lettersDigits),
        _stringInRange(1, 10, _letters),
        _stringInRange(2, 4, _letters),
        (String local, String domain, String tld) => '$local@$domain.$tld',
      );

      Glados(validEmailGen).test('accepts well-formed emails', (email) {
        final result = Validators.validateEmail(email);
        expect(result.isValid, isTrue,
            reason: 'Expected valid email but got error: '
                '"${result.errorMessage}" for input "$email"');
        expect(email.length, lessThanOrEqualTo(AppConstants.maxEmailLength));
      });

      // Oversized generator: produces well-formed emails whose total length
      // exceeds 254 chars (local part padded with 'a').
      final oversizedEmailGen = any
          .intInRange(250, 400) // local length in [250, 399]
          .map((n) => '${'a' * n}@b.co'); // total length = n + 5 ≥ 255

      Glados(oversizedEmailGen).test('rejects emails longer than 254 chars',
          (email) {
        expect(email.length, greaterThan(AppConstants.maxEmailLength));
        expect(Validators.validateEmail(email).isValid, isFalse);
      });

      // Fixed sanity checks for null / empty / whitespace.
      test('rejects null, empty and whitespace-only email', () {
        expect(Validators.validateEmail(null).isValid, isFalse);
        expect(Validators.validateEmail('').isValid, isFalse);
        expect(Validators.validateEmail('   ').isValid, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // Password — 8–64 chars, ≥1 uppercase, ≥1 digit
    // -----------------------------------------------------------------------
    group('Password (8-64 chars, 1 uppercase, 1 digit)', () {
      // Valid password generator: 'A1' + filler (lowercase letters, 6–62 chars)
      // → total length 8–64, contains uppercase 'A' and digit '1'.
      final validPasswordGen =
          _stringInRange(6, 62, _lowercase).map((filler) => 'A1$filler');

      Glados(validPasswordGen).test(
        'accepts 8-64 char passwords with uppercase and digit',
        (password) {
          expect(password.length,
              inInclusiveRange(AppConstants.minPasswordLength,
                  AppConstants.maxPasswordLength));
          expect(Validators.validatePassword(password).isValid, isTrue);
        },
      );

      // Too-short (1–7 chars of letters/digits, always contains at least one
      // char so the empty-check is not triggered).
      final tooShortPasswordGen = _stringInRange(1, 7, _lettersDigits);

      Glados(tooShortPasswordGen).test('rejects passwords shorter than 8 chars',
          (password) {
        expect(password.length, lessThan(AppConstants.minPasswordLength));
        expect(Validators.validatePassword(password).isValid, isFalse);
      });

      // Too-long (65–150 chars) — content mixed so it *would* pass all other
      // checks; only the length check should trip.
      final tooLongPasswordGen = any
          .intInRange(AppConstants.maxPasswordLength + 1, 150)
          .map((n) => 'A1${'a' * (n - 2)}');

      Glados(tooLongPasswordGen).test('rejects passwords longer than 64 chars',
          (password) {
        expect(password.length, greaterThan(AppConstants.maxPasswordLength));
        expect(Validators.validatePassword(password).isValid, isFalse);
      });

      // 8–64 chars but missing uppercase (only lowercase + digits).
      final missingUppercaseGen =
          _stringInRange(8, 64, '$_lowercase$_digits');

      Glados(missingUppercaseGen).test(
        'rejects 8-64 char passwords without an uppercase letter',
        (password) {
          expect(password.contains(RegExp(r'[A-Z]')), isFalse);
          expect(Validators.validatePassword(password).isValid, isFalse);
        },
      );

      // 8–64 chars but missing digit (only letters).
      final missingDigitGen = _stringInRange(8, 64, _letters);

      Glados(missingDigitGen).test(
        'rejects 8-64 char passwords without a digit',
        (password) {
          // Ensure at least one uppercase so the failure is due to the missing
          // digit (otherwise the uppercase check would fire first).
          final forced = 'A$password'.substring(0, password.length);
          expect(forced.contains(RegExp(r'[0-9]')), isFalse);
          expect(Validators.validatePassword(forced).isValid, isFalse);
        },
      );

      test('rejects null and empty password', () {
        expect(Validators.validatePassword(null).isValid, isFalse);
        expect(Validators.validatePassword('').isValid, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // Full Name — not empty after trim, max 100 chars
    // -----------------------------------------------------------------------
    group('Full Name (not empty, max 100 chars)', () {
      // Valid full name: 1–100 letters (no leading/trailing spaces).
      final validNameGen = _stringInRange(1, 100, _letters);

      Glados(validNameGen).test('accepts non-empty names of length 1-100',
          (name) {
        expect(name.trim().length,
            inInclusiveRange(1, AppConstants.maxFullNameLength));
        expect(Validators.validateFullName(name).isValid, isTrue);
      });

      // Oversized name: 101–200 letters.
      final oversizedNameGen = _stringInRange(101, 200, _letters);

      Glados(oversizedNameGen).test('rejects names longer than 100 chars',
          (name) {
        expect(
            name.trim().length, greaterThan(AppConstants.maxFullNameLength));
        expect(Validators.validateFullName(name).isValid, isFalse);
      });

      test('rejects null, empty, and whitespace-only name', () {
        expect(Validators.validateFullName(null).isValid, isFalse);
        expect(Validators.validateFullName('').isValid, isFalse);
        expect(Validators.validateFullName('   ').isValid, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // Phone — E.164 (`^\+[1-9]\d{1,14}$`), max 15 digits
    // -----------------------------------------------------------------------
    group('Phone (E.164, max 15 digits)', () {
      // Valid phone: '+' + leading digit (1–9) + 1–14 more digits
      // → total 2–15 digits after '+'.
      final validPhoneGen = any.combine2(
        any.intInRange(1, 10), // leading digit [1, 9]
        _stringInRange(1, 14, _digits), // 1–14 trailing digits
        (int lead, String trail) => '+$lead$trail',
      );

      Glados(validPhoneGen).test('accepts well-formed E.164 numbers', (phone) {
        final digitsOnly = phone.substring(1);
        expect(digitsOnly.length,
            inInclusiveRange(2, AppConstants.maxPhoneDigits));
        expect(Validators.validatePhone(phone).isValid, isTrue,
            reason: 'Expected valid phone for "$phone"');
      });

      // No leading '+' — just digits.
      final missingPlusGen = _stringInRange(2, 15, _digits);

      Glados(missingPlusGen).test('rejects phones without a leading plus',
          (phone) {
        expect(phone.startsWith('+'), isFalse);
        expect(Validators.validatePhone(phone).isValid, isFalse);
      });

      // Leading digit '0' after '+' is disallowed by E.164.
      final leadingZeroGen =
          _stringInRange(1, 14, _digits).map((rest) => '+0$rest');

      Glados(leadingZeroGen).test(
        'rejects phones whose first digit after + is 0',
        (phone) {
          expect(phone.startsWith('+0'), isTrue);
          expect(Validators.validatePhone(phone).isValid, isFalse);
        },
      );

      // Non-digit characters after the '+'.
      final nonDigitGen = any.combine2(
        any.intInRange(1, 10), // valid leading digit
        _stringInRange(1, 10, _letters), // at least one letter → non-digit
        (int lead, String letters) => '+$lead$letters',
      );

      Glados(nonDigitGen).test(
        'rejects phones containing non-digit characters',
        (phone) {
          expect(Validators.validatePhone(phone).isValid, isFalse);
        },
      );

      test('rejects null, empty, and whitespace-only phone', () {
        expect(Validators.validatePhone(null).isValid, isFalse);
        expect(Validators.validatePhone('').isValid, isFalse);
        expect(Validators.validatePhone('   ').isValid, isFalse);
      });
    });
  });
}
