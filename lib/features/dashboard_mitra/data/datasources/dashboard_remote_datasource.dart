import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/firebase_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../booking/data/models/booking_model.dart';
import '../../../booking/domain/entities/booking_entity.dart';
import '../../domain/entities/revenue_summary.dart';

/// Remote data source for the Mitra dashboard.
///
/// Aggregates revenue, active transactions, and utilization from Firestore.
/// Also implements client-side auto-complete for expired bookings.
abstract class DashboardRemoteDataSource {
  /// Fetches an aggregated [RevenueSummary] for the given Mitra.
  ///
  /// Steps:
  /// 1. Query warehouses owned by [mitraId] to get warehouse IDs and capacities.
  /// 2. Query bookings for those warehouses to compute revenue and counts.
  /// 3. Compute utilization = (totalCapacity - remainingCapacity) / totalCapacity × 100.
  Future<RevenueSummary> getRevenueSummary(String mitraId);

  /// Returns all bookings with status `active` for the given Mitra's warehouses.
  Future<List<BookingModel>> getActiveTransactions(String mitraId);

  /// Returns all transactions for the given Mitra, optionally filtered by date range.
  Future<List<BookingModel>> getAllTransactions({
    required String mitraId,
    DateTime? from,
    DateTime? to,
  });

  /// Auto-completes expired bookings: when endDate has passed and status is
  /// still active, transitions to completed and restores warehouse capacity.
  ///
  /// This is a simplified client-side implementation (single attempt).
  /// The real retry logic (3×, 30s interval) lives in Cloud Functions.
  Future<void> autoCompleteExpiredBookings(String mitraId);
}

/// Firestore-backed implementation of [DashboardRemoteDataSource].
class DashboardRemoteDataSourceImpl implements DashboardRemoteDataSource {
  final FirebaseFirestore _firestore;

  DashboardRemoteDataSourceImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  CollectionReference<Map<String, dynamic>> get _warehouses =>
      _firestore.collection(FirebaseConstants.warehousesCollection);

  CollectionReference<Map<String, dynamic>> get _bookings =>
      _firestore.collection(FirebaseConstants.bookingsCollection);

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  @override
  Future<RevenueSummary> getRevenueSummary(String mitraId) async {
    try {
      // 1. Get all warehouses owned by this mitra.
      final warehouseSnap = await _warehouses
          .where(FirebaseConstants.fieldMitraId, isEqualTo: mitraId)
          .get();

      if (warehouseSnap.docs.isEmpty) {
        return const RevenueSummary(
          dailyRevenue: 0,
          monthlyRevenue: 0,
          activeTransactions: 0,
          utilizationPercent: 0,
          monthlyRevenueHistory: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        );
      }

      final warehouseIds =
          warehouseSnap.docs.map((doc) => doc.id).toList();

      // Compute utilization from warehouse capacities.
      double totalCapacity = 0;
      double remainingCapacity = 0;
      for (final doc in warehouseSnap.docs) {
        final data = doc.data();
        totalCapacity +=
            (data[FirebaseConstants.fieldTotalCapacity] as num).toDouble();
        remainingCapacity +=
            (data[FirebaseConstants.fieldRemainingCapacity] as num).toDouble();
      }

      final utilizationPercent = totalCapacity > 0
          ? ((totalCapacity - remainingCapacity) / totalCapacity) * 100
          : 0.0;

      // 2. Query bookings for these warehouses.
      // Firestore `whereIn` supports max 30 items; chunk if needed.
      final allBookings = await _fetchBookingsForWarehouses(warehouseIds);

      // 3. Aggregate revenue.
      final now = DateTime.now().toUtc();
      final todayStart = DateTime.utc(now.year, now.month, now.day);
      final monthStart = DateTime.utc(now.year, now.month, 1);

      double dailyRevenue = 0;
      double monthlyRevenue = 0;
      int activeTransactions = 0;
      // Net rate after platform commission (Mitra menerima 90% dari totalCost).
      const netRate = 1 - AppConstants.commissionRate;

      for (final booking in allBookings) {
        if (booking.status == BookingStatus.active) {
          activeTransactions++;
        }

        // Only count paid/completed bookings for revenue.
        if (booking.status == BookingStatus.active ||
            booking.status == BookingStatus.completed) {
          final netRevenue = booking.totalCost * netRate;
          if (!booking.createdAt.isBefore(todayStart)) {
            dailyRevenue += netRevenue;
          }
          if (!booking.createdAt.isBefore(monthStart)) {
            monthlyRevenue += netRevenue;
          }
        }
      }

      // 4. Build monthly revenue history (last 12 months).
      final monthlyRevenueHistory = _computeMonthlyHistory(allBookings, now);

      return RevenueSummary(
        dailyRevenue: dailyRevenue,
        monthlyRevenue: monthlyRevenue,
        activeTransactions: activeTransactions,
        utilizationPercent: utilizationPercent,
        monthlyRevenueHistory: monthlyRevenueHistory,
      );
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    }
  }

  @override
  Future<List<BookingModel>> getActiveTransactions(String mitraId) async {
    try {
      final warehouseIds = await _getWarehouseIds(mitraId);
      if (warehouseIds.isEmpty) return [];

      final List<BookingModel> results = [];
      final chunks = _chunk(warehouseIds, 30);

      for (final chunk in chunks) {
        final snap = await _bookings
            .where(FirebaseConstants.fieldWarehouseId, whereIn: chunk)
            .where(
              FirebaseConstants.fieldStatus,
              isEqualTo: BookingStatus.active.toStorageString(),
            )
            .get();
        results.addAll(snap.docs.map(BookingModel.fromFirestore));
      }

      return results;
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    }
  }

