// Property tests for atomicity of capacity reduction on successful booking.
//
// Validates: Requirements 4.5a
// Reference: .kiro/specs/coldshare-platform/requirements.md#Requirement 4
//
// Property 9: Atomisitas Pengurangan Kapasitas Saat Booking Berhasil
//   For every booking that succeeds with volume v on a warehouse with initial
//   remaining capacity R, the remaining capacity after booking SHALL equal R - v.

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
// `glados` re-exports `package:test/test.dart`, which collides with
// `flutter_test`. Hide the duplicates so the flutter_test versions win.
// ignore: depend_on_referenced_packages
import 'package:glados/glados.dart' hide test, group, expect;
import 'package:polarna/core/errors/failures.dart';
import 'package:polarna/features/booking/domain/entities/booking_entity.dart';
import 'package:polarna/features/booking/domain/repositories/booking_repository.dart';
import 'package:polarna/features/booking/domain/usecases/create_booking_usecase.dart';

// ---------------------------------------------------------------------------
// Fake repository — simulates atomic capacity decrement on createBooking.
//
// On `createBooking(entity)`:
//   - Stores the entity
//   - Decrements internal `remainingCapacity` by `entity.volumeM3`
//   - If volume > remainingCapacity, returns Left(InsufficientCapacityFailure)
//   - Otherwise returns Right(entity)
//
// Exposes `remainingCapacity` so the test can assert the post-condition.
// ---------------------------------------------------------------------------
class _FakeBookingRepo implements BookingRepository {
  double remainingCapacity;
  BookingEntity? lastBooking;

  _FakeBookingRepo({required this.remainingCapacity});

  @override
  Future<Either<Failure, BookingEntity>> createBooking(
    BookingEntity booking,
  ) async {
    if (booking.volumeM3 > remainingCapacity) {
      return Left(InsufficientCapacityFailure(
        remainingCapacity: remainingCapacity,
      ));
    }
    // Atomic decrement
    remainingCapacity -= booking.volumeM3;
    lastBooking = booking;
    return Right(booking);
  }

  // Unused by these tests — fail loudly if accidentally invoked.
  @override
  Future<Either<Failure, List<BookingEntity>>> getHistoryForUmkm(
          String umkmId) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, List<BookingEntity>>> getHistoryForMitra(
          String mitraId) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, List<BookingEntity>>> getActiveForWarehouse(
          String warehouseId) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, BookingEntity>> getById(String id) =>
      throw UnimplementedError();
  @override
  Stream<BookingEntity> watchById(String id) => throw UnimplementedError();
  @override
  Future<Either<Failure, BookingEntity>> updatePaymentStatus({
    required String bookingId,
    required PaymentStatus status,
  }) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, BookingEntity>> cancelBooking({
    required String bookingId,
  }) =>
      throw UnimplementedError();
  @override
  Future<Either<Failure, BookingEntity>> completeBooking({
    required String bookingId,
  }) =>
      throw UnimplementedError();
}

// ---------------------------------------------------------------------------
// Helpers.
// ---------------------------------------------------------------------------

/// Uniform `double` in `[min, max]` (both inclusive) with millionth-step
/// granularity — plenty of resolution for boundary exploration.
Generator<double> _doubleInRange(double min, double max) {
  return any
      .intInRange(0, 1000001) // [0, 1_000_000] inclusive
      .map((n) => min + (max - min) * (n / 1000000.0));
}

/// Creates a [CreateBookingParams] with a valid future startDate and
/// durationDays=1 so the date check doesn't interfere.
CreateBookingParams _mkParams({
  required double volume,
  required double remainingCapacity,
}) {
  // Use a date far in the future to avoid past-date rejection.
  final futureDate = DateTime.now().toUtc().add(const Duration(days: 30));
  return CreateBookingParams(
    umkmId: 'umkm-test-1',
    warehouseId: 'wh-test-1',
    warehouseName: 'Gudang Uji',
    volumeM3: volume,
    pricePerM3PerDay: 1000.0,
    startDate: futureDate,
    durationDays: 1,
    remainingCapacity: remainingCapacity,
  );
}

