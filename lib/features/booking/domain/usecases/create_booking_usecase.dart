import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/booking_entity.dart';
import '../repositories/booking_repository.dart';

/// Parameters for [CreateBookingUseCase].
///
/// [remainingCapacity] is a snapshot of the warehouse's sisa kapasitas at
/// the time of form submission. Passing it explicitly lets the use case
/// reject obviously-invalid bookings at the domain level (Requirement 4.3)
/// without needing to re-read the warehouse doc. The data layer is still
/// responsible for the atomic capacity decrement (Requirement 4.5a) since
/// the snapshot may be stale by the time the write actually runs.
class CreateBookingParams extends Equatable {
  final String umkmId;
  final String warehouseId;
  final String warehouseName;
  final double volumeM3;
  final double pricePerM3PerDay;
  final DateTime startDate;
  final int durationDays;
  final double remainingCapacity;

  const CreateBookingParams({
    required this.umkmId,
    required this.warehouseId,
    required this.warehouseName,
    required this.volumeM3,
    required this.pricePerM3PerDay,
    required this.startDate,
    required this.durationDays,
    required this.remainingCapacity,
  });

  @override
  List<Object?> get props => [
        umkmId,
        warehouseId,
        warehouseName,
        volumeM3,
        pricePerM3PerDay,
        startDate,
        durationDays,
        remainingCapacity,
      ];
}

/// Orchestrates creation of a new booking.
///
/// Responsibilities:
/// 1. Enforce the domain invariant `volumeM3 <= remainingCapacity`
///    (Requirement 4.3) — field-level range validation (kelipatan 0,5;
///    durasi 1–365 hari; dll.) is done by the presentation layer.
/// 2. Reject past [CreateBookingParams.startDate] values normalized to
///    UTC-midnight, so that timezone edge-cases around midnight do not
///    spuriously accept yesterday's date (Requirement 4.10).
/// 3. Compute the derived fields (`endDate`, `totalCost`) using the same
///    formula as [CalculateCostUseCase] (Requirement 4.2).
/// 4. Delegate persistence to [BookingRepository], which performs the
///    atomic capacity decrement in the data layer (Requirement 4.5a).
class CreateBookingUseCase {
  final BookingRepository repository;

  const CreateBookingUseCase(this.repository);

  Future<Either<Failure, BookingEntity>> call(CreateBookingParams params) {
    // Capacity invariant (Requirement 4.3).
    if (params.volumeM3 > params.remainingCapacity) {
      return Future.value(
        Left(InsufficientCapacityFailure(
          remainingCapacity: params.remainingCapacity,
        )),
      );
    }

    // Past-date invariant (Requirement 4.10).
    //
    // Normalize both "now" and the supplied [startDate] to UTC-midnight so
    // that a booking starting later today is not rejected by an ordinary
    // wall-clock comparison, and yesterday in any timezone is still
    // considered in the past.
    final now = DateTime.now().toUtc();
    final todayUtc = DateTime.utc(now.year, now.month, now.day);
    final startUtc = params.startDate.toUtc();
    final startDayUtc =
        DateTime.utc(startUtc.year, startUtc.month, startUtc.day);
    if (startDayUtc.isBefore(todayUtc)) {
      return Future.value(const Left(InvalidDateFailure()));
    }

    final endDate = params.startDate.add(Duration(days: params.durationDays));
    final totalCost =
        params.volumeM3 * params.pricePerM3PerDay * params.durationDays;

    final entity = BookingEntity(
      id: '',
      umkmId: params.umkmId,
      warehouseId: params.warehouseId,
      warehouseName: params.warehouseName,
      volumeM3: params.volumeM3,
      startDate: params.startDate,
      endDate: endDate,
      durationDays: params.durationDays,
      pricePerM3PerDay: params.pricePerM3PerDay,
      totalCost: totalCost,
      status: BookingStatus.pending,
      paymentStatus: PaymentStatus.unpaid,
      qrCodeData: null,
      createdAt: now,
      updatedAt: now,
    );

    return repository.createBooking(entity);
  }
}