  @override
  Future<List<BookingModel>> getAllTransactions({
    required String mitraId,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final warehouseIds = await _getWarehouseIds(mitraId);
      if (warehouseIds.isEmpty) return [];

      final List<BookingModel> results = [];
      final chunks = _chunk(warehouseIds, 30);

      for (final chunk in chunks) {
        Query<Map<String, dynamic>> query =
            _bookings.where(FirebaseConstants.fieldWarehouseId, whereIn: chunk);

        if (from != null) {
          query = query.where(
            FirebaseConstants.fieldCreatedAt,
            isGreaterThanOrEqualTo: Timestamp.fromDate(from),
          );
        }
        if (to != null) {
          query = query.where(
            FirebaseConstants.fieldCreatedAt,
            isLessThanOrEqualTo: Timestamp.fromDate(to),
          );
        }

        final snap = await query
            .orderBy(FirebaseConstants.fieldCreatedAt, descending: true)
            .get();
        results.addAll(snap.docs.map(BookingModel.fromFirestore));
      }

      return results;
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    }
  }

  @override
  Future<void> autoCompleteExpiredBookings(String mitraId) async {
    try {
      final warehouseIds = await _getWarehouseIds(mitraId);
      if (warehouseIds.isEmpty) return;

      final now = DateTime.now().toUtc();
      final chunks = _chunk(warehouseIds, 30);

      for (final chunk in chunks) {
        final snap = await _bookings
            .where(FirebaseConstants.fieldWarehouseId, whereIn: chunk)
            .where(
              FirebaseConstants.fieldStatus,
              isEqualTo: BookingStatus.active.toStorageString(),
            )
            .get();

        for (final doc in snap.docs) {
          final booking = BookingModel.fromFirestore(doc);

          // If endDate has passed, auto-complete.
          if (booking.endDate.isBefore(now)) {
            await _completeBookingTransaction(booking);
          }
        }
      }
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Fetches warehouse IDs owned by [mitraId].
  Future<List<String>> _getWarehouseIds(String mitraId) async {
    final snap = await _warehouses
        .where(FirebaseConstants.fieldMitraId, isEqualTo: mitraId)
        .get();
    return snap.docs.map((doc) => doc.id).toList();
  }

  /// Fetches all bookings for the given warehouse IDs (handles chunking).
  Future<List<BookingModel>> _fetchBookingsForWarehouses(
    List<String> warehouseIds,
  ) async {
    final List<BookingModel> results = [];
    final chunks = _chunk(warehouseIds, 30);

    for (final chunk in chunks) {
      final snap = await _bookings
          .where(FirebaseConstants.fieldWarehouseId, whereIn: chunk)
          .get();
      results.addAll(snap.docs.map(BookingModel.fromFirestore));
    }

    return results;
  }

  /// Atomically completes a booking and restores warehouse capacity.
  Future<void> _completeBookingTransaction(BookingModel booking) async {
    await _firestore.runTransaction((txn) async {
      final bookingRef = _bookings.doc(booking.id);
      final warehouseRef = _warehouses.doc(booking.warehouseId);

      final warehouseSnap = await txn.get(warehouseRef);
      if (warehouseSnap.exists) {
        final warehouseData = warehouseSnap.data()!;
        final remaining =
            (warehouseData[FirebaseConstants.fieldRemainingCapacity] as num)
                .toDouble();

        txn.update(warehouseRef, {
          FirebaseConstants.fieldRemainingCapacity:
              remaining + booking.volumeM3,
          FirebaseConstants.fieldUpdatedAt: FieldValue.serverTimestamp(),
        });
      }

      txn.update(bookingRef, {
        FirebaseConstants.fieldStatus:
            BookingStatus.completed.toStorageString(),
        FirebaseConstants.fieldUpdatedAt: FieldValue.serverTimestamp(),
      });
    });
  }

  /// Computes monthly revenue for the last 12 months (oldest first).
  List<double> _computeMonthlyHistory(
    List<BookingModel> bookings,
    DateTime now,
  ) {
    final history = List<double>.filled(12, 0);
    const netRate = 1 - AppConstants.commissionRate;

    for (final booking in bookings) {
      if (booking.status != BookingStatus.active &&
          booking.status != BookingStatus.completed) {
        continue;
      }

      final monthsAgo =
          (now.year - booking.createdAt.year) * 12 +
          (now.month - booking.createdAt.month);

      if (monthsAgo >= 0 && monthsAgo < 12) {
        // Index 11 = current month, 0 = 11 months ago.
        history[11 - monthsAgo] += booking.totalCost * netRate;
      }
    }

    return history;
  }

  /// Splits a list into chunks of [size].
  List<List<T>> _chunk<T>(List<T> list, int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < list.length; i += size) {
      final end = (i + size < list.length) ? i + size : list.length;
      chunks.add(list.sublist(i, end));
    }
    return chunks;
  }

  /// Converts a Firestore exception into a typed [AppException].
  AppException _mapFirebaseException(FirebaseException e) {
    switch (e.code) {
      case 'not-found':
        return const ServerException('Dokumen tidak ditemukan');
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
