import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class SignUpParams extends Equatable {
  final String email;
  final String password;
  final String fullName;
  final String phoneNumber;
  final UserRole role;

  const SignUpParams({
    required this.email,
    required this.password,
    required this.fullName,
    required this.phoneNumber,
    required this.role,
  });

  @override
  List<Object?> get props => [email, password, fullName, phoneNumber, role];
}

/// Registers a new user account.
///
/// Validation of format rules (RFC 5321 email, 8–64 char password with
/// uppercase + digit, E.164 phone, etc.) is handled by
/// `core/utils/validators.dart` in the presentation layer.
class SignUpUseCase {
  final AuthRepository _repository;

  const SignUpUseCase(this._repository);

  Future<Either<Failure, UserEntity>> call(SignUpParams params) {
    return _repository.signUp(
      email: params.email,
      password: params.password,
      fullName: params.fullName,
      phoneNumber: params.phoneNumber,
      role: params.role,
    );
  }
}
