// Property tests for the booking cost calculation use case.
//
// Validates: Requirements 4.2
// Reference: .kiro/specs/coldshare-platform/requirements.md#Requirement 4
//
// Property 7: Kebenaran Kalkulasi Biaya Pemesanan
//   For every combination of volume (v, multiple of 0.5, range [0.5, 500]),
//   price per m³/day (p, range [1000, 999999999]), and duration (d, range
//   [1, 365] days), CalculateCostUseCase SHALL produce total = v × p × d
//   with NO undocumented rounding.

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
// `glados` re-exports `package:test/test.dart`, which collides with
// `flutter_test`. Hide the duplicates so the flutter_test versions win.
// ignore: depend_on_referenced_packages
import 'package:glados/glados.dart' hide test, group, expect;
import 'package:polarna/features/booking/domain/usecases/calculate_cost_usecase.dart';

// ---------------------------------------------------------------------------
// Helpers.
// ---------------------------------------------------------------------------

/// Uniform `double` in `[min, max]` (both inclusive) with millionth-step
/// granularity — plenty of resolution for boundary exploration.
Generator<double> _doubleInRange(double min, double max) {
  return any
      .intInRange(0, 1000001) // [0, 1_000_000] inclusive
      .map((n) => min + (max - min) * (n / 1000000.0));
}

/// Generates a valid volume: multiple of 0.5 in [0.5, 500].
/// There are 1000 possible values: 0.5, 1.0, 1.5, ..., 500.0.
Generator<double> _validVolumeGen() {
  // Pick an integer in [1, 1000] and multiply by 0.5.
  return any.intInRange(1, 1001).map((n) => n * 0.5);
}

/// Generates a valid price per m³/day in [1000, 999999999].
Generator<double> _validPriceGen() {
  return _doubleInRange(1000.0, 999999999.0);
}

/// Generates a valid duration in [1, 365] days.
Generator<int> _validDurationGen() {
  return any.intInRange(1, 366); // [1, 365] inclusive
}

void main() {
  const useCase = CalculateCostUseCase();

  group('Property 7: Kebenaran Kalkulasi Biaya Pemesanan - Requirement 4.2',
      () {
    // -----------------------------------------------------------------------
    // 1. Valid inputs produce exact v×p×d
    // -----------------------------------------------------------------------
    group('Valid inputs produce exact v×p×d', () {
      final validInputGen = any.combine3(
        _validVolumeGen(),
        _validPriceGen(),
        _validDurationGen(),
        (double v, double p, int d) => (v, p, d),
      );

      Glados(validInputGen).test(
        'result.isRight() and result == Right(v * p * d)',
        (input) {
          final (v, p, d) = input;
          final result = useCase(CalculateCostParams(
            volumeM3: v,
            pricePerM3PerDay: p,
            durationDays: d,
          ));
          expect(result.isRight(), isTrue,
              reason: 'Expected Right for v=$v, p=$p, d=$d');
          final expected = v * p * d;
          result.fold(
            (_) => fail('Expected Right but got Left'),
            (total) => expect(total, equals(expected),
                reason:
                    'Expected $expected but got $total for v=$v, p=$p, d=$d'),
          );
        },
      );
    });

    // -----------------------------------------------------------------------
    // 2. Volume ≤ 0 rejected
    // -----------------------------------------------------------------------
    group('Volume ≤ 0 rejected', () {
      final invalidVolumeGen = _doubleInRange(-1000.0, 0.0);

      Glados(invalidVolumeGen).test(
        'result.isLeft() when volume <= 0',
        (v) {
          final result = useCase(CalculateCostParams(
            volumeM3: v,
            pricePerM3PerDay: 5000.0,
            durationDays: 30,
          ));
          expect(result.isLeft(), isTrue,
              reason: 'Expected Left for volume=$v');
        },
      );
    });

    // -----------------------------------------------------------------------
    // 3. Duration ≤ 0 rejected
    // -----------------------------------------------------------------------
    group('Duration ≤ 0 rejected', () {
      final invalidDurationGen = any.intInRange(-365, 1); // [-365, 0]

      Glados(invalidDurationGen).test(
        'result.isLeft() when duration <= 0',
        (d) {
          final result = useCase(CalculateCostParams(
            volumeM3: 10.0,
            pricePerM3PerDay: 5000.0,
            durationDays: d,
          ));
          expect(result.isLeft(), isTrue,
              reason: 'Expected Left for duration=$d');
        },
      );
    });

    // -----------------------------------------------------------------------
    // 4. Commutativity: v×p×d == p×v×d
    // -----------------------------------------------------------------------
    group('Commutativity (no hidden rounding)', () {
      final commInputGen = any.combine3(
        _validVolumeGen(),
        _validPriceGen(),
        _validDurationGen(),
        (double v, double p, int d) => (v, p, d),
      );

      Glados(commInputGen).test(
        'v×p×d == p×v×d (Dart double multiplication is commutative)',
        (input) {
          final (v, p, d) = input;
          final result = useCase(CalculateCostParams(
            volumeM3: v,
            pricePerM3PerDay: p,
            durationDays: d,
          ));
          result.fold(
            (_) => fail('Expected Right but got Left'),
            (total) {
              // Verify commutativity: the use case result matches both
              // orderings of the multiplication.
              expect(total, equals(v * p * d));
              expect(total, equals(p * v * d));
            },
          );
        },
      );
    });

    // -----------------------------------------------------------------------
    // 5. Boundary cases
    // -----------------------------------------------------------------------
    group('Boundary cases', () {
      test('v=0.5, p=1000, d=1 → 500.0', () {
        final result = useCase(const CalculateCostParams(
          volumeM3: 0.5,
          pricePerM3PerDay: 1000.0,
          durationDays: 1,
        ));
        expect(result.isRight(), isTrue);
        result.fold(
          (_) => fail('Expected Right'),
          (total) => expect(total, equals(500.0)),
        );
      });

      test('v=500, p=999999999, d=365 → exact product', () {
        final result = useCase(const CalculateCostParams(
          volumeM3: 500.0,
          pricePerM3PerDay: 999999999.0,
          durationDays: 365,
        ));
        expect(result.isRight(), isTrue);
        final expected = 500.0 * 999999999.0 * 365;
        result.fold(
          (_) => fail('Expected Right'),
          (total) => expect(total, equals(expected)),
        );
      });
    });
  });
}
