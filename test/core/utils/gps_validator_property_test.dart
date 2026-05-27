// Property tests for Indonesia GPS coordinate validation (Validators).
//
// Validates: Requirements 2.2
// Reference: .kiro/specs/coldshare-platform/requirements.md#Requirement 2
//
// Property 4: Validasi Koordinat GPS Wilayah Indonesia
//   Indonesia bounds (inclusive):
//     latitude  ∈ [-11°, 6°]
//     longitude ∈ [95°, 141°]

import 'package:flutter_test/flutter_test.dart';
// `glados` re-exports `package:test/test.dart`, which collides with
// `flutter_test`. Hide the duplicates so the flutter_test versions win.
// ignore: depend_on_referenced_packages
import 'package:glados/glados.dart' hide test, group, expect;
import 'package:polarna/core/constants/app_constants.dart';
import 'package:polarna/core/utils/validators.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Generates a `double` in the inclusive range `[min, max]` with 3 decimal
/// places of precision.
///
/// Implementation: scales the range to integers (x1000), uses
/// `any.intInRange(a, b + 1)` to get inclusive upper bound, then divides
/// back by 1000. This gives a finite, well-distributed grid over the target
/// interval which is sufficient for boundary-focused property testing.
Generator<double> _doubleInRange(double min, double max) {
  final minScaled = (min * 1000).round();
  final maxScaled = (max * 1000).round();
  // intInRange upper bound is EXCLUSIVE, so add 1 to make it inclusive.
  return any.intInRange(minScaled, maxScaled + 1).map((i) => i / 1000.0);
}

