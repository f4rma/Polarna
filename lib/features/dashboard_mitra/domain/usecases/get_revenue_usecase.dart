import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/revenue_summary.dart';
import '../repositories/dashboard_repository.dart';

/// Parameters for [GetRevenueUseCase].
class GetRevenueParams extends Equatable {
  final String mitraId;

  const GetRevenueParams({required this.mitraId});

  @override
  List<Object?> get props => [mitraId];
}

/// Fetches the revenue summary for a Mitra.
///
/// Delegates to [DashboardRepository.getRevenueSummary] which computes
/// daily revenue, monthly revenue, active transaction count, and
/// capacity utilization percentage (Requirements 8.1–8.2).
class GetRevenueUseCase {
  final DashboardRepository repository;

  const GetRevenueUseCase(this.repository);

  Future<Either<Failure, RevenueSummary>> call(GetRevenueParams params) {
    return repository.getRevenueSummary(params.mitraId);
  }
}
