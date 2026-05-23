import 'package:equatable/equatable.dart';

/// Verification status of a warehouse registration.
///
/// - [pending]  — newly registered, awaiting admin review.
/// - [approved] — approved by admin, visible to UMKM users.
/// - [rejected] — rejected by admin.
enum VerificationStatus {
  pending,
  approved,
  rejected;

  /// Serializes to the Firestore-canonical string.
  String toStorageString() => name;

  /// Parses the Firestore-canonical string back to the enum.
  ///
  /// Defaults to [approved] for backward compatibility with existing documents
  /// that don't have this field.
  static VerificationStatus fromString(String? value) {
    if (value == null) return VerificationStatus.approved;
    for (final s in VerificationStatus.values) {
      if (s.name == value) return s;
    }
    return VerificationStatus.approved;
  }
}

/// Temperature category of a cold-storage warehouse.
///
/// - [frozen]  — frozen storage, typically below -18°C.
/// - [chilled] — chilled storage, typically between 0°C and 8°C.
enum TemperatureCategory {
  frozen,
  chilled;

  /// Serializes to the Firestore-canonical string ("frozen" | "chilled").
  String toStorageString() => name;

  /// Parses the Firestore-canonical string back to the enum.
  ///
  /// Throws [ArgumentError] if [value] is not a known category.
  static TemperatureCategory fromString(String value) {
    for (final c in TemperatureCategory.values) {
      if (c.name == value) return c;
    }
    throw ArgumentError.value(
      value,
      'value',
      'Unknown TemperatureCategory. Expected one of: '
          '${TemperatureCategory.values.map((e) => e.name).join(', ')}',
    );
  }
}

/// Immutable domain entity representing a cold-storage warehouse.
///
/// Mirrors the `warehouses/{warehouseId}` document in Cloud Firestore
/// (see design.md §Data Models), except `location` is decomposed into
/// [latitude] and [longitude] so the domain layer stays free of
/// Firestore-specific types (e.g. `GeoPoint`).
class WarehouseEntity extends Equatable {
  final String id;
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
  final VerificationStatus verificationStatus;
  final String? iotNodeId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WarehouseEntity({
    required this.id,
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
    required this.isActive,
    this.verificationStatus = VerificationStatus.approved,
    required this.iotNodeId,
    required this.createdAt,
    required this.updatedAt,
  });

  WarehouseEntity copyWith({
    String? id,
    String? mitraId,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    double? totalCapacity,
    double? remainingCapacity,
    double? pricePerM3PerDay,
    TemperatureCategory? temperatureCategory,
    double? temperatureThreshold,
    List<String>? photoUrls,
    bool? isActive,
    VerificationStatus? verificationStatus,
    String? iotNodeId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WarehouseEntity(
      id: id ?? this.id,
      mitraId: mitraId ?? this.mitraId,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      totalCapacity: totalCapacity ?? this.totalCapacity,
      remainingCapacity: remainingCapacity ?? this.remainingCapacity,
      pricePerM3PerDay: pricePerM3PerDay ?? this.pricePerM3PerDay,
      temperatureCategory: temperatureCategory ?? this.temperatureCategory,
      temperatureThreshold: temperatureThreshold ?? this.temperatureThreshold,
      photoUrls: photoUrls ?? this.photoUrls,
      isActive: isActive ?? this.isActive,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      iotNodeId: iotNodeId ?? this.iotNodeId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
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
        verificationStatus,
        iotNodeId,
        createdAt,
        updatedAt,
      ];
}
