// Property tests for invalid payload rejection by TelemetryParser.
//
// Validates: Requirements 9.2
// Reference: .kiro/specs/coldshare-platform/requirements.md#Requirement 9
//
// Property 16: Validasi Payload Tidak Valid Selalu Ditolak
//   IF payload JSON yang diterima tidak memiliki field wajib (id_gudang,
//   timestamp, suhu, kelembapan), memiliki tipe data yang tidak sesuai,
//   atau nilai timestamp tidak dalam format ISO 8601, THEN THE
//   Telemetry_Service SHALL menolak data tersebut dan mengembalikan
//   respons HTTP 400 (Left with InvalidPayloadFailure) dengan pesan
//   kesalahan yang menyebutkan field mana yang tidak valid.

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
// `glados` re-exports `package:test/test.dart`, which collides with
// `flutter_test`. Hide the duplicates so the flutter_test versions win.
// ignore: depend_on_referenced_packages
import 'package:glados/glados.dart' hide test, group, expect;
import 'package:polarna/core/errors/failures.dart';
import 'package:polarna/features/telemetry/data/parsers/telemetry_parser.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Returns a complete valid payload map that TelemetryParser.parse accepts.
Map<String, dynamic> _validPayload() => {
      'id_gudang': 'warehouse-abc-123',
      'timestamp': '2024-06-15T10:30:00Z',
      'suhu': 5.0,
      'kelembapan': 65.0,
    };

/// Extracts the [InvalidPayloadFailure] from a Left result, or fails the test.
InvalidPayloadFailure _expectInvalid(Either<Failure, dynamic> result) {
  expect(result.isLeft(), isTrue,
      reason: 'Expected Left(InvalidPayloadFailure) but got Right');
  final failure = (result as Left).value;
  expect(failure, isA<InvalidPayloadFailure>());
  return failure as InvalidPayloadFailure;
}

// ---------------------------------------------------------------------------
// Generators
// ---------------------------------------------------------------------------

const _alphanumeric = 'abcdefghijklmnopqrstuvwxyz'
    'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    '0123456789';

List<String> _chars(String s) => s.split('');

/// Random alphanumeric string of length [minLen] to [maxLen].
Generator<String> _stringInRange(int minLen, int maxLen, String pool) {
  return any
      .listWithLengthInRange(minLen, maxLen + 1, any.choose(_chars(pool)))
      .map((list) => list.join());
}

/// Random non-empty alphanumeric string (5-20 chars) for "wrong type" slots.
final _randomStringGen = _stringInRange(5, 20, _alphanumeric);

/// Random positive integer for "wrong type" slots (number instead of string).
final _randomNumberGen = any.intInRange(1, 100000);

/// Random non-ISO-8601 string: alphanumeric garbage that DateTime.tryParse
/// will reject. We avoid accidentally generating valid ISO strings by using
/// only lowercase letters.
final _nonIsoTimestampGen = _stringInRange(5, 25, 'abcdefghijklmnopqrstuvwxyz');

