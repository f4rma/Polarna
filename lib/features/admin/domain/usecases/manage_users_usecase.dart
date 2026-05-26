import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/admin_repository.dart';

/// Parameters for [ActivateUserUseCase] and [DeactivateUserUseCase].
class ManageUserParams extends Equatable {
  final String userId;

  const ManageUserParams({required this.userId});

  @override
  List<Object?> get props => [userId];
}

/// Activates a user account.
class ActivateUserUseCase {
  final AdminRepository repository;

  const ActivateUserUseCase(this.repository);

  Future<Either<Failure, Unit>> call(ManageUserParams params) {
    return repository.activateUser(params.userId);
  }
}

/// Deactivates a user account.
///
/// When the target user is a Mitra, the repository implementation MUST
/// cascade-deactivate all of their warehouses (Requirement 10.5).
class DeactivateUserUseCase {
  final AdminRepository repository;

  const DeactivateUserUseCase(this.repository);

  Future<Either<Failure, Unit>> call(ManageUserParams params) {
    return repository.deactivateUser(params.userId);
  }
}
