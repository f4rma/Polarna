import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';

/// Parameters for [CalculateCostUseCase].
///
/// Field-level range validation (volume kelipatan 0,5; durasi 1–365 hari;
/// dll.) lives in `core/utils/validators.dart` and is invoked by the
/// presentation layer. This use case enforces only the minimal arithmetic
/// precondition that both factors are positive.
class CalculateCostParams extends Equatable {
  final double volumeM3;
  final double pricePerM3PerDay;
  final int durationDays;

  const CalculateCostParams({
    required this.volumeM3,
    required this.pricePerM3PerDay,
    required this.durationDays,
  });

  @override
  List<Object?> get props => [volumeM3, pricePerM3PerDay, durationDays];
}

/// Pure-function use case that computes the total cost of a booking.
///
/// Formula (Requirement 4.2):
///
/// ```
/// total_biaya = volume_m3 × harga_per_m3_per_hari × durasi_hari
/// ```
///
/// The result is returned as-is, without any undocumented rounding, so
/// currency formatting (e.g. "Rp 1.234.567") remains a presentation-layer
/// concern.
class CalculateCostUseCase {
  const CalculateCostUseCase();

  Either<Failure, double> call(CalculateCostParams params) {
    if (params.volumeM3 <= 0) {
      return const Left(ServerFailure('Volume harus positif'));
    }
    if (params.durationDays <= 0) {
      return const Left(ServerFailure('Durasi harus positif'));
    }
    final total =
        params.volumeM3 * params.pricePerM3PerDay * params.durationDays;
    return Right(total);
  }
}
