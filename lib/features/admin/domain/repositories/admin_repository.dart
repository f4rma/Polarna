import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../entities/platform_summary.dart';

/// Abstract data contract between the admin domain and data layers.
///
/// Implementations live in `data/repositories/admin_repository_impl.dart`.
abstract class AdminRepository {
  /// Activates a user account by [userId].
  Future<Either<Failure, Unit>> activateUser(String userId);

  /// Deactivates a user account by [userId].
  ///
  /// When the user is a Mitra, all of their warehouses MUST be
  /// cascade-deactivated as well (Requirement 10.5).
  Future<Either<Failure, Unit>> deactivateUser(String userId);

  /// Retrieves platform-wide summary metrics.
  Future<Either<Failure, PlatformSummary>> getPlatformSummary();

  /// Fetches all registered users on the platform.
  Future<Either<Failure, List<UserEntity>>> getAllUsers();
}
