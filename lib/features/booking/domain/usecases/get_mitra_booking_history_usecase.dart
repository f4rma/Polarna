import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/booking_entity.dart';
import '../repositories/booking_repository.dart';

/// Parameters for [GetMitraBookingHistoryUseCase].
class GetMitraBookingHistoryParams extends Equatable {
  final String mitraId;

  const GetMitraBookingHistoryParams({required this.mitraId});

  @override
  List<Object?> get props => [mitraId];
}

/// Returns every booking made AT any warehouse owned by the given Mitra.
///
/// Thin delegate to [BookingRepository.getHistoryForMitra] — the data layer
/// resolves the Mitra's warehouses and aggregates bookings; this use case
/// exists so the presentation layer depends only on the domain contract.
class GetMitraBookingHistoryUseCase {
  final BookingRepository repository;

  const GetMitraBookingHistoryUseCase(this.repository);

  Future<Either<Failure, List<BookingEntity>>> call(
    GetMitraBookingHistoryParams params,
  ) {
    return repository.getHistoryForMitra(params.mitraId);
  }
}