void main() {
  group('Property 4: Validasi Koordinat GPS Wilayah Indonesia - Requirement 2.2',
      () {
    // -----------------------------------------------------------------------
    // Valid coordinates — inside Indonesia bounds
    // -----------------------------------------------------------------------
    group('Valid Indonesia coordinates', () {
      final validLatGen = _doubleInRange(
        AppConstants.indonesiaMinLatitude, // -11.0
        AppConstants.indonesiaMaxLatitude, //  +6.0
      );
      final validLonGen = _doubleInRange(
        AppConstants.indonesiaMinLongitude, // +95.0
        AppConstants.indonesiaMaxLongitude, // +141.0
      );

      Glados(validLatGen).test(
        'accepts latitude within [-11, 6]',
        (lat) {
          expect(lat,
              inInclusiveRange(AppConstants.indonesiaMinLatitude,
                  AppConstants.indonesiaMaxLatitude));
          final result = Validators.validateLatitude(lat);
          expect(result.isValid, isTrue,
              reason: 'lat=$lat should be valid but got: '
                  '"${result.errorMessage}"');
        },
      );

      Glados(validLonGen).test(
        'accepts longitude within [95, 141]',
        (lon) {
          expect(lon,
              inInclusiveRange(AppConstants.indonesiaMinLongitude,
                  AppConstants.indonesiaMaxLongitude));
          final result = Validators.validateLongitude(lon);
          expect(result.isValid, isTrue,
              reason: 'lon=$lon should be valid but got: '
                  '"${result.errorMessage}"');
        },
      );

      Glados2(validLatGen, validLonGen).test(
        'accepts (lat, lon) pair within Indonesia bounds',
        (lat, lon) {
          expect(
            Validators.validateGpsCoordinates(lat, lon).isValid,
            isTrue,
            reason: '($lat, $lon) should be valid',
          );
        },
      );
    });

    // -----------------------------------------------------------------------
    // Out-of-range latitude
    // -----------------------------------------------------------------------
    group('Out-of-range latitude', () {
      // Strictly below -11°.
      final latBelowGen = _doubleInRange(-90.0, -12.0);
      // Strictly above +6°.
      final latAboveGen = _doubleInRange(7.0, 90.0);

      Glados(latBelowGen).test(
        'rejects latitude below -11 (and rejects full GPS even with valid lon)',
        (lat) {
          expect(lat, lessThan(AppConstants.indonesiaMinLatitude));
          expect(Validators.validateLatitude(lat).isValid, isFalse);
          // Valid longitude (100.0) — the pair must still be rejected.
          expect(
            Validators.validateGpsCoordinates(lat, 100.0).isValid,
            isFalse,
            reason: '($lat, 100.0) should be rejected because lat is out '
                'of range even though lon is valid',
          );
        },
      );

      Glados(latAboveGen).test(
        'rejects latitude above +6 (and rejects full GPS even with valid lon)',
        (lat) {
          expect(lat, greaterThan(AppConstants.indonesiaMaxLatitude));
          expect(Validators.validateLatitude(lat).isValid, isFalse);
          expect(
            Validators.validateGpsCoordinates(lat, 100.0).isValid,
            isFalse,
            reason: '($lat, 100.0) should be rejected because lat is out '
                'of range even though lon is valid',
          );
        },
      );
    });

    // -----------------------------------------------------------------------
    // Out-of-range longitude
    // -----------------------------------------------------------------------
    group('Out-of-range longitude', () {
      // Strictly below +95°.
      final lonBelowGen = _doubleInRange(-180.0, 94.0);
      // Strictly above +141°.
      final lonAboveGen = _doubleInRange(142.0, 180.0);

      Glados(lonBelowGen).test(
        'rejects longitude below 95 (and rejects full GPS even with valid lat)',
        (lon) {
          expect(lon, lessThan(AppConstants.indonesiaMinLongitude));
          expect(Validators.validateLongitude(lon).isValid, isFalse);
          // Valid latitude (0.0) — the pair must still be rejected.
          expect(
            Validators.validateGpsCoordinates(0.0, lon).isValid,
            isFalse,
            reason: '(0.0, $lon) should be rejected because lon is out '
                'of range even though lat is valid',
          );
        },
      );

      Glados(lonAboveGen).test(
        'rejects longitude above 141 (and rejects full GPS even with valid lat)',
        (lon) {
          expect(lon, greaterThan(AppConstants.indonesiaMaxLongitude));
          expect(Validators.validateLongitude(lon).isValid, isFalse);
          expect(
            Validators.validateGpsCoordinates(0.0, lon).isValid,
            isFalse,
            reason: '(0.0, $lon) should be rejected because lon is out '
                'of range even though lat is valid',
          );
        },
      );
    });

    // -----------------------------------------------------------------------
    // Combined: BOTH latitude and longitude out of range
    // -----------------------------------------------------------------------
    group('Combined out-of-range (both lat and lon)', () {
      Glados2(
        _doubleInRange(7.0, 90.0), // lat above +6
        _doubleInRange(142.0, 180.0), // lon above +141
      ).test(
        'rejects when both lat and lon are out of range',
        (lat, lon) {
          expect(lat, greaterThan(AppConstants.indonesiaMaxLatitude));
          expect(lon, greaterThan(AppConstants.indonesiaMaxLongitude));
          expect(Validators.validateLatitude(lat).isValid, isFalse);
          expect(Validators.validateLongitude(lon).isValid, isFalse);
          expect(Validators.validateGpsCoordinates(lat, lon).isValid, isFalse);
        },
      );

      Glados2(
        _doubleInRange(-90.0, -12.0), // lat below -11
        _doubleInRange(-180.0, 94.0), // lon below +95
      ).test(
        'rejects when both lat and lon are out of range (opposite side)',
        (lat, lon) {
          expect(lat, lessThan(AppConstants.indonesiaMinLatitude));
          expect(lon, lessThan(AppConstants.indonesiaMinLongitude));
          expect(Validators.validateLatitude(lat).isValid, isFalse);
          expect(Validators.validateLongitude(lon).isValid, isFalse);
          expect(Validators.validateGpsCoordinates(lat, lon).isValid, isFalse);
        },
      );
    });

    // -----------------------------------------------------------------------
    // Boundary values (fixed)
    // -----------------------------------------------------------------------
    group('Boundary values (fixed)', () {
      test('accepts exact boundary latitudes (-11.0 and 6.0)', () {
        expect(Validators.validateLatitude(-11.0).isValid, isTrue);
        expect(Validators.validateLatitude(6.0).isValid, isTrue);
      });

      test('accepts exact boundary longitudes (95.0 and 141.0)', () {
        expect(Validators.validateLongitude(95.0).isValid, isTrue);
        expect(Validators.validateLongitude(141.0).isValid, isTrue);
      });

      test('rejects latitudes just outside the boundary (-11.01 and 6.01)',
          () {
        expect(Validators.validateLatitude(-11.01).isValid, isFalse);
        expect(Validators.validateLatitude(6.01).isValid, isFalse);
      });

      test('rejects longitudes just outside the boundary (94.99 and 141.01)',
          () {
        expect(Validators.validateLongitude(94.99).isValid, isFalse);
        expect(Validators.validateLongitude(141.01).isValid, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // Null handling (fixed)
    // -----------------------------------------------------------------------
    group('Null handling (fixed)', () {
      test('rejects null latitude', () {
        final result = Validators.validateLatitude(null);
        expect(result.isValid, isFalse);
        expect(result.errorMessage, isNotNull);
      });

      test('rejects null longitude', () {
        final result = Validators.validateLongitude(null);
        expect(result.isValid, isFalse);
        expect(result.errorMessage, isNotNull);
      });

      test('rejects pair when latitude is null', () {
        expect(
            Validators.validateGpsCoordinates(null, 100.0).isValid, isFalse);
      });

      test('rejects pair when longitude is null', () {
        expect(Validators.validateGpsCoordinates(0.0, null).isValid, isFalse);
      });
    });
  });
}
