import 'dart:convert';

import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/telemetry_entity.dart';

/// Canonical snake_case keys exchanged on the wire with the ESP32 IoT node
/// (Requirement 9.2). Duplicated here intentionally so `TelemetryParser`
/// stays a pure-Dart module that can be used in Cloud Functions / isolates
/// without dragging in the Firebase SDK via `TelemetryModel`.
class _JsonKeys {
  _JsonKeys._();

  static const String warehouseId = 'id_gudang';
  static const String timestamp = 'timestamp';
  static const String temperature = 'suhu';
  static const String humidity = 'kelembapan';

  /// Synthetic key used to report payload-level issues (size / JSON syntax)
  /// that are not tied to an individual field.
  static const String payloadSize = 'payload_size';
  static const String payloadFormat = 'payload_format';
}

/// Parses and validates the JSON payload produced by the IoT layer and
/// converts it into a [TelemetryRecord] suitable for storage in Firestore.
///
/// The class is intentionally framework-free:
///   * no Firebase dependency — safe to reuse in a Cloud Function,
///   * no instance state — all members are `static`,
///   * single-pass validation — every field issue in one response
///     (Requirement 9.2, "must name WHICH field is invalid + reason").
///
/// Requirements: 9.1, 9.2, 9.4.
class TelemetryParser {
  TelemetryParser._();

  // ---------------------------------------------------------------------------
  // Limits (Req 9.1 — payload ≤ 64 KB)
  // ---------------------------------------------------------------------------

  /// Hard ceiling for a single telemetry payload. Payloads above this size
  /// are rejected without being decoded (Requirement 9.1).
  static const int maxPayloadBytes = 64 * 1024;

  // ---------------------------------------------------------------------------
  // Field-level limits (Req 9.2)
  // ---------------------------------------------------------------------------

  static const double minTemperature = -50.0;
  static const double maxTemperature = 100.0;
  static const double minHumidity = 0.0;
  static const double maxHumidity = 100.0;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Validates [json] against Requirement 9.2 and returns a [TelemetryRecord]
  /// on success or an [InvalidPayloadFailure] listing *every* offending
  /// field on failure.
  static Either<Failure, TelemetryRecord> parse(Map<String, dynamic> json) {
    final invalid = <String>[];

    final warehouseId = _extractWarehouseId(json, invalid);
    final timestamp = _extractTimestamp(json, invalid);
    final temperature = _extractTemperature(json, invalid);
    final humidity = _extractHumidity(json, invalid);

    if (invalid.isNotEmpty) {
      return Left(InvalidPayloadFailure(invalidFields: invalid));
    }

    return Right(
      TelemetryRecord(
        warehouseId: warehouseId!,
        timestamp: timestamp!,
        temperature: temperature!,
        humidity: humidity!,
      ),
    );
  }

  /// Serialises a [TelemetryRecord] back into the snake_case JSON shape
  /// accepted by [parse]. Guarantees `parse(format(parse(json)))` is
  /// identical to the first `parse(json)` result (Requirement 9.4).
  static Map<String, dynamic> format(TelemetryRecord record) {
    return {
      _JsonKeys.warehouseId: record.warehouseId,
      _JsonKeys.timestamp: record.timestamp.toUtc().toIso8601String(),
      _JsonKeys.temperature: record.temperature,
      _JsonKeys.humidity: record.humidity,
    };
  }

  /// Convenience wrapper that decodes a raw UTF-8 HTTP body and delegates
  /// to [parse]. Enforces:
  ///   * payload size ≤ [maxPayloadBytes] (Req 9.1),
  ///   * body is valid UTF-8 JSON,
  ///   * the decoded value is a JSON object.
  ///
  /// Any problem produces an [InvalidPayloadFailure] so the HTTP handler
  /// can return a single, consistent 400 response.
  static Either<Failure, TelemetryRecord> parseBytes(List<int> utf8Bytes) {
    if (utf8Bytes.length > maxPayloadBytes) {
      return Left(InvalidPayloadFailure(
        invalidFields: const [_JsonKeys.payloadSize],
      ));
    }

    final dynamic decoded;
    try {
      final body = utf8.decode(utf8Bytes);
      decoded = json.decode(body);
    } on FormatException {
      return Left(InvalidPayloadFailure(
        invalidFields: const [_JsonKeys.payloadFormat],
      ));
    }

    if (decoded is! Map<String, dynamic>) {
      return Left(InvalidPayloadFailure(
        invalidFields: const [_JsonKeys.payloadFormat],
      ));
    }

    return parse(decoded);
  }

  // ---------------------------------------------------------------------------
  // Internal field extractors — each one appends to [invalid] on failure so
  // `parse` collects every issue in a single pass (Req 9.2).
  // ---------------------------------------------------------------------------

  static String? _extractWarehouseId(
    Map<String, dynamic> json,
    List<String> invalid,
  ) {
    final raw = json[_JsonKeys.warehouseId];
    if (raw is String && raw.trim().isNotEmpty) return raw;
    invalid.add(_JsonKeys.warehouseId);
    return null;
  }

  static DateTime? _extractTimestamp(
    Map<String, dynamic> json,
    List<String> invalid,
  ) {
    final raw = json[_JsonKeys.timestamp];
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    invalid.add(_JsonKeys.timestamp);
    return null;
  }

  static double? _extractTemperature(
    Map<String, dynamic> json,
    List<String> invalid,
  ) {
    final raw = json[_JsonKeys.temperature];
    if (raw is num) {
      final value = raw.toDouble();
      if (!value.isNaN &&
          !value.isInfinite &&
          value >= minTemperature &&
          value <= maxTemperature) {
        return value;
      }
    }
    invalid.add(_JsonKeys.temperature);
    return null;
  }

  static double? _extractHumidity(
    Map<String, dynamic> json,
    List<String> invalid,
  ) {
    final raw = json[_JsonKeys.humidity];
    if (raw is num) {
      final value = raw.toDouble();
      if (!value.isNaN &&
          !value.isInfinite &&
          value >= minHumidity &&
          value <= maxHumidity) {
        return value;
      }
    }
    invalid.add(_JsonKeys.humidity);
    return null;
  }
}
