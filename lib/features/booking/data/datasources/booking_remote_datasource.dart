import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/firebase_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/booking_entity.dart';
import '../models/booking_model.dart';

/// Remote booking operations backed by Cloud Firestore.
///
/// All methods throw [AppException] subclasses on failure; the repository
/// layer is responsible for converting those into [Failure] objects.
abstract class BookingRemoteDataSource {
  /// Creates a new booking atomically:
  /// 1. Reads warehouse doc to verify remaining capacity.
  /// 2. Decrements `remainingCapacity` by the booked volume.
  /// 3. Creates the booking document with status=active, paymentStatus=paid.
  /// 4. Generates a UUID-based QR code data string.
  ///
  /// Throws [InsufficientCapacityException] when volume > remainingCapacity.
  Future<BookingModel> createBooking(BookingEntity booking);

  /// Returns all bookings for a given UMKM, ordered by createdAt descending.
  Future<List<BookingModel>> getHistoryForUmkm(String umkmId);

  /// Returns all bookings made AT warehouses owned by the given Mitra,
  /// ordered by createdAt descending.
  ///
  /// Implementation looks up the Mitra's warehouses first, then fetches
  /// bookings whose `warehouseId` falls into one of those ids. Uses
  /// chunked `whereIn` queries so the result is not capped by Firestore's
  /// 10/30-element limit.
  Future<List<BookingModel>> getHistoryForMitra(String mitraId);

  /// Returns active bookings for a given warehouse.
  Future<List<BookingModel>> getActiveForWarehouse(String warehouseId);

  /// Fetches a single booking by its document id.
  Future<BookingModel> getById(String id);

  /// Live updates for a single booking document.
  Stream<BookingModel> watchById(String id);

  /// Updates the payment status of a booking.
  Future<BookingModel> updatePaymentStatus({
    required String bookingId,
    required PaymentStatus status,
  });

  /// Transitions a booking to `cancelled` state.
  /// If the booking was active, restores capacity to the warehouse.
  Future<BookingModel> cancelBooking(String bookingId);

  /// Transitions a booking to `completed` state.
  /// Atomically restores the booked volume to the warehouse's
  /// `remainingCapacity` (Requirement 8.5).
  Future<BookingModel> completeBooking(String bookingId);

  /// Mitra scans UMKM QR code to confirm goods arrived. paid → active.
  /// Throws [ServerException] if booking not found, status not `paid`,
  /// or QR code doesn't match.
  Future<BookingModel> checkInBooking({
    required String bookingId,
    required String qrCode,
  });

  /// Mitra scans UMKM QR code to confirm goods picked up. active → completed.
  /// Atomically restores warehouse capacity.
  /// Throws [ServerException] if booking not found, status not `active`,
  /// or QR code doesn't match.
  Future<BookingModel> checkOutBooking({
    required String bookingId,
    required String qrCode,
  });
}

class BookingRemoteDataSourceImpl implements BookingRemoteDataSource {
  final FirebaseFirestore _firestore;
  final Uuid _uuid;

  BookingRemoteDataSourceImpl({
    required FirebaseFirestore firestore,
    Uuid? uuid,
  })  : _firestore = firestore,
        _uuid = uuid ?? const Uuid();

  CollectionReference<Map<String, dynamic>> get _bookings =>
      _firestore.collection(FirebaseConstants.bookingsCollection);

