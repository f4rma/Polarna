import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/booking_entity.dart';
import '../../domain/repositories/booking_repository.dart';
import '../datasources/booking_remote_datasource.dart';

typedef _RemoteCall<T> = Future<T> Function();

/// Concrete [BookingRepository] implementation.
///
/// Responsibilities:
///   - Guard every remote call with [NetworkInfo.isConnected].
///   - Centralise [AppException] → [Failure] mapping via [_call].
///   - Delegate all Firestore transaction logic to [BookingRemoteDataSource].
class BookingRepositoryImpl implements BookingRepository {
  final BookingRemoteDataSource _remote;
  final NetworkInfo _networkInfo;

  const BookingRepositoryImpl({
    required BookingRemoteDataSource remote,
    required NetworkInfo networkInfo,
  })  : _remote = remote,
        _networkInfo = networkInfo;

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, BookingEntity>> createBooking(
    BookingEntity booking,
  ) {
    return _call<BookingEntity>(() => _remote.createBooking(booking));
  }

  @override
  Future<Either<Failure, BookingEntity>> updatePaymentStatus({
    required String bookingId,
    required PaymentStatus status,
  }) {
    return _call<BookingEntity>(
      () => _remote.updatePaymentStatus(bookingId: bookingId, status: status),
    );
  }

  @override
  Future<Either<Failure, BookingEntity>> cancelBooking({
    required String bookingId,
  }) {
    return _call<BookingEntity>(() => _remote.cancelBooking(bookingId));
  }

  @override
  Future<Either<Failure, BookingEntity>> completeBooking({
    required String bookingId,
  }) {
    return _call<BookingEntity>(() => _remote.completeBooking(bookingId));
  }

  @override
  Future<Either<Failure, BookingEntity>> checkInBooking({
    required String bookingId,
    required String qrCode,
  }) {
    return _call<BookingEntity>(() => _remote.checkInBooking(
          bookingId: bookingId,
          qrCode: qrCode,
        ));
  }

  @override
  Future<Either<Failure, BookingEntity>> checkOutBooking({
    required String bookingId,
    required String qrCode,
  }) {
    return _call<BookingEntity>(() => _remote.checkOutBooking(
          bookingId: bookingId,
          qrCode: qrCode,
        ));
  }

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  @override
  Future<Either<Failure, BookingEntity>> getById(String id) {
    return _call<BookingEntity>(() => _remote.getById(id));
  }

  @override
  Future<Either<Failure, List<BookingEntity>>> getHistoryForUmkm(
    String umkmId,
  ) {
    return _call<List<BookingEntity>>(() async {
      final list = await _remote.getHistoryForUmkm(umkmId);
      return List<BookingEntity>.from(list);
    });
  }

  @override
  Future<Either<Failure, List<BookingEntity>>> getHistoryForMitra(
    String mitraId,
  ) {
    return _call<List<BookingEntity>>(() async {
      final list = await _remote.getHistoryForMitra(mitraId);
      return List<BookingEntity>.from(list);
    });
  }

  @override
  Future<Either<Failure, List<BookingEntity>>> getActiveForWarehouse(
    String warehouseId,
  ) {
    return _call<List<BookingEntity>>(() async {
      final list = await _remote.getActiveForWarehouse(warehouseId);
      return List<BookingEntity>.from(list);
    });
  }

  @override
  Stream<BookingEntity> watchById(String id) {
    return _remote.watchById(id);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Generic network-aware remote-call wrapper.
  ///
  /// Centralises the `AppException → Failure` mapping so the public
  /// methods stay focused on their happy path.
  Future<Either<Failure, T>> _call<T>(_RemoteCall<T> action) async {
    if (!await _networkInfo.isConnected) {
      return const Left(NoInternetFailure());
    }
    try {
      return Right(await action());
    } on InsufficientCapacityException catch (e) {
      return Left(
        InsufficientCapacityFailure(remainingCapacity: e.remainingCapacity),
      );
    } on InvalidDateException {
      return const Left(InvalidDateFailure());
    } on PaymentGatewayException {
      return const Left(PaymentGatewayFailure());
    } on NoInternetException {
      return const Left(NoInternetFailure());
    } on TimeoutException {
      return const Left(TimeoutFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }
}
