import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polarna/core/errors/failures.dart';
import 'package:polarna/features/booking/data/providers/booking_data_providers.dart';
import 'package:polarna/features/booking/domain/entities/booking_entity.dart';
import 'package:polarna/features/booking/domain/usecases/calculate_cost_usecase.dart';
import 'package:polarna/features/booking/domain/usecases/create_booking_usecase.dart';
import 'package:polarna/features/booking/domain/usecases/get_booking_history_usecase.dart';
import 'package:polarna/features/booking/presentation/providers/booking_provider.dart';

import 'fakes/fake_booking_repository.dart';
import 'fakes/fake_payment_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

BookingEntity _sampleBooking({
  String id = 'b1',
  String umkmId = 'u1',
  String warehouseId = 'w1',
}) {
  final now = DateTime.now();
  return BookingEntity(
    id: id,
    umkmId: umkmId,
    warehouseId: warehouseId,
    warehouseName: 'Gudang A',
    volumeM3: 5.0,
    startDate: now.add(const Duration(days: 1)),
    endDate: now.add(const Duration(days: 31)),
    durationDays: 30,
    pricePerM3PerDay: 1000.0,
    totalCost: 150000.0,
    status: BookingStatus.active,
    paymentStatus: PaymentStatus.paid,
    qrCodeData: 'qr-data',
    createdAt: now,
    updatedAt: now,
  );
}

// ---------------------------------------------------------------------------
// CalculateCostUseCase Tests
// ---------------------------------------------------------------------------

