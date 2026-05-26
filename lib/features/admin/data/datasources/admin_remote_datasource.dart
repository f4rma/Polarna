import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firebase_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../domain/entities/platform_summary.dart';

/// Remote admin operations backed by Cloud Firestore.
///
/// All methods throw [AppException] subclasses on failure; the repository
/// layer converts those into [Failure] objects for the domain layer.
abstract class AdminRemoteDataSource {
  /// Sets `isActive: true` on the user document identified by [userId].
  Future<void> activateUser(String userId);

  /// Sets `isActive: false` on the user document identified by [userId].
  ///
  /// If the user's role is `mitra`, all warehouses with
  /// `mitraId == userId` are also batch-updated to `isActive: false`
  /// (cascade deactivation — Requirement 10.5).
  Future<void> deactivateUser(String userId);

  /// Aggregates platform-wide metrics: total users, active warehouses,
  /// active bookings, and total revenue (sum of `totalCost`).
  Future<PlatformSummary> getPlatformSummary();

  /// Fetches all user documents from the `users` collection.
  Future<List<UserModel>> getAllUsers();
}

/// Concrete [AdminRemoteDataSource] implementation using Cloud Firestore.
class AdminRemoteDataSourceImpl implements AdminRemoteDataSource {
  final FirebaseFirestore _firestore;

  const AdminRemoteDataSourceImpl({
    required FirebaseFirestore firestore,
  }) : _firestore = firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(FirebaseConstants.usersCollection);

  CollectionReference<Map<String, dynamic>> get _warehouses =>
      _firestore.collection(FirebaseConstants.warehousesCollection);

  CollectionReference<Map<String, dynamic>> get _bookings =>
      _firestore.collection(FirebaseConstants.bookingsCollection);

  // ---------------------------------------------------------------------------
  // User activation / deactivation
  // ---------------------------------------------------------------------------

  @override
  Future<void> activateUser(String userId) async {
    try {
      await _users.doc(userId).update({
        FirebaseConstants.fieldIsActive: true,
      });
    } on FirebaseException catch (e) {
      throw ServerException('Firestore error: ${e.message ?? e.code}');
    }
  }

  @override
  Future<void> deactivateUser(String userId) async {
    try {
      // 1. Read user doc to check role.
      final userSnap = await _users.doc(userId).get();
      if (!userSnap.exists) {
        throw const ServerException('Pengguna tidak ditemukan');
      }

      final data = userSnap.data()!;
      final role = data[FirebaseConstants.fieldRole] as String?;

      // 2. Set user isActive = false.
      final batch = _firestore.batch();
      batch.update(_users.doc(userId), {
        FirebaseConstants.fieldIsActive: false,
      });

      // 3. If role == 'mitra', cascade deactivate all their warehouses.
      if (role == UserRole.mitra.toStorageString()) {
        final warehouseQuery = await _warehouses
            .where(FirebaseConstants.fieldMitraId, isEqualTo: userId)
            .get();

        for (final doc in warehouseQuery.docs) {
          batch.update(doc.reference, {
            FirebaseConstants.fieldIsActiveWarehouse: false,
          });
        }
      }

      // Commit atomically.
      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException('Firestore error: ${e.message ?? e.code}');
    }
  }

  // ---------------------------------------------------------------------------
  // Platform summary
  // ---------------------------------------------------------------------------

  @override
  Future<PlatformSummary> getPlatformSummary() async {
    try {
      // Run queries in parallel for efficiency.
      final results = await Future.wait([
        _users.get(),
        _warehouses
            .where(FirebaseConstants.fieldIsActiveWarehouse, isEqualTo: true)
            .get(),
        _bookings
            .where(FirebaseConstants.fieldStatus, isEqualTo: 'active')
            .get(),
        _bookings.get(),
      ]);

      final usersSnap = results[0];
      final activeWarehousesSnap = results[1];
      final activeBookingsSnap = results[2];
      final allBookingsSnap = results[3];

      // Sum totalCost across all bookings for total revenue.
      double totalRevenue = 0;
      for (final doc in allBookingsSnap.docs) {
        final cost = doc.data()[FirebaseConstants.fieldTotalCost];
        if (cost is num) {
          totalRevenue += cost.toDouble();
        }
      }

      return PlatformSummary(
        totalUsers: usersSnap.size,
        activeWarehouses: activeWarehousesSnap.size,
        activeTransactions: activeBookingsSnap.size,
        grossMerchandiseValue: totalRevenue,
      );
    } on FirebaseException catch (e) {
      throw ServerException('Firestore error: ${e.message ?? e.code}');
    }
  }

  // ---------------------------------------------------------------------------
  // User listing
  // ---------------------------------------------------------------------------

  @override
  Future<List<UserModel>> getAllUsers() async {
    try {
      final snapshot = await _users.get();
      return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    } on FirebaseException catch (e) {
      throw ServerException('Firestore error: ${e.message ?? e.code}');
    }
  }
}
