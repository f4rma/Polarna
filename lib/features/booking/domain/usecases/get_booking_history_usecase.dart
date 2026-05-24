import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/booking_entity.dart';
import '../repositories/booking_repository.dart';

/// Parameters for [GetBookingHistoryUseCase].
class GetBookingHistoryParams extends Equatable {
  final String umkmId;

  const GetBookingHistoryParams({required this.umkmId});

  @override
  List<Object?> get props => [umkmId];
}

/// Returns the full booking history for a UMKM (Requirement 4.8).
///
/// Thin delegate to [BookingRepository.getHistoryForUmkm] — the data layer
/// handles sorting/pagination; this use case exists so that the
/// presentation layer depends only on the domain contract.
class GetBookingHistoryUseCase {
  final BookingRepository repository;

  const GetBookingHistoryUseCase(this.repository);

  Future<Either<Failure, List<BookingEntity>>> call(
    GetBookingHistoryParams params,
  ) {
    return repository.getHistoryForUmkm(params.umkmId);
  }
}
