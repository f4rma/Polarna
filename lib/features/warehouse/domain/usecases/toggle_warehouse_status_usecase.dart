import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/warehouse_repository.dart';

/// Parameters for [ToggleWarehouseStatusUseCase].
class ToggleWarehouseStatusParams extends Equatable {
  final String warehouseId;
  final bool isActive;

  const ToggleWarehouseStatusParams({
    required this.warehouseId,
    required this.isActive,
  });

  @override
  List<Object?> get props => [warehouseId, isActive];
}

/// Activates or deactivates a warehouse (Requirements 2.7, 2.8).
class ToggleWarehouseStatusUseCase {
  final WarehouseRepository repository;

  const ToggleWarehouseStatusUseCase(this.repository);

  Future<Either<Failure, Unit>> call(ToggleWarehouseStatusParams params) {
    return repository.toggleStatus(
      warehouseId: params.warehouseId,
      isActive: params.isActive,
    );
  }
}