/// Random whitespace-only or empty string for the "empty id_gudang" property.
final _emptyOrWhitespaceGen = any.choose([
  '',
  ' ',
  '  ',
  '   ',
  '\t',
  '\n',
  ' \t ',
]);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group(
    'Property 16: Validasi Payload Tidak Valid Selalu Ditolak '
    '(Validates: Requirements 9.2)',
    () {
      // ---------------------------------------------------------------------
      // 1. Missing id_gudang → Left with 'id_gudang' in invalidFields.
      // ---------------------------------------------------------------------
      Glados(_randomStringGen).test(
        '1. Missing id_gudang produces InvalidPayloadFailure naming id_gudang',
        (_) {
          final payload = _validPayload()..remove('id_gudang');
          final result = TelemetryParser.parse(payload);
          final failure = _expectInvalid(result);
          expect(failure.invalidFields, contains('id_gudang'));
        },
      );

      // ---------------------------------------------------------------------
      // 2. Missing timestamp → Left with 'timestamp'.
      // ---------------------------------------------------------------------
      Glados(_randomStringGen).test(
        '2. Missing timestamp produces InvalidPayloadFailure naming timestamp',
        (_) {
          final payload = _validPayload()..remove('timestamp');
          final result = TelemetryParser.parse(payload);
          final failure = _expectInvalid(result);
          expect(failure.invalidFields, contains('timestamp'));
        },
      );

      // ---------------------------------------------------------------------
      // 3. Missing suhu → Left with 'suhu'.
      // ---------------------------------------------------------------------
      Glados(_randomStringGen).test(
        '3. Missing suhu produces InvalidPayloadFailure naming suhu',
        (_) {
          final payload = _validPayload()..remove('suhu');
          final result = TelemetryParser.parse(payload);
          final failure = _expectInvalid(result);
          expect(failure.invalidFields, contains('suhu'));
        },
      );

      // ---------------------------------------------------------------------
      // 4. Missing kelembapan → Left with 'kelembapan'.
      // ---------------------------------------------------------------------
      Glados(_randomStringGen).test(
        '4. Missing kelembapan produces InvalidPayloadFailure naming kelembapan',
        (_) {
          final payload = _validPayload()..remove('kelembapan');
          final result = TelemetryParser.parse(payload);
          final failure = _expectInvalid(result);
          expect(failure.invalidFields, contains('kelembapan'));
        },
      );

      // ---------------------------------------------------------------------
      // 5. Wrong type for id_gudang (number instead of string) → Left with
      //    'id_gudang'.
      // ---------------------------------------------------------------------
      Glados(_randomNumberGen).test(
        '5. Wrong type for id_gudang (number) produces InvalidPayloadFailure',
        (randomNum) {
          final payload = _validPayload()..['id_gudang'] = randomNum;
          final result = TelemetryParser.parse(payload);
          final failure = _expectInvalid(result);
          expect(failure.invalidFields, contains('id_gudang'));
        },
      );

      // ---------------------------------------------------------------------
      // 6. Wrong type for suhu (string instead of number) → Left with 'suhu'.
      // ---------------------------------------------------------------------
      Glados(_randomStringGen).test(
        '6. Wrong type for suhu (string) produces InvalidPayloadFailure',
        (randomStr) {
          final payload = _validPayload()..['suhu'] = randomStr;
          final result = TelemetryParser.parse(payload);
          final failure = _expectInvalid(result);
          expect(failure.invalidFields, contains('suhu'));
        },
      );

      // ---------------------------------------------------------------------
      // 7. Non-ISO-8601 timestamp (random non-date string) → Left with
      //    'timestamp'.
      // ---------------------------------------------------------------------
      Glados(_nonIsoTimestampGen).test(
        '7. Non-ISO-8601 timestamp produces InvalidPayloadFailure naming timestamp',
        (garbage) {
          final payload = _validPayload()..['timestamp'] = garbage;
          final result = TelemetryParser.parse(payload);
          final failure = _expectInvalid(result);
          expect(failure.invalidFields, contains('timestamp'));
        },
      );

      // ---------------------------------------------------------------------
      // 8. Empty id_gudang (empty string or whitespace) → Left with
      //    'id_gudang'.
      // ---------------------------------------------------------------------
      Glados(_emptyOrWhitespaceGen).test(
        '8. Empty/whitespace id_gudang produces InvalidPayloadFailure',
        (emptyVal) {
          final payload = _validPayload()..['id_gudang'] = emptyVal;
          final result = TelemetryParser.parse(payload);
          final failure = _expectInvalid(result);
          expect(failure.invalidFields, contains('id_gudang'));
        },
      );

      // ---------------------------------------------------------------------
      // 9. All fields missing (empty map) → Left with all 4 fields listed.
      // ---------------------------------------------------------------------
      Glados(_randomStringGen).test(
        '9. Empty map produces InvalidPayloadFailure listing all 4 fields',
        (_) {
          final result = TelemetryParser.parse(<String, dynamic>{});
          final failure = _expectInvalid(result);
          expect(failure.invalidFields, contains('id_gudang'));
          expect(failure.invalidFields, contains('timestamp'));
          expect(failure.invalidFields, contains('suhu'));
          expect(failure.invalidFields, contains('kelembapan'));
          expect(failure.invalidFields.length, equals(4));
        },
      );

      // ---------------------------------------------------------------------
      // 10. Multiple fields wrong simultaneously → Left listing ALL invalid
      //     fields (single-pass collection per Req 9.2).
      //
      //     We generate a random subset of 2+ fields to invalidate.
      // ---------------------------------------------------------------------
      Glados(any.combine2(
        _randomNumberGen,
        _randomStringGen,
        (int num, String str) => {'num': num, 'str': str},
      )).test(
        '10. Multiple invalid fields are ALL reported in a single pass',
        (generated) {
          // Invalidate id_gudang (number) and suhu (string) simultaneously
          final payload = _validPayload()
            ..['id_gudang'] = generated['num']
            ..['suhu'] = generated['str'];
          final result = TelemetryParser.parse(payload);
          final failure = _expectInvalid(result);
          expect(failure.invalidFields, contains('id_gudang'),
              reason: 'id_gudang should be reported as invalid');
          expect(failure.invalidFields, contains('suhu'),
              reason: 'suhu should be reported as invalid');
        },
      );

      // ---------------------------------------------------------------------
      // 10b. Three fields invalid simultaneously — verifies single-pass
      //      collection reports all three.
      // ---------------------------------------------------------------------
      Glados(any.combine2(
        _randomNumberGen,
        _nonIsoTimestampGen,
        (int num, String garbage) => {'num': num, 'garbage': garbage},
      )).test(
        '10b. Three invalid fields are ALL reported in a single pass',
        (generated) {
          // Invalidate id_gudang (number), timestamp (garbage), kelembapan (string)
          final payload = _validPayload()
            ..['id_gudang'] = generated['num']
            ..['timestamp'] = generated['garbage']
            ..['kelembapan'] = 'not-a-number';
          final result = TelemetryParser.parse(payload);
          final failure = _expectInvalid(result);
          expect(failure.invalidFields, contains('id_gudang'));
          expect(failure.invalidFields, contains('timestamp'));
          expect(failure.invalidFields, contains('kelembapan'));
          expect(failure.invalidFields.length, greaterThanOrEqualTo(3));
        },
      );
    },
  );
}
