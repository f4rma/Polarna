import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firebase_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/telemetry_model.dart';

/// Remote telemetry operations backed by Cloud Firestore.
///
/// All methods throw [AppException] subclasses on failure; the repository
/// layer is responsible for converting those into [Failure] objects.
abstract class TelemetryRemoteDataSource {
  /// Emits the latest [TelemetryModel] every time a new reading arrives
  /// for the given [warehouseId].
  Stream<TelemetryModel> watchLatestTelemetry(String warehouseId);

  /// Fetches historical telemetry readings for [warehouseId] between
  /// [from] and [to] (inclusive), ordered by timestamp ascending.
  Future<List<TelemetryModel>> getHistory({
    required String warehouseId,
    required DateTime from,
    required DateTime to,
  });

  /// Returns the single most recent reading for [warehouseId], or `null`
  /// if no data has been recorded yet.
  Future<TelemetryModel?> getLatest(String warehouseId);
}

/// Firestore-backed implementation of [TelemetryRemoteDataSource].
class TelemetryRemoteDataSourceImpl implements TelemetryRemoteDataSource {
  final FirebaseFirestore _firestore;

  const TelemetryRemoteDataSourceImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  CollectionReference<Map<String, dynamic>> get _telemetry =>
      _firestore.collection(FirebaseConstants.telemetryCollection);

  @override
  Stream<TelemetryModel> watchLatestTelemetry(String warehouseId) {
    return _telemetry
        .where(FirebaseConstants.fieldWarehouseId, isEqualTo: warehouseId)
        .orderBy(FirebaseConstants.fieldTimestamp, descending: true)
        .limit(1)
        .snapshots()
        .where((snapshot) => snapshot.docs.isNotEmpty) // Skip empty snapshots
        .map((snapshot) => TelemetryModel.fromFirestore(snapshot.docs.first));
  }

  @override
  Future<List<TelemetryModel>> getHistory({
    required String warehouseId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final snapshot = await _telemetry
          .where(FirebaseConstants.fieldWarehouseId, isEqualTo: warehouseId)
          .where(
            FirebaseConstants.fieldTimestamp,
            isGreaterThanOrEqualTo: Timestamp.fromDate(from.toUtc()),
          )
          .where(
            FirebaseConstants.fieldTimestamp,
            isLessThanOrEqualTo: Timestamp.fromDate(to.toUtc()),
          )
          .orderBy(FirebaseConstants.fieldTimestamp)
          .get();
      return snapshot.docs.map(TelemetryModel.fromFirestore).toList();
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    }
  }

  @override
  Future<TelemetryModel?> getLatest(String warehouseId) async {
    try {
      final snapshot = await _telemetry
          .where(FirebaseConstants.fieldWarehouseId, isEqualTo: warehouseId)
          .orderBy(FirebaseConstants.fieldTimestamp, descending: true)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return TelemetryModel.fromFirestore(snapshot.docs.first);
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  AppException _mapFirebaseException(FirebaseException e) {
    switch (e.code) {
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
