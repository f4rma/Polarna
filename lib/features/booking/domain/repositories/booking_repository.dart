import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/booking_entity.dart';

/// Abstract data contract between the booking domain and data layers.
///
/// Implementations live in `data/repositories/booking_repository_impl.dart`
/// and translate domain entities to/from Firestore models. The data layer
/// is responsible for enforcing cross-aggregate invariants (e.g. atomically
/// decrementing `warehouses.remainingCapacity` when a booking is created —
/// Requirement 4.5a).
abstract class BookingRepository {
  /// Persists a new booking record.
  ///
  /// Implementations MUST:
  /// - Assign a generated id (data layer may overwrite [BookingEntity.id]).
  /// - Atomically decrement `warehouses/{warehouseId}.remainingCapacity`
  ///   by [BookingEntity.volumeM3] in the same transaction (Requirement
  ///   4.5a). Failure to do so SHALL result in the booking being rolled
  ///   back and the capacity unchanged.
  Future<Either<Failure, BookingEntity>> createBooking(BookingEntity booking);

  /// Returns the full booking history for a given UMKM (Requirement 4.8).
  Future<Either<Failure, List<BookingEntity>>> getHistoryForUmkm(
    String umkmId,
  );

  /// Returns the full booking history for a given Mitra — every booking
  /// made AT any of the Mitra's warehouses, newest first.
  ///
  /// Implementations resolve the Mitra's warehouses first, then aggregate
  /// matching bookings.
  Future<Either<Failure, List<BookingEntity>>> getHistoryForMitra(
    String mitraId,
  );

  /// Returns bookings that are currently `active` for a given warehouse.
  /// Used by Mitra dashboards (Requirement 8.4).
  Future<Either<Failure, List<BookingEntity>>> getActiveForWarehouse(
    String warehouseId,
  );

  /// Fetches a single booking by its document id.
  Future<Either<Failure, BookingEntity>> getById(String id);

  /// Live updates for a single booking — primarily used by the QR code
  /// / confirmation pages and the active-booking monitoring flow.
  Stream<BookingEntity> watchById(String id);

  /// Updates the payment status of a booking (e.g. after Payment_Gateway
  /// confirms capture or issues a refund).
  Future<Either<Failure, BookingEntity>> updatePaymentStatus({
    required String bookingId,
    required PaymentStatus status,
  });

  /// Transitions a booking to `cancelled` state.
  ///
  /// Implementations MUST return capacity to the warehouse if the booking
  /// was previously `active` (Requirement 4.6).
  Future<Either<Failure, BookingEntity>> cancelBooking({
    required String bookingId,
  });

  /// Transitions a booking to `completed` state.
  ///
  /// Implementations MUST atomically return the booked volume to
  /// `warehouses/{warehouseId}.remainingCapacity` (Requirement 8.5).
  Future<Either<Failure, BookingEntity>> completeBooking({
    required String bookingId,
  });

  /// Mitra scans UMKM QR to confirm goods arrived (paid → active).
  Future<Either<Failure, BookingEntity>> checkInBooking({
    required String bookingId,
    required String qrCode,
  });

  /// Mitra scans UMKM QR to confirm goods picked up (active → completed).
  /// Restores warehouse capacity atomically.
  Future<Either<Failure, BookingEntity>> checkOutBooking({
    required String bookingId,
    required String qrCode,
  });
}
