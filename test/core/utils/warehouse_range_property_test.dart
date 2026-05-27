// Property tests for warehouse capacity and price range validation.
//
// Validates: Requirements 2.3
// Reference: .kiro/specs/coldshare-platform/requirements.md#Requirement 2
//
// Property 5: Validasi Rentang Kapasitas dan Harga Gudang
//   - Capacity : [1, 999_999] m³
//   - Price    : [1_000, 999_999_999] Rp
//   - Error messages must be field-specific ("Kapasitas" vs "Harga").

import 'package:flutter_test/flutter_test.dart';
// `glados` re-exports `package:test/test.dart`, which collides with
// `flutter_test`. Hide the duplicates so the flutter_test versions win.
// ignore: depend_on_referenced_packages
import 'package:glados/glados.dart' hide test, group, expect;
import 'package:polarna/core/constants/app_constants.dart';
import 'package:polarna/core/utils/validators.dart';

/// Generates a `double` uniformly in `[min, max]` (both inclusive) with
/// millionth-step granularity — enough resolution for boundary exploration
/// without blowing up the shrinker.
Generator<double> _doubleInRange(double min, double max) {
  return any
      .intInRange(0, 1000001) // [0, 1_000_000] inclusive via exclusive upper
      .map((n) => min + (max - min) * (n / 1000000.0));
}

void main() {
  const capMin = AppConstants.minWarehouseCapacityM3; // 1.0
  const capMax = AppConstants.maxWarehouseCapacityM3; // 999_999.0
  const priceMin = AppConstants.minWarehousePriceRp; // 1_000.0
  const priceMax = AppConstants.maxWarehousePriceRp; // 999_999_999.0

  group('Property 5: Validasi Rentang Kapasitas dan Harga - Requirement 2.3',
      () {
    // -----------------------------------------------------------------------
    // Capacity [1, 999_999] m³
    // -----------------------------------------------------------------------
    group('Capacity [1, 999999]', () {
      Glados(_doubleInRange(capMin, capMax))
          .test('accepts values within range', (v) {
        expect(v, inInclusiveRange(capMin, capMax));
        expect(Validators.validateWarehouseCapacity(v).isValid, isTrue,
            reason: 'Expected valid capacity for $v');
      });

      // Below min: values strictly < 1.0, including 0 and negatives.
      // We sample from [-1000, ~0.999999].
      final belowMinGen = _doubleInRange(-1000.0, capMin)
          .map((v) => v >= capMin ? capMin - 1e-6 : v);

      Glados(belowMinGen).test('rejects values below min', (v) {
        expect(v, lessThan(capMin));
        final r = Validators.validateWarehouseCapacity(v);
        expect(r.isValid, isFalse);
        expect(r.errorMessage, contains('Kapasitas'));
      });

      // Above max: strictly > 999_999.0.
      final aboveMaxGen = _doubleInRange(capMax, capMax + 1e6)
          .map((v) => v <= capMax ? capMax + 1e-6 : v);

      Glados(aboveMaxGen).test('rejects values above max', (v) {
        expect(v, greaterThan(capMax));
        final r = Validators.validateWarehouseCapacity(v);
        expect(r.isValid, isFalse);
        expect(r.errorMessage, contains('Kapasitas'));
      });
    });

    // -----------------------------------------------------------------------
    // Price [1_000, 999_999_999] Rp
    // -----------------------------------------------------------------------
    group('Price [1000, 999999999]', () {
      Glados(_doubleInRange(priceMin, priceMax))
          .test('accepts values within range', (v) {
        expect(v, inInclusiveRange(priceMin, priceMax));
        expect(Validators.validateWarehousePrice(v).isValid, isTrue,
            reason: 'Expected valid price for $v');
      });

      // Below min: positive values in [0, 999.99] (strictly < 1000).
      final belowMinGen = _doubleInRange(0.0, priceMin)
          .map((v) => v >= priceMin ? priceMin - 1e-3 : v);

      Glados(belowMinGen).test('rejects values below min', (v) {
        expect(v, lessThan(priceMin));
        final r = Validators.validateWarehousePrice(v);
        expect(r.isValid, isFalse);
        expect(r.errorMessage, contains('Harga'));
      });

      // Above max: strictly > 999_999_999.0.
      final aboveMaxGen = _doubleInRange(priceMax, priceMax + 1e9)
          .map((v) => v <= priceMax ? priceMax + 1.0 : v);

      Glados(aboveMaxGen).test('rejects values above max', (v) {
        expect(v, greaterThan(priceMax));
        final r = Validators.validateWarehousePrice(v);
        expect(r.isValid, isFalse);
        expect(r.errorMessage, contains('Harga'));
      });
    });

    // -----------------------------------------------------------------------
    // Field-specific error messages (Requirement 2.3 explicitly demands
    // "pesan validasi yang spesifik untuk setiap field").
    // -----------------------------------------------------------------------
    group('Field-specific error messages', () {
      // Any invalid capacity (below, above, or null) → mentions only Kapasitas.
      final invalidCapacityGen = any.choose<double?>([
        -1.0, 0.0, 0.999999, capMax + 1e-6, capMax + 1.0, 1e9, null,
      ]);

      Glados(invalidCapacityGen).test(
        'capacity errors mention Kapasitas and not Harga',
        (v) {
          final r = Validators.validateWarehouseCapacity(v);
          expect(r.isValid, isFalse);
          expect(r.errorMessage, contains('Kapasitas'));
          expect(r.errorMessage, isNot(contains('Harga')));
        },
      );

      final invalidPriceGen = any.choose<double?>([
        -1.0, 0.0, 999.99, priceMin - 1e-3, priceMax + 1.0, 1e12, null,
      ]);

      Glados(invalidPriceGen).test(
        'price errors mention Harga and not Kapasitas',
        (v) {
          final r = Validators.validateWarehousePrice(v);
          expect(r.isValid, isFalse);
          expect(r.errorMessage, contains('Harga'));
          expect(r.errorMessage, isNot(contains('Kapasitas')));
        },
      );
    });

    // -----------------------------------------------------------------------
    // Boundaries and null (fixed tests).
    // -----------------------------------------------------------------------
    group('Boundaries and null', () {
      test('capacity accepts exact min and max, rejects just below min', () {
        expect(Validators.validateWarehouseCapacity(capMin).isValid, isTrue);
        expect(Validators.validateWarehouseCapacity(capMax).isValid, isTrue);
        expect(Validators.validateWarehouseCapacity(0.999999).isValid, isFalse);
      });

      test('price accepts exact min and max', () {
        expect(Validators.validateWarehousePrice(priceMin).isValid, isTrue);
        expect(Validators.validateWarehousePrice(priceMax).isValid, isTrue);
      });

      test('null is rejected for both capacity and price', () {
        expect(Validators.validateWarehouseCapacity(null).isValid, isFalse);
        expect(Validators.validateWarehousePrice(null).isValid, isFalse);
      });
    });
  });
}
