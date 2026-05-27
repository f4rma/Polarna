// Property tests for booking capacity rejection at the domain/use-case layer.
//
// Validates: Requirements 4.3
// Reference: .kiro/specs/coldshare-platform/requirements.md#Requirement 4
//
// Property 8: Penolakan Pemesanan Melebihi Kapasitas Tersedia
//   For every pair (volume_ordered, remaining_capacity):
//     - volume <= remaining  →  CreateBookingUseCase proceeds (returns Right)
//     - volume >  remaining  →  CreateBookingUseCase rejects with
//                               InsufficientCapacityFailure whose message
//                               contains the remaining capacity value, and
//                               the repository is NOT called.

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
// Fake repository — echoes the entity back on createBooking and tracks call
// count so tests can assert the use case short-circuits before hitting the
// data layer when the capacity invariant is violated.
// ---------------------------------------------------------------------------
class _FakeBookingRepo implements BookingRepository {
  int createBookingCalls = 0;

  @override
  Future<Either<Failure, BookingEntity>> createBooking(
    BookingEntity booking,
  ) async {
    createBookingCalls++;
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
  // Valid pair: volume ∈ [0.5, remaining], remaining ∈ [0.5, 999_999].
  // We generate remaining first, then volume as remaining * fraction.
  final acceptedPairGen = any.combine2(
    _doubleInRange(0.5, 999999.0),
    _doubleInRange(0.0, 1.0),
    (double remaining, double fraction) =>
        (remaining * fraction.clamp(0.001, 1.0), remaining),
  );

  // Violating pair: volume = remaining + excess, excess ∈ [0.001, 999_999].
  final rejectedPairGen = any.combine2(
    _doubleInRange(0.5, 999999.0),
    _doubleInRange(0.001, 999999.0),
    (double remaining, double excess) => (remaining + excess, remaining),
  );

  group('Property 8: Penolakan Pemesanan Melebihi Kapasitas - Requirement 4.3',
      () {
    // -----------------------------------------------------------------------
    // 1. Volume ≤ remaining → accepted
    // -----------------------------------------------------------------------
    Glados(acceptedPairGen).test(
        'accepts booking when volume <= remaining capacity', (pair) async {
      final (volume, remaining) = pair;
      expect(volume, lessThanOrEqualTo(remaining));

      final repo = _FakeBookingRepo();
      final useCase = CreateBookingUseCase(repo);
      final result = await useCase(_mkParams(
        volume: volume,
        remainingCapacity: remaining,
      ));

      expect(result.isRight(), isTrue,
          reason:
              'Expected Right for volume=$volume, remaining=$remaining');
      expect(repo.createBookingCalls, 1,
          reason: 'Repository should be invoked once on valid input');
    });

    // -----------------------------------------------------------------------
    // 2. Volume > remaining → rejected
    // -----------------------------------------------------------------------
    Glados(rejectedPairGen).test(
        'rejects booking when volume > remaining capacity', (pair) async {
      final (volume, remaining) = pair;
      expect(volume, greaterThan(remaining));

      final repo = _FakeBookingRepo();
      final useCase = CreateBookingUseCase(repo);
      final result = await useCase(_mkParams(
        volume: volume,
        remainingCapacity: remaining,
      ));

      expect(result.isLeft(), isTrue,
          reason:
              'Expected Left for volume=$volume, remaining=$remaining');
      result.fold(
        (f) {
          expect(f, isA<InsufficientCapacityFailure>());
          final failure = f as InsufficientCapacityFailure;
          expect(failure.remainingCapacity, equals(remaining));
          expect(failure.message, contains(remaining.toString()));
        },
        (_) => fail('Expected Left but got Right'),
      );
      expect(repo.createBookingCalls, 0,
          reason:
              'Repository must NOT be called when capacity is insufficient');
    });

    // -----------------------------------------------------------------------
    // 3. Boundary cases
    // -----------------------------------------------------------------------
    group('Boundary cases', () {
      test('volume == remaining → accepted', () async {
        const remaining = 100.0;
        const volume = 100.0;

        final repo = _FakeBookingRepo();
        final useCase = CreateBookingUseCase(repo);
        final result = await useCase(_mkParams(
          volume: volume,
          remainingCapacity: remaining,
        ));

        expect(result.isRight(), isTrue,
            reason: 'volume == remaining should be accepted');
        expect(repo.createBookingCalls, 1);
      });

      test('volume == remaining + 0.5 → rejected', () async {
        const remaining = 100.0;
        const volume = 100.5;

        final repo = _FakeBookingRepo();
        final useCase = CreateBookingUseCase(repo);
        final result = await useCase(_mkParams(
          volume: volume,
          remainingCapacity: remaining,
        ));

        expect(result.isLeft(), isTrue,
            reason: 'volume > remaining by 0.5 should be rejected');
        result.fold(
          (f) {
            expect(f, isA<InsufficientCapacityFailure>());
            final failure = f as InsufficientCapacityFailure;
            expect(failure.remainingCapacity, equals(remaining));
            expect(failure.message, contains(remaining.toString()));
          },
          (_) => fail('Expected Left but got Right'),
        );
        expect(repo.createBookingCalls, 0,
            reason: 'Repository must NOT be called when rejected');
      });
    });
  });
}
