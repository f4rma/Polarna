import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firebase_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/telemetry_entity.dart';

/// Canonical snake_case keys used on the HTTP payload exchanged with the
/// ESP32 IoT node (see Requirement 9.2). Kept private so callers go through
/// `fromJson` / `toJson` and never hard-code a key string.
class _JsonKeys {
  _JsonKeys._();

  static const String warehouseId = 'id_gudang';
  static const String timestamp = 'timestamp';
  static const String temperature = 'suhu';
  static const String humidity = 'kelembapan';
}

/// Data-layer representation of a telemetry reading.
///
/// Extends [TelemetryEntity] so repositories can return it without an
/// explicit `toEntity()` step. Two serialisation dialects are supported:
///
///   * Firestore camelCase (`warehouseId`, `timestamp`, `temperature`,
///     `humidity`) — see [fromFirestore] / [toFirestore].
///   * HTTP snake_case (`id_gudang`, `timestamp`, `suhu`, `kelembapan`) —
///     see [fromJson] / [toJson].
///
/// Validation of individual field *ranges* lives in `TelemetryParser` —
/// this model only deals with the JSON/Firestore shape.
class TelemetryModel extends TelemetryEntity {
  const TelemetryModel({
    required super.warehouseId,
    required super.timestamp,
    required super.temperature,
    required super.humidity,
  });

  /// Copy-constructor from a plain domain [TelemetryEntity].
  factory TelemetryModel.fromEntity(TelemetryEntity entity) {
    return TelemetryModel(
      warehouseId: entity.warehouseId,
      timestamp: entity.timestamp,
      temperature: entity.temperature,
      humidity: entity.humidity,
    );
  }

  // ---------------------------------------------------------------------------
  // Firestore (camelCase) serialisation
  // ---------------------------------------------------------------------------

  /// Builds a [TelemetryModel] from a `telemetry/{id}` Firestore document.
  ///
  /// Throws [ServerException] when the document is missing, empty, or has a
  /// field with the wrong type.
  factory TelemetryModel.fromFirestore(DocumentSnapshot<Object?> doc) {
    final data = doc.data();
    if (data == null || data is! Map<String, dynamic>) {
      throw const ServerException('Dokumen telemetri tidak ditemukan');
    }
    try {
      return TelemetryModel(
        warehouseId: data[FirebaseConstants.fieldWarehouseId] as String,
        timestamp:
            (data[FirebaseConstants.fieldTimestamp] as Timestamp).toDate(),
        temperature:
            (data[FirebaseConstants.fieldTemperature] as num).toDouble(),
        humidity: (data[FirebaseConstants.fieldHumidity] as num).toDouble(),
      );
    } on TypeError catch (e) {
      throw ServerException('Skema dokumen telemetri tidak valid: $e');
    }
  }

  /// Serialises this model into a Firestore-ready map.
  ///
  /// `receivedAt` is set to the server timestamp so it is filled in by
  /// Firestore atomically with the write — matches the schema in
  /// `design.md §Data Models`.
  Map<String, dynamic> toFirestore() {
    return {
      FirebaseConstants.fieldWarehouseId: warehouseId,
      FirebaseConstants.fieldTimestamp: Timestamp.fromDate(timestamp.toUtc()),
      FirebaseConstants.fieldTemperature: temperature,
      FirebaseConstants.fieldHumidity: humidity,
      FirebaseConstants.fieldReceivedAt: FieldValue.serverTimestamp(),
    };
  }

  // ---------------------------------------------------------------------------
  // HTTP JSON (snake_case) serialisation
  // ---------------------------------------------------------------------------

  /// Parses the raw snake_case JSON sent by the ESP32 IoT node.
  ///
  /// Walks every required field in a single pass and collects *every*
  /// problem — missing, wrongly typed, or (for `timestamp`) malformed — so
  /// the caller can surface **all** issues in one response
  /// (Requirement 9.2).
  ///
  /// Throws [InvalidPayloadException] with `invalidFields` listing each
  /// offending key. Range checks (e.g. temperature outside [-50, 100]) are
  /// the responsibility of `TelemetryParser.parse`, which calls this
  /// factory and layers the extra validation on top.
  factory TelemetryModel.fromJson(Map<String, dynamic> json) {
    final invalid = <String>[];

    final warehouseIdRaw = json[_JsonKeys.warehouseId];
    String? warehouseId;
    if (warehouseIdRaw is String && warehouseIdRaw.trim().isNotEmpty) {
      warehouseId = warehouseIdRaw;
    } else {
      invalid.add(_JsonKeys.warehouseId);
    }

    final timestampRaw = json[_JsonKeys.timestamp];
    DateTime? timestamp;
    if (timestampRaw is String) {
      timestamp = DateTime.tryParse(timestampRaw);
      if (timestamp == null) invalid.add(_JsonKeys.timestamp);
    } else {
      invalid.add(_JsonKeys.timestamp);
    }

    final tempRaw = json[_JsonKeys.temperature];
    double? temperature;
    if (tempRaw is num) {
      temperature = tempRaw.toDouble();
    } else {
      invalid.add(_JsonKeys.temperature);
    }

    final humRaw = json[_JsonKeys.humidity];
    double? humidity;
    if (humRaw is num) {
      humidity = humRaw.toDouble();
    } else {
      invalid.add(_JsonKeys.humidity);
    }

    if (invalid.isNotEmpty) {
      throw InvalidPayloadException(invalidFields: invalid);
    }

    return TelemetryModel(
      warehouseId: warehouseId!,
      timestamp: timestamp!,
      temperature: temperature!,
      humidity: humidity!,
    );
  }

  /// Serialises this model to the snake_case JSON shape accepted by
  /// [fromJson] — guarantees the round-trip property in Req 9.4.
  Map<String, dynamic> toJson() {
    return {
      _JsonKeys.warehouseId: warehouseId,
      _JsonKeys.timestamp: timestamp.toUtc().toIso8601String(),
      _JsonKeys.temperature: temperature,
      _JsonKeys.humidity: humidity,
    };
  }
}
