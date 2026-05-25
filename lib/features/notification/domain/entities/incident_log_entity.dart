import 'package:equatable/equatable.dart';

/// Immutable domain entity representing a temperature incident log.
///
/// Mirrors the `incident_logs/{logId}` document in Cloud Firestore.
/// Records temperature violations and recoveries, tracking which UMKM
/// tenants were affected and notification delivery status.
///
/// Requirements: 7.1, 7.2, 7.5
class IncidentLogEntity extends Equatable {
  final String id;
  final String warehouseId;
  final String warehouseName;
  final double temperature;
  final double threshold;
  final String severity; // 'warning' | 'critical'
  final String eventType; // 'violation' | 'recovery'
  final List<String> affectedUmkmIds;
  final List<String> notificationsSent;
  final List<String> notificationsFailed;
  final DateTime timestamp;
  final DateTime? resolvedAt;

  const IncidentLogEntity({
    required this.id,
    required this.warehouseId,
    required this.warehouseName,
    required this.temperature,
    required this.threshold,
    required this.severity,
    required this.eventType,
    required this.affectedUmkmIds,
    required this.notificationsSent,
    required this.notificationsFailed,
    required this.timestamp,
    this.resolvedAt,
  });

  IncidentLogEntity copyWith({
    String? id,
    String? warehouseId,
    String? warehouseName,
    double? temperature,
    double? threshold,
    String? severity,
    String? eventType,
    List<String>? affectedUmkmIds,
    List<String>? notificationsSent,
    List<String>? notificationsFailed,
    DateTime? timestamp,
    DateTime? resolvedAt,
  }) {
    return IncidentLogEntity(
      id: id ?? this.id,
      warehouseId: warehouseId ?? this.warehouseId,
      warehouseName: warehouseName ?? this.warehouseName,
      temperature: temperature ?? this.temperature,
      threshold: threshold ?? this.threshold,
      severity: severity ?? this.severity,
      eventType: eventType ?? this.eventType,
      affectedUmkmIds: affectedUmkmIds ?? this.affectedUmkmIds,
      notificationsSent: notificationsSent ?? this.notificationsSent,
      notificationsFailed: notificationsFailed ?? this.notificationsFailed,
      timestamp: timestamp ?? this.timestamp,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        warehouseId,
        warehouseName,
        temperature,
        threshold,
        severity,
        eventType,
        affectedUmkmIds,
        notificationsSent,
        notificationsFailed,
        timestamp,
        resolvedAt,
      ];
}