  CollectionReference<Map<String, dynamic>> get _warehouses =>
      _firestore.collection(FirebaseConstants.warehousesCollection);

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  @override
  Future<BookingModel> createBooking(BookingEntity booking) async {
    try {
      final result = await _firestore.runTransaction<BookingModel>(
        (txn) async {
          // 1. Read warehouse doc inside transaction.
          final warehouseRef = _warehouses.doc(booking.warehouseId);
          final warehouseSnap = await txn.get(warehouseRef);

          if (!warehouseSnap.exists) {
            throw const ServerException('Gudang tidak ditemukan');
          }

          final warehouseData = warehouseSnap.data()!;
          final remainingCapacity =
              (warehouseData[FirebaseConstants.fieldRemainingCapacity] as num)
                  .toDouble();

          // 2. Check capacity.
          if (remainingCapacity < booking.volumeM3) {
            throw InsufficientCapacityException(
              remainingCapacity: remainingCapacity,
            );
          }

          // 3. Prepare booking document.
          final bookingRef = _bookings.doc();
          final qrCode = _uuid.v4();
          final now = DateTime.now().toUtc();

          final model = BookingModel(
            id: bookingRef.id,
            umkmId: booking.umkmId,
            warehouseId: booking.warehouseId,
            warehouseName: booking.warehouseName,
            volumeM3: booking.volumeM3,
            startDate: booking.startDate,
            endDate: booking.endDate,
            durationDays: booking.durationDays,
            pricePerM3PerDay: booking.pricePerM3PerDay,
            totalCost: booking.totalCost,
            status: BookingStatus.paid,
            paymentStatus: PaymentStatus.paid,
            qrCodeData: qrCode,
            createdAt: now,
            updatedAt: now,
          );

          final payload = model.toFirestore()
            ..[FirebaseConstants.fieldCreatedAt] = FieldValue.serverTimestamp()
            ..[FirebaseConstants.fieldUpdatedAt] = FieldValue.serverTimestamp();

          // 4. Atomically decrement warehouse capacity.
          txn.update(warehouseRef, {
            FirebaseConstants.fieldRemainingCapacity:
                remainingCapacity - booking.volumeM3,
            FirebaseConstants.fieldUpdatedAt: FieldValue.serverTimestamp(),
          });

          // 5. Create booking document.
          txn.set(bookingRef, payload);

          return model;
        },
      );
      return result;
    } on InsufficientCapacityException {
      rethrow;
    } on ServerException {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    }
  }

  @override
  Future<BookingModel> cancelBooking(String bookingId) async {
    try {
      final result = await _firestore.runTransaction<BookingModel>(
        (txn) async {
          final bookingRef = _bookings.doc(bookingId);
          final bookingSnap = await txn.get(bookingRef);

          if (!bookingSnap.exists) {
            throw const ServerException('Booking tidak ditemukan');
          }

          final current = BookingModel.fromFirestore(bookingSnap);

          // If booking was active, restore capacity to warehouse.
          if (current.status == BookingStatus.active) {
            final warehouseRef = _warehouses.doc(current.warehouseId);
            final warehouseSnap = await txn.get(warehouseRef);

            if (warehouseSnap.exists) {
              final warehouseData = warehouseSnap.data()!;
              final remainingCapacity =
                  (warehouseData[FirebaseConstants.fieldRemainingCapacity]
                          as num)
                      .toDouble();

              txn.update(warehouseRef, {
                FirebaseConstants.fieldRemainingCapacity:
                    remainingCapacity + current.volumeM3,
                FirebaseConstants.fieldUpdatedAt: FieldValue.serverTimestamp(),
              });
            }
          }

          txn.update(bookingRef, {
            FirebaseConstants.fieldStatus:
                BookingStatus.cancelled.toStorageString(),
            FirebaseConstants.fieldUpdatedAt: FieldValue.serverTimestamp(),
          });

          return BookingModel(
            id: current.id,
            umkmId: current.umkmId,
            warehouseId: current.warehouseId,
            warehouseName: current.warehouseName,
            volumeM3: current.volumeM3,
            startDate: current.startDate,
            endDate: current.endDate,
            durationDays: current.durationDays,
            pricePerM3PerDay: current.pricePerM3PerDay,
            totalCost: current.totalCost,
            status: BookingStatus.cancelled,
            paymentStatus: current.paymentStatus,
            qrCodeData: current.qrCodeData,
            createdAt: current.createdAt,
            updatedAt: DateTime.now().toUtc(),
          );
        },
      );
      return result;
    } on ServerException {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    }
  }

