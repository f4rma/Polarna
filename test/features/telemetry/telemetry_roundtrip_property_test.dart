// Property tests for round-trip serialisation of TelemetryRecord.
//
// Validates: Requirements 9.1, 9.4
// Reference: .kiro/specs/coldshare-platform/requirements.md#Requirement 9
//
// Property 11: Round-Trip Serialisasi TelemetryRecord
//   For every valid TelemetryRecord (warehouseId non-empty, timestamp UTC,
//   temperature [-50,100], humidity [0,100]),
//   `TelemetryParser.parse(TelemetryParser.format(record))` SHALL produce
//   an identical record (all 4 fields match).

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
// `glados` re-exports `package:test/test.dart`, which collides with
// `flutter_test`. Hide the duplicates so the flutter_test versions win.
// ignore: depend_on_referenced_packages
import 'package:glados/glados.dart' hide test, group, expect;
import 'package:polarna/features/telemetry/data/models/telemetry_model.dart';
import 'package:polarna/features/telemetry/data/parsers/telemetry_parser.dart';
import 'package:polarna/features/telemetry/domain/entities/telemetry_entity.dart';

// ---------------------------------------------------------------------------
// Generators
// ---------------------------------------------------------------------------

const _alphanumeric = 'abcdefghijklmnopqrstuvwxyz'
    'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    '0123456789';

List<String> _chars(String s) => s.split('');

/// Generates a random alphanumeric string of length [minLen] to [maxLen].
Generator<String> _stringInRange(int minLen, int maxLen, String pool) {
  return any
      .listWithLengthInRange(minLen, maxLen + 1, any.choose(_chars(pool)))
      .map((list) => list.join());
}

/// warehouseId: random alphanumeric string 5-20 chars.
final _warehouseIdGen = _stringInRange(5, 20, _alphanumeric);

/// timestamp: random UTC DateTime (year 2020-2030, month 1-12, day 1-28,
/// hour 0-23, minute 0-59, second 0-59).
final _timestampGen = any.combine6(
  any.intInRange(2020, 2031), // year [2020, 2030]
  any.intInRange(1, 13), // month [1, 12]
  any.intInRange(1, 29), // day [1, 28]
  any.intInRange(0, 24), // hour [0, 23]
  any.intInRange(0, 60), // minute [0, 59]
  any.intInRange(0, 60), // second [0, 59]
  (int y, int m, int d, int h, int min, int sec) =>
      DateTime.utc(y, m, d, h, min, sec),
);

/// temperature: double in [-50.0, 100.0].
final _temperatureGen =
    any.intInRange(-50000, 100001).map((i) => i / 1000.0);

/// humidity: double in [0.0, 100.0].
final _humidityGen = any.intInRange(0, 100001).map((i) => i / 1000.0);

/// Compose into a TelemetryRecord generator using combine4.
final _telemetryRecordGen = any.combine4(
  _warehouseIdGen,
  _timestampGen,
  _temperatureGen,
  _humidityGen,
  (String wId, DateTime ts, double temp, double hum) => TelemetryRecord(
    warehouseId: wId,
    timestamp: ts,
    temperature: temp,
    humidity: hum,
  ),
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group(
    'Property 11: Round-Trip Serialisasi TelemetryRecord '
    '(Validates: Requirements 9.1, 9.4)',
    () {
      // ---------------------------------------------------------------------
      // Property 1: Round-trip via TelemetryParser
      // parse(format(record)) → Right(record) with all 4 fields identical.
      // ---------------------------------------------------------------------
      Glados(_telemetryRecordGen).test(
        'parse(format(record)) produces Right with identical fields',
        (record) {
          final json = TelemetryParser.format(record);
          final result = TelemetryParser.parse(json);

          expect(result.isRight(), isTrue,
              reason: 'Expected Right but got Left for record: '
                  '${record.warehouseId}');

          final parsed = (result as Right).value as TelemetryRecord;

          expect(parsed.warehouseId, equals(record.warehouseId));
          expect(
            parsed.timestamp.toUtc().toIso8601String(),
            equals(record.timestamp.toUtc().toIso8601String()),
          );
          expect(parsed.temperature, closeTo(record.temperature, 1e-10));
          expect(parsed.humidity, closeTo(record.humidity, 1e-10));
        },
      );

      // ---------------------------------------------------------------------
      // Property 2: Round-trip via TelemetryModel
      // TelemetryModel.fromJson(TelemetryModel.fromEntity(record).toJson())
      // produces identical fields.
      // ---------------------------------------------------------------------
      Glados(_telemetryRecordGen).test(
        'TelemetryModel.fromJson(TelemetryModel.fromEntity(record).toJson()) '
        'produces identical fields',
        (record) {
          final model = TelemetryModel.fromEntity(record);
          final json = model.toJson();
          final restored = TelemetryModel.fromJson(json);

          expect(restored.warehouseId, equals(record.warehouseId));
          expect(
            restored.timestamp.toUtc().toIso8601String(),
            equals(record.timestamp.toUtc().toIso8601String()),
          );
          expect(restored.temperature, closeTo(record.temperature, 1e-10));
          expect(restored.humidity, closeTo(record.humidity, 1e-10));
        },
      );

      // ---------------------------------------------------------------------
      // Property 3: Format output contains all required JSON keys
      // format(record) map has keys id_gudang, timestamp, suhu, kelembapan.
      // ---------------------------------------------------------------------
      Glados(_telemetryRecordGen).test(
        'format(record) contains all required JSON keys',
        (record) {
          final json = TelemetryParser.format(record);

          expect(json, contains('id_gudang'));
          expect(json, contains('timestamp'));
          expect(json, contains('suhu'));
          expect(json, contains('kelembapan'));
        },
      );

      // ---------------------------------------------------------------------
      // Property 4: Timestamp preserved as ISO 8601 UTC
      // format(record)['timestamp'] ends with 'Z' or contains '+00:00'.
      // ---------------------------------------------------------------------
      Glados(_telemetryRecordGen).test(
        'format(record)[timestamp] is ISO 8601 UTC (ends with Z or +00:00)',
        (record) {
          final json = TelemetryParser.format(record);
          final ts = json['timestamp'] as String;

          final isUtc = ts.endsWith('Z') || ts.contains('+00:00');
          expect(isUtc, isTrue,
              reason: 'Timestamp "$ts" is not in UTC format');
        },
      );
    },
  );
}
