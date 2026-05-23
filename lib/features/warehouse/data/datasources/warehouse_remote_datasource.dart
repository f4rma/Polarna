import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firebase_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/warehouse_entity.dart';
import '../../domain/entities/warehouse_search_filter.dart';
import '../models/warehouse_model.dart';

/// Remote warehouse operations backed by Cloud Firestore.
///
/// All methods throw [AppException] subclasses on failure; the repository
/// layer is responsible for converting those into [Failure] objects.
abstract class WarehouseRemoteDataSource {
  /// Creates a new `warehouses/{id}` document.  The assigned id is written
  /// back into the returned model.  If [w.remainingCapacity] is zero, the
  /// stored value is initialised to [w.totalCapacity] — a newly registered
  /// warehouse is assumed to be empty and therefore fully available.
  Future<WarehouseModel> registerWarehouse(WarehouseEntity w);

  /// Updates an existing warehouse document via [WarehouseModel.toUpdateMap].
  /// Throws [WarehouseNotFoundException] when [w.id] does not exist.
  Future<WarehouseModel> updateWarehouse(WarehouseEntity w);

  /// Searches warehouses matching [filter].  The distance filter is applied
  /// client-side using the Haversine formula because Firestore does not
  /// support native geo-distance queries.  Results are ordered by distance
  /// ascending when a search centre is provided; otherwise by name.
  Future<List<WarehouseModel>> searchWarehouses(WarehouseSearchFilter filter);

  /// Flips the `isActive` flag for a warehouse (Requirements 2.7, 2.8).
  Future<void> toggleStatus({
    required String warehouseId,
    required bool isActive,
  });

  /// Fetches a single warehouse by id.  Throws
  /// [WarehouseNotFoundException] when the document is missing.
  Future<WarehouseModel> getById(String id);

  /// Fetches all warehouses belonging to [mitraId].
  Future<List<WarehouseModel>> getByMitraId(String mitraId);

  /// Emits the latest [WarehouseModel] for [id] whenever the underlying
  /// document changes.  The stream emits an error (via
  /// [WarehouseNotFoundException]) when the document is deleted.
  Stream<WarehouseModel> watchById(String id);

  /// Atomically writes [newRemainingCapacity] after enforcing the
  /// `remainingCapacity <= totalCapacity` invariant (Requirement 2.6).
  /// Throws [InvalidRemainingCapacityException] when the new value would
  /// violate the invariant.
  Future<WarehouseModel> updateRemainingCapacity({
    required String warehouseId,
    required double newRemainingCapacity,
  });
}

class WarehouseRemoteDataSourceImpl implements WarehouseRemoteDataSource {
  final FirebaseFirestore _firestore;

  const WarehouseRemoteDataSourceImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  CollectionReference<Map<String, dynamic>> get _warehouses =>
      _firestore.collection(FirebaseConstants.warehousesCollection);

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  @override
  Future<WarehouseModel> registerWarehouse(WarehouseEntity w) async {
    try {
      final now = DateTime.now().toUtc();
      // New warehouses default remainingCapacity = totalCapacity.
      final remaining =
          w.remainingCapacity == 0 ? w.totalCapacity : w.remainingCapacity;
      final docRef = _warehouses.doc();
      final toStore = WarehouseModel(
        id: docRef.id,
        mitraId: w.mitraId,
        name: w.name,
        address: w.address,
        latitude: w.latitude,
        longitude: w.longitude,
        totalCapacity: w.totalCapacity,
        remainingCapacity: remaining,
        pricePerM3PerDay: w.pricePerM3PerDay,
        temperatureCategory: w.temperatureCategory,
        temperatureThreshold: w.temperatureThreshold,
        photoUrls: w.photoUrls,
        isActive: w.isActive,
        verificationStatus: w.verificationStatus,
        iotNodeId: w.iotNodeId,
        createdAt: now,
        updatedAt: now,
      );
      // Use server timestamps for createdAt/updatedAt so writes from
      // multiple clients share the same clock source.
      final payload = toStore.toFirestore()
        ..[FirebaseConstants.fieldCreatedAt] = FieldValue.serverTimestamp()
        ..[FirebaseConstants.fieldUpdatedAt] = FieldValue.serverTimestamp();
      await docRef.set(payload);
      // Re-read so the returned model carries the authoritative server
      // timestamps (Firestore resolves them on the server side).
      final snap = await docRef.get();
      return WarehouseModel.fromFirestore(snap);
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    }
  }

