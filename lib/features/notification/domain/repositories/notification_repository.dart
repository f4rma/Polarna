import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/incident_log_entity.dart';

/// Abstract data contract between the notification domain and data layers.
///
/// Implementations live in
/// `data/repositories/notification_repository_impl.dart` and translate
/// domain entities to/from Firestore models.
abstract class NotificationRepository {
  /// Fetches incident logs with optional filters.
  ///
  /// - [warehouseId]: filter by specific warehouse.
  /// - [from]: only logs at or after this timestamp.
  /// - [to]: only logs at or before this timestamp.
  Future<Either<Failure, List<IncidentLogEntity>>> getIncidentLogs({
    String? warehouseId,
    DateTime? from,
    DateTime? to,
  });

  /// Creates a new incident log entry.
  Future<Either<Failure, IncidentLogEntity>> createIncidentLog(
    IncidentLogEntity log,
  );

  /// Marks an incident as resolved.
  Future<Either<Failure, Unit>> resolveIncident(String logId);
}
