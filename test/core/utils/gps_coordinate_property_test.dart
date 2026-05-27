// Property tests for Indonesia GPS coordinate validation (Validators).
//
// Validates: Requirements 2.2
// Reference: .kiro/specs/coldshare-platform/requirements.md#Requirement 2
//
// Property 4: Validasi Koordinat GPS Wilayah Indonesia
//   - Latitude  ∈ [-11.0, 6.0]   (lintang)
//   - Longitude ∈ [95.0, 141.0]  (bujur)

import 'package:flutter_test/flutter_test.dart';
// `glados` re-exports `package:test/test.dart`, which collides with
// `flutter_test`. Hide the duplicates so the flutter_test versions win.
// ignore: depend_on_referenced_packages
import 'package:glados/glados.dart' hide test, group, expect;
import 'package:polarna/core/constants/app_constants.dart';
import 'package:polarna/core/utils/validators.dart';

// ---------------------------------------------------------------------------
// Shared generator: uniform double in `[min, max]` (both inclusive).
// Uses 1_000_001 integer buckets to give enough resolution for boundary
// coverage while staying deterministic and shrinkable.
// ---------------------------------------------------------------------------
Generator<double> _doubleInRange(double min, double max) => any
    .intInRange(0, 1000001)
    .map((n) => min + (max - min) * n / 1000000);

// Convenience handles for the Indonesia bounds.
const _latMin = AppConstants.indonesiaMinLatitude; // -11.0
const _latMax = AppConstants.indonesiaMaxLatitude; //   6.0
const _lonMin = AppConstants.indonesiaMinLongitude; //  95.0
const _lonMax = AppConstants.indonesiaMaxLongitude; // 141.0

void main() {
  group('Property 4: Validasi Koordinat GPS Indonesia - Requirement 2.2', () {
    // -----------------------------------------------------------------------
    // Latitude ∈ [-11.0, 6.0]
    // -----------------------------------------------------------------------
    group('Latitude [-11, 6]', () {
      Glados(_doubleInRange(_latMin, _latMax))
          .test('accepts latitudes inside Indonesia bounds', (lat) {
        expect(lat, inInclusiveRange(_latMin, _latMax));
        expect(Validators.validateLatitude(lat).isValid, isTrue,
            reason: 'Expected valid latitude for $lat');
      });

      Glados(_doubleInRange(-90.0, -11.0001))
          .test('rejects latitudes below -11.0', (lat) {
        expect(lat, lessThan(_latMin));
        expect(Validators.validateLatitude(lat).isValid, isFalse);
      });

      Glados(_doubleInRange(6.0001, 90.0))
          .test('rejects latitudes above 6.0', (lat) {
        expect(lat, greaterThan(_latMax));
        expect(Validators.validateLatitude(lat).isValid, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // Longitude ∈ [95.0, 141.0]
    // -----------------------------------------------------------------------
    group('Longitude [95, 141]', () {
      Glados(_doubleInRange(_lonMin, _lonMax))
          .test('accepts longitudes inside Indonesia bounds', (lon) {
        expect(lon, inInclusiveRange(_lonMin, _lonMax));
        expect(Validators.validateLongitude(lon).isValid, isTrue,
            reason: 'Expected valid longitude for $lon');
      });

      Glados(_doubleInRange(-180.0, 94.9999))
          .test('rejects longitudes below 95.0', (lon) {
        expect(lon, lessThan(_lonMin));
        expect(Validators.validateLongitude(lon).isValid, isFalse);
      });

      Glados(_doubleInRange(141.0001, 180.0))
          .test('rejects longitudes above 141.0', (lon) {
        expect(lon, greaterThan(_lonMax));
        expect(Validators.validateLongitude(lon).isValid, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // Pair (latitude, longitude)
    // -----------------------------------------------------------------------
    group('Pair (latitude, longitude)', () {
      Glados2(_doubleInRange(_latMin, _latMax),
              _doubleInRange(_lonMin, _lonMax))
          .test('accepts pairs fully inside Indonesia bounds', (lat, lon) {
        expect(Validators.validateGpsCoordinates(lat, lon).isValid, isTrue,
            reason: 'Expected valid pair ($lat, $lon)');
      });

      // At-least-one out-of-range → invalid. Covered in two directions:
      // (out lat, any lon) and (any lat, out lon).
      Glados2(_doubleInRange(-90.0, -11.0001),
              _doubleInRange(-180.0, 180.0))
          .test('rejects pairs whose latitude is out of range', (lat, lon) {
        expect(Validators.validateGpsCoordinates(lat, lon).isValid, isFalse);
      });

      Glados2(_doubleInRange(-90.0, 90.0),
              _doubleInRange(141.0001, 180.0))
          .test('rejects pairs whose longitude is out of range', (lat, lon) {
        expect(Validators.validateGpsCoordinates(lat, lon).isValid, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // Fixed boundary and null-handling checks.
    // -----------------------------------------------------------------------
    group('Boundaries and null', () {
      test('accepts exact boundary coordinates (inclusive range)', () {
        expect(Validators.validateLatitude(_latMin).isValid, isTrue);
        expect(Validators.validateLatitude(_latMax).isValid, isTrue);
        expect(Validators.validateLongitude(_lonMin).isValid, isTrue);
        expect(Validators.validateLongitude(_lonMax).isValid, isTrue);
        expect(
            Validators.validateGpsCoordinates(_latMin, _lonMin).isValid, isTrue);
        expect(
            Validators.validateGpsCoordinates(_latMax, _lonMax).isValid, isTrue);
      });

      test('rejects null latitude and null longitude', () {
        expect(Validators.validateLatitude(null).isValid, isFalse);
        expect(Validators.validateLongitude(null).isValid, isFalse);
        expect(Validators.validateGpsCoordinates(null, 110.0).isValid, isFalse);
        expect(Validators.validateGpsCoordinates(0.0, null).isValid, isFalse);
      });
    });
  });
}