void main() {
  // ---------------------------------------------------------------------------
  // Generator: valid pair (R, v) where v ≤ R.
  // R ∈ [0.5, 999_999], v = R * fraction where fraction ∈ [0.001, 1.0]
  // ---------------------------------------------------------------------------
  final validPairGen = any.combine2(
    _doubleInRange(0.5, 999999.0),
    _doubleInRange(0.001, 1.0),
    (double remaining, double fraction) => (
      remaining, // R
      remaining * fraction, // v (≤ R)
    ),
  );

  // ---------------------------------------------------------------------------
  // Generator: list of 2-5 volumes that sum ≤ R.
  // Strategy: generate R, then generate 2-5 fractions that sum ≤ 1.0,
  // multiply each by R to get volumes.
  // ---------------------------------------------------------------------------
  final multiBookingGen = any.combine2(
    _doubleInRange(10.0, 999999.0), // R (min 10 to allow multiple bookings)
    any.intInRange(2, 6), // count: 2..5
    (double remaining, int count) {
      // Divide remaining into `count` equal parts (conservative approach)
      // Each volume = R / (count + 1) to ensure sum < R
      final volumeEach = remaining / (count + 1);
      return (remaining, List.generate(count, (_) => volumeEach));
    },
  );

  // ---------------------------------------------------------------------------
  // Generator: rejected pair (R, v) where v > R.
  // ---------------------------------------------------------------------------
  final rejectedPairGen = any.combine2(
    _doubleInRange(0.5, 999999.0),
    _doubleInRange(0.001, 999999.0),
    (double remaining, double excess) => (
      remaining, // R
      remaining + excess, // v (> R)
    ),
  );

  group(
      'Property 9: Atomisitas Pengurangan Kapasitas - Requirement 4.5a', () {
    // -----------------------------------------------------------------------
    // 1. After successful booking, remaining = R - v
    // -----------------------------------------------------------------------
    Glados(validPairGen).test(
        'after successful booking, remaining capacity equals R - v',
        (pair) async {
      final (remaining, volume) = pair;
      expect(volume, lessThanOrEqualTo(remaining));

      final repo = _FakeBookingRepo(remainingCapacity: remaining);
      final useCase = CreateBookingUseCase(repo);
      final result = await useCase(_mkParams(
        volume: volume,
        remainingCapacity: remaining,
      ));

      expect(result.isRight(), isTrue,
          reason:
              'Expected Right for volume=$volume, remaining=$remaining');

      // Post-condition: remaining capacity = R - v
      final expectedRemaining = remaining - volume;
      expect(repo.remainingCapacity, closeTo(expectedRemaining, 1e-9),
          reason:
              'After booking volume=$volume from R=$remaining, '
              'expected remaining=$expectedRemaining but got '
              '${repo.remainingCapacity}');
    });

    // -----------------------------------------------------------------------
    // 2. Multiple sequential bookings decrement correctly
    // -----------------------------------------------------------------------
    Glados(multiBookingGen).test(
        'multiple sequential bookings decrement remaining correctly',
        (data) async {
      final (remaining, volumes) = data;
      final totalVolume = volumes.fold(0.0, (sum, v) => sum + v);
      // Ensure sum of volumes ≤ R (guaranteed by generator design)
      expect(totalVolume, lessThanOrEqualTo(remaining));

      final repo = _FakeBookingRepo(remainingCapacity: remaining);
      final useCase = CreateBookingUseCase(repo);

      // Execute all bookings sequentially
      for (final v in volumes) {
        final result = await useCase(_mkParams(
          volume: v,
          remainingCapacity: repo.remainingCapacity,
        ));
        expect(result.isRight(), isTrue,
            reason:
                'Expected Right for volume=$v, '
                'currentRemaining=${repo.remainingCapacity}');
      }

      // Post-condition: remaining = R - sum(volumes)
      final expectedRemaining = remaining - totalVolume;
      expect(repo.remainingCapacity, closeTo(expectedRemaining, 1e-6),
          reason:
              'After ${volumes.length} bookings totaling $totalVolume from '
              'R=$remaining, expected remaining=$expectedRemaining but got '
              '${repo.remainingCapacity}');
    });

    // -----------------------------------------------------------------------
    // 3. Rejected booking does NOT change remaining
    // -----------------------------------------------------------------------
    Glados(rejectedPairGen).test(
        'rejected booking does NOT change remaining capacity', (pair) async {
      final (remaining, volume) = pair;
      expect(volume, greaterThan(remaining));

      final repo = _FakeBookingRepo(remainingCapacity: remaining);
      final useCase = CreateBookingUseCase(repo);
      final result = await useCase(_mkParams(
        volume: volume,
        remainingCapacity: remaining,
      ));

      expect(result.isLeft(), isTrue,
          reason:
              'Expected Left for volume=$volume, remaining=$remaining');

      // Post-condition: remaining capacity unchanged
      expect(repo.remainingCapacity, equals(remaining),
          reason:
              'After rejected booking (volume=$volume > remaining=$remaining), '
              'remaining capacity should be unchanged but got '
              '${repo.remainingCapacity}');
    });
  });
}
