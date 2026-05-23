import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/warehouse_entity.dart';
import '../repositories/warehouse_repository.dart';

/// Parameters for [UpdateWarehouseUseCase].
class UpdateWarehouseParams extends Equatable {
  final WarehouseEntity warehouse;

  const UpdateWarehouseParams({required this.warehouse});

  @override
  List<Object?> get props => [warehouse];
}

/// Updates an existing warehouse, enforcing the
/// `remainingCapacity <= totalCapacity` invariant (Requirement 2.6).
class UpdateWarehouseUseCase {
  final WarehouseRepository repository;

  const UpdateWarehouseUseCase(this.repository);

  Future<Either<Failure, WarehouseEntity>> call(
    UpdateWarehouseParams params,
  ) {
    final w = params.warehouse;
    if (w.remainingCapacity > w.totalCapacity) {
      return Future.value(
        Left(InvalidRemainingCapacityFailure(
          totalCapacity: w.totalCapacity,
        )),
      );
    }
    return repository.updateWarehouse(
      w.copyWith(updatedAt: DateTime.now().toUtc()),
    );
  }
}