  @override
  Future<BookingModel> completeBooking(String bookingId) async {
    try {
      final result = await _firestore.runTransaction<BookingModel>(
        (txn) async {
          final bookingRef = _bookings.doc(bookingId);
          final bookingSnap = await txn.get(bookingRef);

          if (!bookingSnap.exists) {
            throw const ServerException('Booking tidak ditemukan');
          }

          final current = BookingModel.fromFirestore(bookingSnap);

          // Restore capacity to warehouse (Requirement 8.5).
          final warehouseRef = _warehouses.doc(current.warehouseId);
          final warehouseSnap = await txn.get(warehouseRef);

          if (warehouseSnap.exists) {
            final warehouseData = warehouseSnap.data()!;
            final remainingCapacity =
                (warehouseData[FirebaseConstants.fieldRemainingCapacity] as num)
                    .toDouble();

            txn.update(warehouseRef, {
              FirebaseConstants.fieldRemainingCapacity:
                  remainingCapacity + current.volumeM3,
              FirebaseConstants.fieldUpdatedAt: FieldValue.serverTimestamp(),
            });
          }

          txn.update(bookingRef, {
            FirebaseConstants.fieldStatus:
                BookingStatus.completed.toStorageString(),
            FirebaseConstants.fieldUpdatedAt: FieldValue.serverTimestamp(),
          });

          return BookingModel(
            id: current.id,
            umkmId: current.umkmId,
            warehouseId: current.warehouseId,
            warehouseName: current.warehouseName,
            volumeM3: current.volumeM3,
            startDate: current.startDate,
            endDate: current.endDate,
            durationDays: current.durationDays,
            pricePerM3PerDay: current.pricePerM3PerDay,
            totalCost: current.totalCost,
            status: BookingStatus.completed,
            paymentStatus: current.paymentStatus,
            qrCodeData: current.qrCodeData,
            createdAt: current.createdAt,
            updatedAt: DateTime.now().toUtc(),
          );
        },
      );
      return result;
    } on ServerException {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    }
  }

  @override
  Future<BookingModel> updatePaymentStatus({
    required String bookingId,
    required PaymentStatus status,
  }) async {
    try {
      final docRef = _bookings.doc(bookingId);
      await docRef.update({
        FirebaseConstants.fieldPaymentStatus: status.toStorageString(),
        FirebaseConstants.fieldUpdatedAt: FieldValue.serverTimestamp(),
      });
      final snap = await docRef.get();
      return BookingModel.fromFirestore(snap);
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    }
  }

  @override
  Future<BookingModel> checkInBooking({
    required String bookingId,
    required String qrCode,
  }) async {
    try {
      final result = await _firestore.runTransaction<BookingModel>(
        (txn) async {
          final bookingRef = _bookings.doc(bookingId);
          final bookingSnap = await txn.get(bookingRef);

          if (!bookingSnap.exists) {
            throw const ServerException('Booking tidak ditemukan');
          }

          final current = BookingModel.fromFirestore(bookingSnap);

          if (current.status != BookingStatus.paid) {
            throw const ServerException(
              'Booking sudah check-in atau status tidak valid',
            );
          }

          if (current.qrCodeData != qrCode) {
            throw const ServerException('QR Code tidak cocok');
          }

          txn.update(bookingRef, {
            FirebaseConstants.fieldStatus:
                BookingStatus.active.toStorageString(),
            FirebaseConstants.fieldUpdatedAt: FieldValue.serverTimestamp(),
          });

          return BookingModel(
            id: current.id,
            umkmId: current.umkmId,
            warehouseId: current.warehouseId,
            warehouseName: current.warehouseName,
            volumeM3: current.volumeM3,
            startDate: current.startDate,
            endDate: current.endDate,
            durationDays: current.durationDays,
            pricePerM3PerDay: current.pricePerM3PerDay,
            totalCost: current.totalCost,
            status: BookingStatus.active,
            paymentStatus: current.paymentStatus,
            qrCodeData: current.qrCodeData,
            createdAt: current.createdAt,
            updatedAt: DateTime.now().toUtc(),
          );
        },
      );
      return result;
    } on ServerException {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    }
  }

