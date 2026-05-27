// Property tests for TelemetryParser sensor value range validation.
//
// Validates: Requirements 5.8
// Reference: .kiro/specs/coldshare-platform/requirements.md#Requirement 5
//
// Property 10: Validasi Rentang Nilai Sensor Telemetri
//   The TelemetryParser validates temperature in [-50.0, 100.0]°C and
//   humidity in [0.0, 100.0]% (per Requirement 9.2 — the parser's actual
//   validation range). Requirement 5.8 specifies the DHT22 operational range
//   [-40, +80]°C which is a subset; the parser uses the wider Req 9.2 range.
//   Values outside the parser range are rejected with the field name
//   ('suhu' or 'kelembapan') listed in invalidFields.

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

/// Builds a complete valid telemetry JSON map with overridable temp/hum.
/// All other fields are valid defaults so only the field under test triggers
/// rejection.
Map<String, dynamic> _validPayload({double? temp, double? hum}) {
  return {
    'id_gudang': 'warehouse_test_001',
    'timestamp': '2024-06-15T10:30:00Z',
    'suhu': temp ?? 25.0,
    'kelembapan': hum ?? 50.0,
  };
}

// ---------------------------------------------------------------------------
// Generators
// ---------------------------------------------------------------------------

/// Temperature in valid range [-50.0, 100.0].
/// Uses integer millidegrees mapped to double for uniform coverage.
final _validTempGen =
    any.intInRange(-50000, 100001).map((i) => i / 1000.0);

/// Temperature below -50.0 (range: -200.0 to -50.001).
final _belowMinTempGen =
    any.intInRange(-200000, -50001).map((i) => i / 1000.0);

/// Temperature above 100.0 (range: 100.001 to 250.0).
final _aboveMaxTempGen =
    any.intInRange(100001, 250001).map((i) => i / 1000.0);

/// Humidity in valid range [0.0, 100.0].
final _validHumGen = any.intInRange(0, 100001).map((i) => i / 1000.0);

/// Humidity below 0.0 (range: -100.0 to -0.001).
final _belowMinHumGen =
    any.intInRange(-100000, -1).map((i) => i / 1000.0);

/// Humidity above 100.0 (range: 100.001 to 200.0).
final _aboveMaxHumGen =
    any.intInRange(100001, 200001).map((i) => i / 1000.0);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group(
    'Property 10: Validasi Rentang Nilai Sensor Telemetri '
    '(Validates: Requirements 5.8)',
    () {
      // -------------------------------------------------------------------
      // 1. Temperature in [-50, 100] accepted → parse returns Right.
      // -------------------------------------------------------------------
      Glados(_validTempGen).test(
        'temperature in [-50, 100] is accepted (Right)',
        (temp) {
          final result = TelemetryParser.parse(_validPayload(temp: temp));

          expect(result.isRight(), isTrue,
              reason: 'Expected Right for temp=$temp but got Left: '
                  '${result.fold((f) => f.message, (_) => '')}');
        },
      );

      // -------------------------------------------------------------------
      // 2. Temperature < -50 rejected → Left with 'suhu' in invalidFields.
      // -------------------------------------------------------------------
      Glados(_belowMinTempGen).test(
        'temperature < -50 is rejected with "suhu" in invalidFields',
        (temp) {
          final result = TelemetryParser.parse(_validPayload(temp: temp));

          expect(result.isLeft(), isTrue,
              reason: 'Expected Left for temp=$temp but got Right');

          final failure = (result as Left).value as InvalidPayloadFailure;
          expect(failure.invalidFields, contains('suhu'),
              reason: 'invalidFields should contain "suhu" for temp=$temp');
        },
      );

      // -------------------------------------------------------------------
      // 3. Temperature > 100 rejected → Left with 'suhu' in invalidFields.
      // -------------------------------------------------------------------
      Glados(_aboveMaxTempGen).test(
        'temperature > 100 is rejected with "suhu" in invalidFields',
        (temp) {
          final result = TelemetryParser.parse(_validPayload(temp: temp));

          expect(result.isLeft(), isTrue,
              reason: 'Expected Left for temp=$temp but got Right');

          final failure = (result as Left).value as InvalidPayloadFailure;
          expect(failure.invalidFields, contains('suhu'),
              reason: 'invalidFields should contain "suhu" for temp=$temp');
        },
      );

      // -------------------------------------------------------------------
      // 4. Humidity in [0, 100] accepted → parse returns Right.
      // -------------------------------------------------------------------
      Glados(_validHumGen).test(
        'humidity in [0, 100] is accepted (Right)',
        (hum) {
          final result = TelemetryParser.parse(_validPayload(hum: hum));

          expect(result.isRight(), isTrue,
              reason: 'Expected Right for hum=$hum but got Left: '
                  '${result.fold((f) => f.message, (_) => '')}');
        },
      );

      // -------------------------------------------------------------------
      // 5. Humidity < 0 rejected → Left with 'kelembapan' in invalidFields.
      // -------------------------------------------------------------------
      Glados(_belowMinHumGen).test(
        'humidity < 0 is rejected with "kelembapan" in invalidFields',
        (hum) {
          final result = TelemetryParser.parse(_validPayload(hum: hum));

          expect(result.isLeft(), isTrue,
              reason: 'Expected Left for hum=$hum but got Right');

          final failure = (result as Left).value as InvalidPayloadFailure;
          expect(failure.invalidFields, contains('kelembapan'),
              reason:
                  'invalidFields should contain "kelembapan" for hum=$hum');
        },
      );

      // -------------------------------------------------------------------
      // 6. Humidity > 100 rejected → Left with 'kelembapan' in invalidFields.
      // -------------------------------------------------------------------
      Glados(_aboveMaxHumGen).test(
        'humidity > 100 is rejected with "kelembapan" in invalidFields',
        (hum) {
          final result = TelemetryParser.parse(_validPayload(hum: hum));

          expect(result.isLeft(), isTrue,
              reason: 'Expected Left for hum=$hum but got Right');

          final failure = (result as Left).value as InvalidPayloadFailure;
          expect(failure.invalidFields, contains('kelembapan'),
              reason:
                  'invalidFields should contain "kelembapan" for hum=$hum');
        },
      );

      // -------------------------------------------------------------------
      // 7. Both out of range → both 'suhu' and 'kelembapan' in invalidFields.
      // -------------------------------------------------------------------
      Glados(any.combine2(
        _aboveMaxTempGen,
        _aboveMaxHumGen,
        (double temp, double hum) => (temp: temp, hum: hum),
      )).test(
        'both temp > 100 and hum > 100 → both fields in invalidFields',
        (pair) {
          final result = TelemetryParser.parse(
            _validPayload(temp: pair.temp, hum: pair.hum),
          );

          expect(result.isLeft(), isTrue,
              reason: 'Expected Left for temp=${pair.temp}, hum=${pair.hum} '
                  'but got Right');

          final failure = (result as Left).value as InvalidPayloadFailure;
          expect(failure.invalidFields, contains('suhu'),
              reason: 'invalidFields should contain "suhu"');
          expect(failure.invalidFields, contains('kelembapan'),
              reason: 'invalidFields should contain "kelembapan"');
        },
      );
    },
  );
}
