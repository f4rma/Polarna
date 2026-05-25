import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firebase_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/incident_log_entity.dart';
import '../models/incident_log_model.dart';

/// Remote incident-log operations backed by Cloud Firestore.
///
/// All methods throw [AppException] subclasses on failure; the repository
/// layer is responsible for converting those into [Failure] objects.
abstract class NotificationDataSource {
  /// Fetches incident logs with optional filters.
  ///
  /// - [warehouseId]: filter by specific warehouse.
  /// - [from]: only logs at or after this timestamp.
  /// - [to]: only logs at or before this timestamp.
  Future<List<IncidentLogModel>> getIncidentLogs({
    String? warehouseId,
    DateTime? from,
    DateTime? to,
  });

  /// Creates a new incident log document and returns the persisted model.
  Future<IncidentLogModel> createIncidentLog(IncidentLogEntity log);

  /// Marks an incident as resolved by setting [resolvedAt].
  Future<void> resolveIncident(String logId, DateTime resolvedAt);
}

/// Firestore-backed implementation of [NotificationDataSource].
class NotificationDataSourceImpl implements NotificationDataSource {
  final FirebaseFirestore _firestore;

  const NotificationDataSourceImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  CollectionReference<Map<String, dynamic>> get _incidentLogs =>
      _firestore.collection(FirebaseConstants.incidentLogsCollection);

  @override
  Future<List<IncidentLogModel>> getIncidentLogs({
    String? warehouseId,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _incidentLogs;

      if (warehouseId != null) {
        query = query.where(
          FirebaseConstants.fieldWarehouseId,
          isEqualTo: warehouseId,
        );
      }
      if (from != null) {
        query = query.where(
          FirebaseConstants.fieldTimestamp,
          isGreaterThanOrEqualTo: Timestamp.fromDate(from),
        );
      }
      if (to != null) {
        query = query.where(
          FirebaseConstants.fieldTimestamp,
          isLessThanOrEqualTo: Timestamp.fromDate(to),
        );
      }

      query = query.orderBy(FirebaseConstants.fieldTimestamp, descending: true);

      final snap = await query.get();
      return snap.docs.map(IncidentLogModel.fromFirestore).toList();
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    }
  }

  @override
  Future<IncidentLogModel> createIncidentLog(IncidentLogEntity log) async {
    try {
      final docRef = _incidentLogs.doc();
      final model = IncidentLogModel(
        id: docRef.id,
        warehouseId: log.warehouseId,
        warehouseName: log.warehouseName,
        temperature: log.temperature,
        threshold: log.threshold,
        severity: log.severity,
        eventType: log.eventType,
        affectedUmkmIds: log.affectedUmkmIds,
        notificationsSent: log.notificationsSent,
        notificationsFailed: log.notificationsFailed,
        timestamp: log.timestamp,
        resolvedAt: log.resolvedAt,
      );
      await docRef.set(model.toFirestore());
      final snap = await docRef.get();
      return IncidentLogModel.fromFirestore(snap);
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    }
  }

  @override
  Future<void> resolveIncident(String logId, DateTime resolvedAt) async {
    try {
      await _incidentLogs.doc(logId).update({
        FirebaseConstants.fieldResolvedAt: Timestamp.fromDate(resolvedAt),
      });
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    }
  }

  /// Converts a Firestore exception into a typed [AppException].
  AppException _mapFirebaseException(FirebaseException e) {
    switch (e.code) {
      case 'not-found':
        return const ServerException('Incident log tidak ditemukan');
      case 'unavailable':
      case 'deadline-exceeded':
        return const TimeoutException();
      case 'permission-denied':
        return ServerException('Akses ditolak: ${e.message ?? e.code}');
      default:
        return ServerException(
          'FirebaseException(${e.code}): ${e.message ?? 'unknown error'}',
        );
    }
  }
}
