// Property tests for BreachDetector temperature violation detection.
//
// Validates: Requirements 7.2
// Reference: .kiro/specs/coldshare-platform/requirements.md#Requirement 7
//
// Property 12: Deteksi Pelanggaran Suhu
//   For every pair (currentTemp, threshold), BreachDetector.detect() returns
//   BreachStatus.violation iff currentTemp > threshold, and
//   BreachStatus.normal iff currentTemp <= threshold.

import 'package:flutter_test/flutter_test.dart';
// `glados` re-exports `package:test/test.dart`, which collides with
// `flutter_test`. Hide the duplicates so the flutter_test versions win.
// ignore: depend_on_referenced_packages
import 'package:glados/glados.dart' hide test, group, expect;
import 'package:polarna/features/notification/domain/services/breach_detector.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Generates a double in the range [min, max] with millidegree precision.
/// Uses integer millidegrees mapped to double for uniform coverage.
Generator<double> _doubleInRange(double min, double max) {
  final minInt = (min * 1000).round();
  final maxInt = (max * 1000).round();
  return any.intInRange(minInt, maxInt + 1).map((i) => i / 1000.0);
}

// ---------------------------------------------------------------------------
// Generators
// ---------------------------------------------------------------------------

/// Temperature range covering realistic cold-chain values: -50.0 to 100.0°C.
final _tempGen = _doubleInRange(-50.0, 100.0);

/// Threshold range covering warehouse thresholds: -50.0 to 100.0°C.
final _thresholdGen = _doubleInRange(-50.0, 100.0);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group(
    'Property 12: Deteksi Pelanggaran Suhu '
    '(Validates: Requirements 7.2)',
    () {
      // -------------------------------------------------------------------
      // 1. Violation: temp > threshold → BreachStatus.violation
      // -------------------------------------------------------------------
      Glados(any.combine2(
        _thresholdGen,
        _doubleInRange(0.001, 50.0), // positive delta to ensure temp > threshold
        (double threshold, double delta) =>
            (threshold: threshold, temp: threshold + delta),
      )).test(
        'returns violation when currentTemp > threshold',
        (pair) {
          final result = BreachDetector.detect(
            currentTemp: pair.temp,
            threshold: pair.threshold,
          );

          expect(result, equals(BreachStatus.violation),
              reason: 'Expected violation for temp=${pair.temp}, '
                  'threshold=${pair.threshold}');
        },
      );

      // -------------------------------------------------------------------
      // 2. Normal: temp < threshold → BreachStatus.normal
      // -------------------------------------------------------------------
      Glados(any.combine2(
        _thresholdGen,
        _doubleInRange(0.001, 50.0), // positive delta to ensure temp < threshold
        (double threshold, double delta) =>
            (threshold: threshold, temp: threshold - delta),
      )).test(
        'returns normal when currentTemp < threshold',
        (pair) {
          final result = BreachDetector.detect(
            currentTemp: pair.temp,
            threshold: pair.threshold,
          );

          expect(result, equals(BreachStatus.normal),
              reason: 'Expected normal for temp=${pair.temp}, '
                  'threshold=${pair.threshold}');
        },
      );

      // -------------------------------------------------------------------
      // 3. Boundary: temp == threshold → BreachStatus.normal (≤ means equal
      //    is normal)
      // -------------------------------------------------------------------
      Glados(_thresholdGen).test(
        'returns normal when currentTemp == threshold (boundary)',
        (threshold) {
          final result = BreachDetector.detect(
            currentTemp: threshold,
            threshold: threshold,
          );

          expect(result, equals(BreachStatus.normal),
              reason: 'Expected normal for temp==threshold=$threshold');
        },
      );

      // -------------------------------------------------------------------
      // 4. Extreme values: specific edge cases
      // -------------------------------------------------------------------
      test('extreme: temp = -50, threshold = -50 → normal', () {
        final result = BreachDetector.detect(
          currentTemp: -50.0,
          threshold: -50.0,
        );
        expect(result, equals(BreachStatus.normal));
      });

      test('extreme: temp = 100, threshold = 99.9 → violation', () {
        final result = BreachDetector.detect(
          currentTemp: 100.0,
          threshold: 99.9,
        );
        expect(result, equals(BreachStatus.violation));
      });
    },
  );
}
