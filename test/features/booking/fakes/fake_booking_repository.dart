// Hand-rolled fake for [BookingRepository] used by BookingNotifier and
// use-case unit tests.
//
// No mockito / build_runner — plain Dart only. Responses are enqueued by the
// test; each call pops the next queued response. If a queue is empty when a
// method is called, a [StateError] is thrown so tests fail loudly.

import 'dart:async';
import 'dart:collection';

import 'package:dartz/dartz.dart';
import 'package:polarna/core/errors/failures.dart';
import 'package:polarna/features/booking/domain/entities/booking_entity.dart';
import 'package:polarna/features/booking/domain/repositories/booking_repository.dart';

/// Captured arguments of a single `createBooking` call.
class CreateBookingCall {
  final BookingEntity booking;
  const CreateBookingCall(this.booking);
}

/// Captured arguments of a single `getHistoryForUmkm` call.
class GetHistoryForUmkmCall {
  final String umkmId;
  const GetHistoryForUmkmCall(this.umkmId);
}

/// Captured arguments of a single `getHistoryForMitra` call.
class GetHistoryForMitraCall {
  final String mitraId;
  const GetHistoryForMitraCall(this.mitraId);
}

/// Captured arguments of a single `getActiveForWarehouse` call.
class GetActiveForWarehouseCall {
  final String warehouseId;
  const GetActiveForWarehouseCall(this.warehouseId);
}

/// Captured arguments of a single `getById` call.
class GetByIdCall {
  final String id;
  const GetByIdCall(this.id);
}

/// Captured arguments of a single `updatePaymentStatus` call.
class UpdatePaymentStatusCall {
  final String bookingId;
  final PaymentStatus status;
  const UpdatePaymentStatusCall(this.bookingId, this.status);
}

/// Captured arguments of a single `cancelBooking` call.
class CancelBookingCall {
  final String bookingId;
  const CancelBookingCall(this.bookingId);
}

/// Captured arguments of a single `completeBooking` call.
class CompleteBookingCall {
  final String bookingId;
  const CompleteBookingCall(this.bookingId);
}

class FakeBookingRepository implements BookingRepository {
  // ---------------------------------------------------------------------------
  // Response queues — tests enqueue responses in the order they expect them.
  // ---------------------------------------------------------------------------

  final Queue<Either<Failure, BookingEntity>> createBookingResponses = Queue();
  final Queue<Either<Failure, List<BookingEntity>>> getHistoryForUmkmResponses =
      Queue();
  final Queue<Either<Failure, List<BookingEntity>>>
      getHistoryForMitraResponses = Queue();
  final Queue<Either<Failure, List<BookingEntity>>>
      getActiveForWarehouseResponses = Queue();
  final Queue<Either<Failure, BookingEntity>> getByIdResponses = Queue();
  final Queue<Either<Failure, BookingEntity>> updatePaymentStatusResponses =
      Queue();
  final Queue<Either<Failure, BookingEntity>> cancelBookingResponses = Queue();
  final Queue<Either<Failure, BookingEntity>> completeBookingResponses =
      Queue();

  // ---------------------------------------------------------------------------
  // Invocation log — tests assert on call counts and arguments.
  // ---------------------------------------------------------------------------

  final List<CreateBookingCall> createBookingCalls = [];
  final List<GetHistoryForUmkmCall> getHistoryForUmkmCalls = [];
  final List<GetHistoryForMitraCall> getHistoryForMitraCalls = [];
  final List<GetActiveForWarehouseCall> getActiveForWarehouseCalls = [];
  final List<GetByIdCall> getByIdCalls = [];
  final List<UpdatePaymentStatusCall> updatePaymentStatusCalls = [];
  final List<CancelBookingCall> cancelBookingCalls = [];
  final List<CompleteBookingCall> completeBookingCalls = [];

  // ---------------------------------------------------------------------------
  // Watch stream.
  // ---------------------------------------------------------------------------

  final StreamController<BookingEntity> watchController =
      StreamController<BookingEntity>.broadcast();

  Future<void> dispose() => watchController.close();

  // ---------------------------------------------------------------------------
  // Repository API.
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, BookingEntity>> createBooking(
    BookingEntity booking,
  ) async {
    createBookingCalls.add(CreateBookingCall(booking));
    if (createBookingResponses.isEmpty) {
      throw StateError('No createBookingResponses queued');
    }
    return createBookingResponses.removeFirst();
  }

  @override
  Future<Either<Failure, List<BookingEntity>>> getHistoryForUmkm(
    String umkmId,
  ) async {
    getHistoryForUmkmCalls.add(GetHistoryForUmkmCall(umkmId));
    if (getHistoryForUmkmResponses.isEmpty) {
      throw StateError('No getHistoryForUmkmResponses queued');
    }
    return getHistoryForUmkmResponses.removeFirst();
  }

  @override
  Future<Either<Failure, List<BookingEntity>>> getHistoryForMitra(
    String mitraId,
  ) async {
    getHistoryForMitraCalls.add(GetHistoryForMitraCall(mitraId));
    if (getHistoryForMitraResponses.isEmpty) {
      throw StateError('No getHistoryForMitraResponses queued');
    }
    return getHistoryForMitraResponses.removeFirst();
  }

  @override
  Future<Either<Failure, List<BookingEntity>>> getActiveForWarehouse(
    String warehouseId,
  ) async {
    getActiveForWarehouseCalls.add(GetActiveForWarehouseCall(warehouseId));
    if (getActiveForWarehouseResponses.isEmpty) {
      throw StateError('No getActiveForWarehouseResponses queued');
    }
    return getActiveForWarehouseResponses.removeFirst();
  }

  @override
  Future<Either<Failure, BookingEntity>> getById(String id) async {
    getByIdCalls.add(GetByIdCall(id));
    if (getByIdResponses.isEmpty) {
      throw StateError('No getByIdResponses queued');
    }
    return getByIdResponses.removeFirst();
  }

  @override
  Stream<BookingEntity> watchById(String id) => watchController.stream;

  @override
  Future<Either<Failure, BookingEntity>> updatePaymentStatus({
    required String bookingId,
    required PaymentStatus status,
  }) async {
    updatePaymentStatusCalls
        .add(UpdatePaymentStatusCall(bookingId, status));
    if (updatePaymentStatusResponses.isEmpty) {
      throw StateError('No updatePaymentStatusResponses queued');
    }
    return updatePaymentStatusResponses.removeFirst();
  }

  @override
  Future<Either<Failure, BookingEntity>> cancelBooking({
    required String bookingId,
  }) async {
    cancelBookingCalls.add(CancelBookingCall(bookingId));
    if (cancelBookingResponses.isEmpty) {
      throw StateError('No cancelBookingResponses queued');
    }
    return cancelBookingResponses.removeFirst();
  }

  @override
  Future<Either<Failure, BookingEntity>> completeBooking({
    required String bookingId,
  }) async {
    completeBookingCalls.add(CompleteBookingCall(bookingId));
    if (completeBookingResponses.isEmpty) {
      throw StateError('No completeBookingResponses queued');
    }
    return completeBookingResponses.removeFirst();
  }
}
