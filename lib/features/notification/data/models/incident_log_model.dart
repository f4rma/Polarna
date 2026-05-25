import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firebase_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/incident_log_entity.dart';

/// Data-layer representation of an incident log, coupled to Firestore.
///
/// Extends [IncidentLogEntity] so it can be returned directly from the
/// repository without a manual `toEntity()` call — the domain layer still
/// only depends on the base entity interface.
class IncidentLogModel extends IncidentLogEntity {
  const IncidentLogModel({
    required super.id,
    required super.warehouseId,
    required super.warehouseName,
    required super.temperature,
    required super.threshold,
    required super.severity,
    required super.eventType,
    required super.affectedUmkmIds,
    required super.notificationsSent,
    required super.notificationsFailed,
    required super.timestamp,
    super.resolvedAt,
  });

  // ---------------------------------------------------------------------------
  // Factories
  // ---------------------------------------------------------------------------

  /// Builds an [IncidentLogModel] from a Firestore `incident_logs/{id}` doc.
  ///
  /// Throws [ServerException] when a required field is missing or has an
  /// unexpected type.
  factory IncidentLogModel.fromFirestore(DocumentSnapshot<Object?> doc) {
    final data = doc.data();
    if (data == null || data is! Map<String, dynamic>) {
      throw const ServerException('Dokumen incident log tidak ditemukan');
    }
    try {
      return IncidentLogModel(
        id: doc.id,
        warehouseId: data[FirebaseConstants.fieldWarehouseId] as String,
        warehouseName: data[FirebaseConstants.fieldWarehouseName] as String,
        temperature:
            (data[FirebaseConstants.fieldTemperature] as num).toDouble(),
        threshold: (data[FirebaseConstants.fieldThreshold] as num).toDouble(),
        severity: data[FirebaseConstants.fieldSeverity] as String,
        eventType: data[FirebaseConstants.fieldEventType] as String,
        affectedUmkmIds: List<String>.from(
          (data[FirebaseConstants.fieldAffectedUmkmIds] as List<dynamic>?) ??
              const <dynamic>[],
        ),
        notificationsSent: List<String>.from(
          (data[FirebaseConstants.fieldNotificationsSent] as List<dynamic>?) ??
              const <dynamic>[],
        ),
        notificationsFailed: List<String>.from(
          (data[FirebaseConstants.fieldNotificationsFailed]
                  as List<dynamic>?) ??
              const <dynamic>[],
        ),
        timestamp: (data[FirebaseConstants.fieldTimestamp] as Timestamp)
            .toDate()
            .toUtc(),
        resolvedAt: data[FirebaseConstants.fieldResolvedAt] != null
            ? (data[FirebaseConstants.fieldResolvedAt] as Timestamp)
                .toDate()
                .toUtc()
            : null,
      );
    } on TypeError catch (e) {
      throw ServerException('Skema dokumen incident log tidak valid: $e');
    }
  }

  /// Copy-constructor from a plain domain [IncidentLogEntity].
  factory IncidentLogModel.fromEntity(IncidentLogEntity e) {
    return IncidentLogModel(
      id: e.id,
      warehouseId: e.warehouseId,
      warehouseName: e.warehouseName,
      temperature: e.temperature,
      threshold: e.threshold,
      severity: e.severity,
      eventType: e.eventType,
      affectedUmkmIds: List<String>.from(e.affectedUmkmIds),
      notificationsSent: List<String>.from(e.notificationsSent),
      notificationsFailed: List<String>.from(e.notificationsFailed),
      timestamp: e.timestamp,
      resolvedAt: e.resolvedAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  /// Serialises this model into a Firestore-ready map for document creation.
  Map<String, dynamic> toFirestore() {
    return {
      FirebaseConstants.fieldWarehouseId: warehouseId,
      FirebaseConstants.fieldWarehouseName: warehouseName,
      FirebaseConstants.fieldTemperature: temperature,
      FirebaseConstants.fieldThreshold: threshold,
      FirebaseConstants.fieldSeverity: severity,
      FirebaseConstants.fieldEventType: eventType,
      FirebaseConstants.fieldAffectedUmkmIds: affectedUmkmIds,
      FirebaseConstants.fieldNotificationsSent: notificationsSent,
      FirebaseConstants.fieldNotificationsFailed: notificationsFailed,
      FirebaseConstants.fieldTimestamp: Timestamp.fromDate(timestamp),
      if (resolvedAt != null)
        FirebaseConstants.fieldResolvedAt: Timestamp.fromDate(resolvedAt!),
    };
  }
}
