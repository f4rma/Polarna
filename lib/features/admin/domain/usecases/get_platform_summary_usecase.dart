import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/platform_summary.dart';
import '../repositories/admin_repository.dart';

/// Retrieves platform-wide summary metrics for the Admin dashboard.
class GetPlatformSummaryUseCase {
  final AdminRepository repository;

  const GetPlatformSummaryUseCase(this.repository);

  Future<Either<Failure, PlatformSummary>> call() {
    return repository.getPlatformSummary();
  }
}
