import 'package:equatable/equatable.dart';

import 'warehouse_entity.dart';

/// Filter parameters for [WarehouseRepository.searchWarehouses].
///
/// All fields are optional; leaving a field `null` means "no constraint".
/// Per Requirement 3.2, [radiusKm] is expected to be one of
/// 5, 10, 25, or 50 km when provided, but the domain entity does not
/// enforce this so new UI presets remain easy to add.
class WarehouseSearchFilter extends Equatable {
  /// Center latitude for radius-based search.
  final double? centerLatitude;

  /// Center longitude for radius-based search.
  final double? centerLongitude;

  /// Search radius in kilometers (typically 5, 10, 25, or 50).
  final double? radiusKm;

  /// Restrict to a single temperature category (frozen | chilled).
  final TemperatureCategory? category;

  /// Minimum remaining capacity in m³ that a warehouse must offer.
  final double? minCapacityM3;

  /// Maximum price per m³ per day in Rupiah.
  final double? maxPricePerM3;

  /// Minimum price per m³ per day in Rupiah.
  final double? minPricePerM3;

  const WarehouseSearchFilter({
    this.centerLatitude,
    this.centerLongitude,
    this.radiusKm,
    this.category,
    this.minCapacityM3,
    this.maxPricePerM3,
    this.minPricePerM3,
  });

  WarehouseSearchFilter copyWith({
    double? centerLatitude,
    double? centerLongitude,
    double? radiusKm,
    TemperatureCategory? category,
    double? minCapacityM3,
    double? maxPricePerM3,
    double? minPricePerM3,
  }) {
    return WarehouseSearchFilter(
      centerLatitude: centerLatitude ?? this.centerLatitude,
      centerLongitude: centerLongitude ?? this.centerLongitude,
      radiusKm: radiusKm ?? this.radiusKm,
      category: category ?? this.category,
      minCapacityM3: minCapacityM3 ?? this.minCapacityM3,
      maxPricePerM3: maxPricePerM3 ?? this.maxPricePerM3,
      minPricePerM3: minPricePerM3 ?? this.minPricePerM3,
    );
  }

  @override
  List<Object?> get props => [
        centerLatitude,
        centerLongitude,
        radiusKm,
        category,
        minCapacityM3,
        maxPricePerM3,
        minPricePerM3,
      ];
}