  @override
  Future<WarehouseModel> updateWarehouse(WarehouseEntity w) async {
    if (w.id.isEmpty) {
      throw const WarehouseNotFoundException();
    }
    try {
      final docRef = _warehouses.doc(w.id);
      final model = WarehouseModel.fromEntity(w);
      await docRef.update(model.toUpdateMap());
      final snap = await docRef.get();
      return WarehouseModel.fromFirestore(snap);
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    }
  }

  @override
  Future<void> toggleStatus({
    required String warehouseId,
    required bool isActive,
  }) async {
    try {
      await _warehouses.doc(warehouseId).update({
        FirebaseConstants.fieldIsActiveWarehouse: isActive,
        FirebaseConstants.fieldUpdatedAt: FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    }
  }

  @override
  Future<WarehouseModel> updateRemainingCapacity({
    required String warehouseId,
    required double newRemainingCapacity,
  }) async {
    try {
      final docRef = _warehouses.doc(warehouseId);
      final updated = await _firestore.runTransaction<WarehouseModel>(
        (txn) async {
          final snap = await txn.get(docRef);
          if (!snap.exists) {
            throw const WarehouseNotFoundException();
          }
          final current = WarehouseModel.fromFirestore(snap);
          if (newRemainingCapacity < 0 ||
              newRemainingCapacity > current.totalCapacity) {
            throw InvalidRemainingCapacityException(
              totalCapacity: current.totalCapacity,
            );
          }
          txn.update(docRef, {
            FirebaseConstants.fieldRemainingCapacity: newRemainingCapacity,
            FirebaseConstants.fieldUpdatedAt: FieldValue.serverTimestamp(),
          });
          return current.copyWithModel(
            remainingCapacity: newRemainingCapacity,
            updatedAt: DateTime.now().toUtc(),
          );
        },
      );
      return updated;
    } on InvalidRemainingCapacityException {
      rethrow;
    } on WarehouseNotFoundException {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  @override
  Future<WarehouseModel> getById(String id) async {
    try {
      final snap = await _warehouses.doc(id).get();
      if (!snap.exists) {
        throw const WarehouseNotFoundException();
      }
      return WarehouseModel.fromFirestore(snap);
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    }
  }

  @override
  Future<List<WarehouseModel>> getByMitraId(String mitraId) async {
    try {
      final snap = await _warehouses
          .where(FirebaseConstants.fieldMitraId, isEqualTo: mitraId)
          .get();
      return snap.docs.map(WarehouseModel.fromFirestore).toList();
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    }
  }

  @override
  Stream<WarehouseModel> watchById(String id) {
    return _warehouses.doc(id).snapshots().map((snap) {
      if (!snap.exists) {
        throw const WarehouseNotFoundException();
      }
      return WarehouseModel.fromFirestore(snap);
    }).handleError((Object err) {
      if (err is AppException) throw err;
      if (err is FirebaseException) throw _mapFirebaseException(err);
      throw ServerException(err.toString());
    });
  }

  @override
  Future<List<WarehouseModel>> searchWarehouses(
    WarehouseSearchFilter filter,
  ) async {
    try {
      // Simplified query: only filter by isActive on server-side.
      // Other filters applied client-side to avoid complex composite indexes.
      Query<Map<String, dynamic>> q = _warehouses
          .where(FirebaseConstants.fieldIsActiveWarehouse, isEqualTo: true);

      if (filter.category != null) {
        q = q.where(
          FirebaseConstants.fieldTemperatureCategory,
          isEqualTo: filter.category!.toStorageString(),
        );
      }

      final snap = await q.get();
      var all = snap.docs.map(WarehouseModel.fromFirestore).toList();

      // Client-side filters
      all = all.where((w) => w.remainingCapacity > 0).toList();

      if (filter.minCapacityM3 != null) {
        all = all.where((w) => w.remainingCapacity >= filter.minCapacityM3!).toList();
      }
      if (filter.minPricePerM3 != null) {
        all = all.where((w) => w.pricePerM3PerDay >= filter.minPricePerM3!).toList();
      }
      if (filter.maxPricePerM3 != null) {
        all = all.where((w) => w.pricePerM3PerDay <= filter.maxPricePerM3!).toList();
      }

      // Client-side distance filter (Firestore lacks native geo-distance).
      final hasCenter = filter.centerLatitude != null &&
          filter.centerLongitude != null;
      final radius = filter.radiusKm;
      if (hasCenter && radius != null) {
        final lat = filter.centerLatitude!;
        final lon = filter.centerLongitude!;
        final within = <_ScoredWarehouse>[];
        for (final w in all) {
          final d = _haversineKm(lat, lon, w.latitude, w.longitude);
          if (d <= radius) within.add(_ScoredWarehouse(w, d));
        }
        within.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        return within.map((s) => s.warehouse).toList();
      } else if (hasCenter) {
        // Centre provided but no radius → order by distance, no filter.
        final lat = filter.centerLatitude!;
        final lon = filter.centerLongitude!;
        final scored = all
            .map((w) => _ScoredWarehouse(
                  w,
                  _haversineKm(lat, lon, w.latitude, w.longitude),
                ))
            .toList()
          ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        return scored.map((s) => s.warehouse).toList();
      }

      all.sort((a, b) => a.name.compareTo(b.name));
      return all;
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Converts a Firestore exception into a typed [AppException].
  AppException _mapFirebaseException(FirebaseException e) {
    switch (e.code) {
      case 'not-found':
        return const WarehouseNotFoundException();
      case 'unavailable':
      case 'deadline-exceeded':
        return const TimeoutException();
      case 'permission-denied':
        return ServerException(
          'Akses ditolak: ${e.message ?? e.code}',
        );
      default:
        return ServerException(
          'FirebaseException(${e.code}): ${e.message ?? 'unknown error'}',
        );
    }
  }

  /// Haversine great-circle distance in kilometres between two points.
  ///
  /// Accurate to within ~0.5% for typical inter-city distances on Earth.
  static double _haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0088;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _deg2rad(double deg) => deg * math.pi / 180.0;
}

/// Internal helper bundling a warehouse with its computed distance so we
/// can sort by distance without recomputing Haversine repeatedly.
class _ScoredWarehouse {
  final WarehouseModel warehouse;
  final double distanceKm;
  const _ScoredWarehouse(this.warehouse, this.distanceKm);
}

// ---------------------------------------------------------------------------
// WarehouseModel helper extension — keep transaction logic self-contained.
// ---------------------------------------------------------------------------

extension _WarehouseModelCopy on WarehouseModel {
  WarehouseModel copyWithModel({
    double? remainingCapacity,
    DateTime? updatedAt,
  }) {
    return WarehouseModel(
      id: id,
      mitraId: mitraId,
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
      totalCapacity: totalCapacity,
      remainingCapacity: remainingCapacity ?? this.remainingCapacity,
      pricePerM3PerDay: pricePerM3PerDay,
      temperatureCategory: temperatureCategory,
      temperatureThreshold: temperatureThreshold,
      photoUrls: photoUrls,
      isActive: isActive,
      iotNodeId: iotNodeId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
