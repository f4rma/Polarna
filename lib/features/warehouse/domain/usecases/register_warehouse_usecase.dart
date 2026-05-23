import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/warehouse_entity.dart';
import '../repositories/warehouse_repository.dart';

/// Parameters needed to register a new warehouse.
///
/// Fields managed by the data layer ([WarehouseEntity.id],
/// [WarehouseEntity.createdAt], [WarehouseEntity.updatedAt]) are omitted.
class RegisterWarehouseParams extends Equatable {
  final String mitraId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double totalCapacity;
  final double remainingCapacity;
  final double pricePerM3PerDay;
  final TemperatureCategory temperatureCategory;
  final double temperatureThreshold;
  final List<String> photoUrls;
  final bool isActive;
  final String? iotNodeId;

  const RegisterWarehouseParams({
    required this.mitraId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.totalCapacity,
    required this.remainingCapacity,
    required this.pricePerM3PerDay,
    required this.temperatureCategory,
    required this.temperatureThreshold,
    required this.photoUrls,
    this.isActive = true,
    this.iotNodeId,
  });

  @override
  List<Object?> get props => [
        mitraId,
        name,
        address,
        latitude,
        longitude,
        totalCapacity,
        remainingCapacity,
        pricePerM3PerDay,
        temperatureCategory,
        temperatureThreshold,
        photoUrls,
        isActive,
        iotNodeId,
      ];
}

/// Registers a new warehouse, enforcing the remaining-vs-total capacity
/// invariant at the domain level (Requirement 2.6).
///
/// Other field-level validations (GPS range, capacity range, price range,
/// photo count, etc.) live in `core/utils/validators.dart` and are invoked
/// by the presentation layer.
class RegisterWarehouseUseCase {
  final WarehouseRepository repository;

  const RegisterWarehouseUseCase(this.repository);

  Future<Either<Failure, WarehouseEntity>> call(
    RegisterWarehouseParams params,
  ) {
    if (params.remainingCapacity > params.totalCapacity) {
      return Future.value(
        Left(InvalidRemainingCapacityFailure(
          totalCapacity: params.totalCapacity,
        )),
      );
    }

    final now = DateTime.now().toUtc();
    final entity = WarehouseEntity(
      id: '',
      mitraId: params.mitraId,
      name: params.name,
      address: params.address,
      latitude: params.latitude,
      longitude: params.longitude,
      totalCapacity: params.totalCapacity,
      remainingCapacity: params.remainingCapacity,
      pricePerM3PerDay: params.pricePerM3PerDay,
      temperatureCategory: params.temperatureCategory,
      temperatureThreshold: params.temperatureThreshold,
      photoUrls: params.photoUrls,
      isActive: params.isActive,
      iotNodeId: params.iotNodeId,
      createdAt: now,
      updatedAt: now,
    );
    return repository.registerWarehouse(entity);
  }
}