  @override
  Future<BookingModel> checkOutBooking({
    required String bookingId,
    required String qrCode,
  }) async {
    try {
      final result = await _firestore.runTransaction<BookingModel>(
        (txn) async {
          final bookingRef = _bookings.doc(bookingId);
          final bookingSnap = await txn.get(bookingRef);

          if (!bookingSnap.exists) {
            throw const ServerException('Booking tidak ditemukan');
          }

          final current = BookingModel.fromFirestore(bookingSnap);

          if (current.status != BookingStatus.active) {
            throw const ServerException(
              'Booking belum check-in atau sudah selesai',
            );
          }

          if (current.qrCodeData != qrCode) {
            throw const ServerException('QR Code tidak cocok');
          }

          // Restore warehouse capacity
          final warehouseRef = _warehouses.doc(current.warehouseId);
          final warehouseSnap = await txn.get(warehouseRef);

          if (warehouseSnap.exists) {
            final warehouseData = warehouseSnap.data()!;
            final remainingCapacity =
                (warehouseData[FirebaseConstants.fieldRemainingCapacity] as num)
                    .toDouble();

            txn.update(warehouseRef, {
              FirebaseConstants.fieldRemainingCapacity:
                  remainingCapacity + current.volumeM3,
              FirebaseConstants.fieldUpdatedAt: FieldValue.serverTimestamp(),
            });
          }

          txn.update(bookingRef, {
            FirebaseConstants.fieldStatus:
                BookingStatus.completed.toStorageString(),
            FirebaseConstants.fieldUpdatedAt: FieldValue.serverTimestamp(),
          });

          return BookingModel(
            id: current.id,
            umkmId: current.umkmId,
            warehouseId: current.warehouseId,
            warehouseName: current.warehouseName,
            volumeM3: current.volumeM3,
            startDate: current.startDate,
            endDate: current.endDate,
            durationDays: current.durationDays,
            pricePerM3PerDay: current.pricePerM3PerDay,
            totalCost: current.totalCost,
            status: BookingStatus.completed,
            paymentStatus: current.paymentStatus,
            qrCodeData: current.qrCodeData,
            createdAt: current.createdAt,
            updatedAt: DateTime.now().toUtc(),
          );
        },
      );
      return result;
    } on ServerException {
      rethrow;
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  @override
  Future<BookingModel> getById(String id) async {
    try {
      final snap = await _bookings.doc(id).get();
      if (!snap.exists) {
        throw const ServerException('Booking tidak ditemukan');
      }
      return BookingModel.fromFirestore(snap);
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    }
  }

  @override
  Future<List<BookingModel>> getHistoryForUmkm(String umkmId) async {
    try {
      final snap = await _bookings
          .where(FirebaseConstants.fieldUmkmId, isEqualTo: umkmId)
          .get();
      final results = snap.docs.map(BookingModel.fromFirestore).toList();
      // Sort client-side to avoid requiring a composite Firestore index.
      results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return results;
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    }
  }

  @override
  Future<List<BookingModel>> getHistoryForMitra(String mitraId) async {
    try {
      // 1. Look up all warehouses owned by this mitra.
      final warehousesSnap = await _warehouses
          .where(FirebaseConstants.fieldMitraId, isEqualTo: mitraId)
          .get();
      final warehouseIds = warehousesSnap.docs.map((d) => d.id).toList();

      if (warehouseIds.isEmpty) return <BookingModel>[];

      // 2. Fetch bookings for those warehouses.
      // Firestore `whereIn` accepts at most 10 values per query, so we
      // chunk and merge the results.
      final allBookings = <BookingModel>[];
      for (var i = 0; i < warehouseIds.length; i += 10) {
        final chunk = warehouseIds.skip(i).take(10).toList();
        final bookingsSnap = await _bookings
            .where(FirebaseConstants.fieldWarehouseId, whereIn: chunk)
            .get();
        allBookings.addAll(bookingsSnap.docs.map(BookingModel.fromFirestore));
      }

      // Sort client-side (newest first) — same convention as the UMKM path.
      allBookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return allBookings;
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    }
  }

  @override
  Future<List<BookingModel>> getActiveForWarehouse(String warehouseId) async {
    try {
      final snap = await _bookings
          .where(FirebaseConstants.fieldWarehouseId, isEqualTo: warehouseId)
          .where(
            FirebaseConstants.fieldStatus,
            isEqualTo: BookingStatus.active.toStorageString(),
          )
          .get();
      return snap.docs.map(BookingModel.fromFirestore).toList();
    } on FirebaseException catch (e) {
      throw _mapFirebaseException(e);
    }
  }

  @override
  Stream<BookingModel> watchById(String id) {
    return _bookings.doc(id).snapshots().map((snap) {
      if (!snap.exists) {
        throw const ServerException('Booking tidak ditemukan');
      }
      return BookingModel.fromFirestore(snap);
    }).handleError((Object err) {
      if (err is AppException) throw err;
      if (err is FirebaseException) throw _mapFirebaseException(err);
      throw ServerException(err.toString());
    });
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

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
