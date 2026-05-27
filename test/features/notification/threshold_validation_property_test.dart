// Property tests for temperature threshold validation (Validators).
//
// Validates: Requirements 7.6
// Reference: .kiro/specs/coldshare-platform/requirements.md#Requirement 7
//
// Property 13: Validasi Rentang dan Presisi Threshold Suhu
//   Validators.validateTemperatureThreshold() accepts values in [-40.0, +30.0]°C
//   with precision 0.1°C and rejects values outside range or with wrong precision.

import 'package:flutter_test/flutter_test.dart';
// `glados` re-exports `package:test/test.dart`, which collides with
// `flutter_test`. Hide the duplicates so the flutter_test versions win.
// ignore: depend_on_referenced_packages
import 'package:glados/glados.dart' hide test, group, expect;
import 'package:polarna/core/utils/validators.dart';

// ---------------------------------------------------------------------------
// Generators
// ---------------------------------------------------------------------------

/// Valid threshold: integer multiples of 0.1 in [-40.0, +30.0].
/// Maps integers in [-400, 300] to doubles via division by 10.
final _validThresholdGen =
    any.intInRange(-400, 301).map((i) => i / 10.0);

/// Below minimum (-40.0): values in [-100.0, -40.1].
/// Maps integers in [-1000, -401] to doubles via division by 10.
final _belowMinGen =
    any.intInRange(-1000, -401).map((i) => i / 10.0);

/// Above maximum (+30.0): values in [30.1, 100.0].
/// Maps integers in [301, 1000] to doubles via division by 10.
final _aboveMaxGen =
    any.intInRange(301, 1001).map((i) => i / 10.0);

/// Wrong precision: values with more than 1 decimal place within range.
/// Generates two components:
///   - base: integer in [-400, 300] → valid 0.1 multiple (base / 10.0)
///   - offset: integer in [1, 9] → fractional hundredths (offset / 100.0)
/// Result is always within [-40.0, +30.0] but has 0.01 precision (invalid).
final _wrongPrecisionGen = any.combine2(
  any.intInRange(-399, 299),
  any.intInRange(1, 10),
  (int base, int offset) => base / 10.0 + offset / 100.0,
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group(
    'Property 13: Validasi Rentang dan Presisi Threshold Suhu '
    '(Validates: Requirements 7.6)',
    () {
      // -------------------------------------------------------------------
      // 1. In-range with 0.1 precision accepted.
      // -------------------------------------------------------------------
      Glados(_validThresholdGen).test(
        'values in [-40.0, +30.0] with 0.1 precision are accepted',
        (threshold) {
          final result =
              Validators.validateTemperatureThreshold(threshold);

          expect(result.isValid, isTrue,
              reason: 'Expected valid for threshold=$threshold but got '
                  'error: "${result.errorMessage}"');
        },
      );

      // -------------------------------------------------------------------
      // 2. Below -40.0 rejected.
      // -------------------------------------------------------------------
      Glados(_belowMinGen).test(
        'values below -40.0 are rejected',
        (threshold) {
          final result =
              Validators.validateTemperatureThreshold(threshold);

          expect(result.isValid, isFalse,
              reason: 'Expected invalid for threshold=$threshold '
                  '(below minimum)');
        },
      );

      // -------------------------------------------------------------------
      // 3. Above +30.0 rejected.
      // -------------------------------------------------------------------
      Glados(_aboveMaxGen).test(
        'values above +30.0 are rejected',
        (threshold) {
          final result =
              Validators.validateTemperatureThreshold(threshold);

          expect(result.isValid, isFalse,
              reason: 'Expected invalid for threshold=$threshold '
                  '(above maximum)');
        },
      );

      // -------------------------------------------------------------------
      // 4. Wrong precision rejected (more than 1 decimal place).
      // -------------------------------------------------------------------
      Glados(_wrongPrecisionGen).test(
        'values with precision finer than 0.1 are rejected',
        (threshold) {
          final result =
              Validators.validateTemperatureThreshold(threshold);

          expect(result.isValid, isFalse,
              reason: 'Expected invalid for threshold=$threshold '
                  '(wrong precision)');
        },
      );

      // -------------------------------------------------------------------
      // 5. Boundary values: -40.0 and 30.0 accepted, -40.1 and 30.1 rejected.
      // -------------------------------------------------------------------
      test('boundary: -40.0 is accepted', () {
        final result = Validators.validateTemperatureThreshold(-40.0);
        expect(result.isValid, isTrue);
      });

      test('boundary: 30.0 is accepted', () {
        final result = Validators.validateTemperatureThreshold(30.0);
        expect(result.isValid, isTrue);
      });

      test('boundary: -40.1 is rejected', () {
        final result = Validators.validateTemperatureThreshold(-40.1);
        expect(result.isValid, isFalse);
      });

      test('boundary: 30.1 is rejected', () {
        final result = Validators.validateTemperatureThreshold(30.1);
        expect(result.isValid, isFalse);
      });

      // -------------------------------------------------------------------
      // 6. Null is rejected.
      // -------------------------------------------------------------------
      test('null is rejected', () {
        final result = Validators.validateTemperatureThreshold(null);
        expect(result.isValid, isFalse);
      });
    },
  );
}