void main() {
  group('CalculateCostUseCase', () {
    const useCase = CalculateCostUseCase();

    test('valid params → Right(volume × price × duration)', () {
      const params = CalculateCostParams(
        volumeM3: 2.0,
        pricePerM3PerDay: 500.0,
        durationDays: 10,
      );

      final result = useCase.call(params);

      expect(result, equals(const Right<Failure, double>(10000.0)));
    });

    test('volume ≤ 0 → Left(ServerFailure)', () {
      const params = CalculateCostParams(
        volumeM3: 0.0,
        pricePerM3PerDay: 500.0,
        durationDays: 10,
      );

      final result = useCase.call(params);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('Expected Left'),
      );
    });

    test('duration ≤ 0 → Left(ServerFailure)', () {
      const params = CalculateCostParams(
        volumeM3: 2.0,
        pricePerM3PerDay: 500.0,
        durationDays: 0,
      );

      final result = useCase.call(params);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('Expected Left'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // CreateBookingUseCase Tests
  // -------------------------------------------------------------------------

  group('CreateBookingUseCase', () {
    late FakeBookingRepository fakeRepo;
    late CreateBookingUseCase useCase;

    setUp(() {
      fakeRepo = FakeBookingRepository();
      useCase = CreateBookingUseCase(fakeRepo);
    });

    test('volume > remainingCapacity → Left(InsufficientCapacityFailure)',
        () async {
      final params = CreateBookingParams(
        umkmId: 'u1',
        warehouseId: 'w1',
        warehouseName: 'Gudang A',
        volumeM3: 10.0,
        pricePerM3PerDay: 1000.0,
        startDate: DateTime.now().add(const Duration(days: 1)),
        durationDays: 30,
        remainingCapacity: 5.0,
      );

      final result = await useCase.call(params);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<InsufficientCapacityFailure>()),
        (_) => fail('Expected Left'),
      );
    });

    test('past startDate → Left(InvalidDateFailure)', () async {
      final params = CreateBookingParams(
        umkmId: 'u1',
        warehouseId: 'w1',
        warehouseName: 'Gudang A',
        volumeM3: 2.0,
        pricePerM3PerDay: 1000.0,
        startDate: DateTime.now().subtract(const Duration(days: 2)),
        durationDays: 30,
        remainingCapacity: 10.0,
      );

      final result = await useCase.call(params);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<InvalidDateFailure>()),
        (_) => fail('Expected Left'),
      );
    });

    test('valid params → Right(entity from repo)', () async {
      final expectedBooking = _sampleBooking();
      fakeRepo.createBookingResponses.add(Right(expectedBooking));

      final params = CreateBookingParams(
        umkmId: 'u1',
        warehouseId: 'w1',
        warehouseName: 'Gudang A',
        volumeM3: 5.0,
        pricePerM3PerDay: 1000.0,
        startDate: DateTime.now().add(const Duration(days: 1)),
        durationDays: 30,
        remainingCapacity: 20.0,
      );

      final result = await useCase.call(params);

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (booking) => expect(booking, equals(expectedBooking)),
      );
      expect(fakeRepo.createBookingCalls.length, 1);
    });
  });

  // -------------------------------------------------------------------------
  // GetBookingHistoryUseCase Tests
  // -------------------------------------------------------------------------

  group('GetBookingHistoryUseCase', () {
    late FakeBookingRepository fakeRepo;
    late GetBookingHistoryUseCase useCase;

    setUp(() {
      fakeRepo = FakeBookingRepository();
      useCase = GetBookingHistoryUseCase(fakeRepo);
    });

    test('delegates umkmId to repo', () async {
      final bookings = [_sampleBooking(), _sampleBooking(id: 'b2')];
      fakeRepo.getHistoryForUmkmResponses.add(Right(bookings));

      final result = await useCase.call(
        const GetBookingHistoryParams(umkmId: 'u1'),
      );

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (list) => expect(list.length, 2),
      );
      expect(fakeRepo.getHistoryForUmkmCalls.length, 1);
      expect(fakeRepo.getHistoryForUmkmCalls.first.umkmId, 'u1');
    });
  });

  // -------------------------------------------------------------------------
  // BookingNotifier Tests
  // -------------------------------------------------------------------------

  group('BookingNotifier', () {
    late FakeBookingRepository fakeRepo;
    late FakePaymentService fakePayment;
    late ProviderContainer container;

    setUp(() {
      fakeRepo = FakeBookingRepository();
      fakePayment = FakePaymentService();
      container = ProviderContainer(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(fakeRepo),
          paymentServiceProvider.overrideWithValue(fakePayment),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('calculateCost valid → phase=costDisplayed, estimatedCost set', () {
      final notifier = container.read(bookingProvider.notifier);

      notifier.calculateCost(
        volumeM3: 3.0,
        pricePerM3PerDay: 200.0,
        durationDays: 5,
      );

      final state = container.read(bookingProvider);
      expect(state.phase, BookingPhase.costDisplayed);
      expect(state.estimatedCost, 3000.0);
      expect(state.errorMessage, isNull);
    });

    test('calculateCost invalid → phase=idle, errorMessage set', () {
      final notifier = container.read(bookingProvider.notifier);

      notifier.calculateCost(
        volumeM3: -1.0,
        pricePerM3PerDay: 200.0,
        durationDays: 5,
      );

      final state = container.read(bookingProvider);
      expect(state.phase, BookingPhase.idle);
      expect(state.errorMessage, isNotNull);
    });

    test('confirmBooking success → phase=bookingActive, activeBooking set',
        () async {
      final expectedBooking = _sampleBooking();
      fakePayment.processPaymentResponses.add(true);
      fakeRepo.createBookingResponses.add(Right(expectedBooking));

      final notifier = container.read(bookingProvider.notifier);

      await notifier.confirmBooking(
        umkmId: 'u1',
        warehouseId: 'w1',
        warehouseName: 'Gudang A',
        volumeM3: 5.0,
        pricePerM3PerDay: 1000.0,
        startDate: DateTime.now().add(const Duration(days: 1)),
        durationDays: 30,
        remainingCapacity: 20.0,
      );

      final state = container.read(bookingProvider);
      expect(state.phase, BookingPhase.bookingActive);
      expect(state.activeBooking, equals(expectedBooking));
    });

    test('confirmBooking payment fails → phase=paymentFailed', () async {
      fakePayment.processPaymentResponses.add(false);

      final notifier = container.read(bookingProvider.notifier);

      await notifier.confirmBooking(
        umkmId: 'u1',
        warehouseId: 'w1',
        warehouseName: 'Gudang A',
        volumeM3: 5.0,
        pricePerM3PerDay: 1000.0,
        startDate: DateTime.now().add(const Duration(days: 1)),
        durationDays: 30,
        remainingCapacity: 20.0,
      );

      final state = container.read(bookingProvider);
      expect(state.phase, BookingPhase.paymentFailed);
      expect(state.errorMessage, isNotNull);
    });

    test('getHistory → history list populated', () async {
      final bookings = [_sampleBooking(), _sampleBooking(id: 'b2')];
      fakeRepo.getHistoryForUmkmResponses.add(Right(bookings));

      final notifier = container.read(bookingProvider.notifier);

      await notifier.getHistory(umkmId: 'u1');

      final state = container.read(bookingProvider);
      expect(state.history.length, 2);
      expect(state.isLoadingHistory, isFalse);
    });

    test('reset → state back to initial', () {
      final notifier = container.read(bookingProvider.notifier);

      // First set some state
      notifier.calculateCost(
        volumeM3: 3.0,
        pricePerM3PerDay: 200.0,
        durationDays: 5,
      );
      expect(container.read(bookingProvider).phase, BookingPhase.costDisplayed);

      // Then reset
      notifier.reset();

      final state = container.read(bookingProvider);
      expect(state.phase, BookingPhase.idle);
      expect(state.estimatedCost, isNull);
      expect(state.activeBooking, isNull);
      expect(state.history, isEmpty);
      expect(state.errorMessage, isNull);
    });
  });
}
