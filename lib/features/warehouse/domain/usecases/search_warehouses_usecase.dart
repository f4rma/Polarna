import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/warehouse_entity.dart';
import '../entities/warehouse_search_filter.dart';
import '../repositories/warehouse_repository.dart';

/// Parameters for [SearchWarehousesUseCase].
class SearchWarehousesParams extends Equatable {
  final WarehouseSearchFilter filter;

  const SearchWarehousesParams({required this.filter});

  @override
  List<Object?> get props => [filter];
}

/// Searches warehouses matching the given filter.
///
/// Delegates entirely to [WarehouseRepository.searchWarehouses]; the data
/// layer is responsible for distance calculations and Firestore querying.
class SearchWarehousesUseCase {
  final WarehouseRepository repository;

  const SearchWarehousesUseCase(this.repository);

  Future<Either<Failure, List<WarehouseEntity>>> call(
    SearchWarehousesParams params,
  ) {
    return repository.searchWarehouses(params.filter);
  }
}
