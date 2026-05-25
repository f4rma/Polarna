import 'package:equatable/equatable.dart';

/// Immutable domain entity representing a single telemetry reading from an
/// IoT node attached to a cold-storage warehouse.
///
/// Mirrors the `telemetry/{telemetryId}` Firestore document described in
/// `design.md §Data Models`, except:
///   * `warehouseId` is the snake_case `id_gudang` carried on the IoT
///     payload, exposed in camelCase for Dart consumers.
///   * Firestore metadata (`receivedAt`) is not part of the domain entity —
///     it is added by the data layer when writing the document.
///
/// Requirements: 9.1, 9.3, 9.4.
class TelemetryEntity extends Equatable {
  /// Reference to `warehouses/{warehouseId}`. Never empty for valid payloads.
  final String warehouseId;

  /// Sampling time in UTC (ISO 8601 on the wire, [DateTime] in Dart).
  final DateTime timestamp;

  /// Ambient temperature in °C. Accepted range per Req 9.2: [-50.0, 100.0].
  final double temperature;

  /// Relative humidity in % RH. Accepted range per Req 9.2: [0.0, 100.0].
  final double humidity;

  const TelemetryEntity({
    required this.warehouseId,
    required this.timestamp,
    required this.temperature,
    required this.humidity,
  });

  /// Returns a copy of this entity with the given fields replaced.
  TelemetryEntity copyWith({
    String? warehouseId,
    DateTime? timestamp,
    double? temperature,
    double? humidity,
  }) {
    return TelemetryEntity(
      warehouseId: warehouseId ?? this.warehouseId,
      timestamp: timestamp ?? this.timestamp,
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
    );
  }

  @override
  List<Object?> get props => [warehouseId, timestamp, temperature, humidity];
}

/// Spec-level alias — the design document refers to this type as
/// `TelemetryRecord`. We expose it as a typedef so both names compile to the
/// same runtime type (no duplication, no manual conversion).
typedef TelemetryRecord = TelemetryEntity;
