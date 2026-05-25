import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/telemetry_entity.dart';

/// Abstract data contract between the telemetry domain and data layers.
///
/// Implementations live in `data/repositories/telemetry_repository_impl.dart`
/// and handle Firestore queries, real-time listeners, and error mapping.
///
/// Requirements: 5.1–5.8, 6.1–6.5, 9.1–9.4.
abstract class TelemetryRepository {
  /// Emits the latest [TelemetryRecord] every time a new reading arrives
  /// for the given [warehouseId].
  ///
  /// Errors propagate as stream errors (no Either wrapping).
  Stream<TelemetryRecord> watchLatestTelemetry(String warehouseId);

  /// Fetches historical telemetry readings for [warehouseId] between
  /// [from] and [to] (inclusive), ordered by timestamp ascending.
  Future<Either<Failure, List<TelemetryRecord>>> getHistory({
    required String warehouseId,
    required DateTime from,
    required DateTime to,
  });

  /// Returns the single most recent reading for [warehouseId], or `null`
  /// if no data has been recorded yet.
  Future<Either<Failure, TelemetryRecord?>> getLatest(String warehouseId);
}
