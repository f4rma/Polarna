import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firebase_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/warehouse_entity.dart';

/// Data-layer representation of a warehouse, coupled to Firestore.
///
/// Extends [WarehouseEntity] so it can be returned directly from the
/// repository without a manual `toEntity()` call — the domain layer still
/// only depends on the base entity interface.
///
/// The mapping to/from the Firestore document follows the schema defined
/// in `design.md §Data Models` for `warehouses/{warehouseId}`:
///   - `location` (GeoPoint) ↔ [latitude] + [longitude]
///   - `temperatureCategory` (String) ↔ [temperatureCategory] enum
///   - `createdAt` / `updatedAt` (Timestamp, UTC) ↔ DateTime (UTC)
class WarehouseModel extends WarehouseEntity {
  const WarehouseModel({
    required super.id,
    required super.mitraId,
    required super.name,
    required super.address,
    required super.latitude,
    required super.longitude,
    required super.totalCapacity,
    required super.remainingCapacity,
    required super.pricePerM3PerDay,
    required super.temperatureCategory,
    required super.temperatureThreshold,
    required super.photoUrls,
    required super.isActive,
    super.verificationStatus,
    required super.iotNodeId,
    required super.createdAt,
    required super.updatedAt,
  });

  // ---------------------------------------------------------------------------
  // Factories
  // ---------------------------------------------------------------------------

  /// Builds a [WarehouseModel] from a Firestore `warehouses/{id}` document.
  ///
  /// Throws [WarehouseNotFoundException] when the document does not exist
  /// and [ServerException] when a required field is missing or has an
  /// unexpected type.  Optional fields (`iotNodeId`) are tolerated.
  factory WarehouseModel.fromFirestore(DocumentSnapshot<Object?> doc) {
    final data = doc.data();
    if (data == null || data is! Map<String, dynamic>) {
      throw const WarehouseNotFoundException();
    }
    try {
      final loc = data[FirebaseConstants.fieldLocation] as GeoPoint;
      final totalCap = (data[FirebaseConstants.fieldTotalCapacity] as num).toDouble();
      return WarehouseModel(
        id: doc.id,
        mitraId: data[FirebaseConstants.fieldMitraId] as String,
        name: data[FirebaseConstants.fieldName] as String,
        address: data[FirebaseConstants.fieldAddress] as String,
        latitude: loc.latitude,
        longitude: loc.longitude,
        totalCapacity: totalCap,
        remainingCapacity:
            (data[FirebaseConstants.fieldRemainingCapacity] as num?)?.toDouble() ?? totalCap,
        pricePerM3PerDay:
            (data[FirebaseConstants.fieldPricePerM3PerDay] as num).toDouble(),
        temperatureCategory: TemperatureCategory.fromString(
          data[FirebaseConstants.fieldTemperatureCategory] as String,
        ),
        temperatureThreshold:
            (data[FirebaseConstants.fieldTemperatureThreshold] as num?)
                ?.toDouble() ?? -18.0,
        photoUrls: List<String>.from(
          (data[FirebaseConstants.fieldPhotoUrls] as List<dynamic>?) ??
              const <dynamic>[],
        ),
        isActive:
            (data[FirebaseConstants.fieldIsActiveWarehouse] as bool?) ?? true,
        verificationStatus: VerificationStatus.fromString(
          data[FirebaseConstants.fieldVerificationStatus] as String?,
        ),
        iotNodeId: data[FirebaseConstants.fieldIotNodeId] as String?,
        createdAt: (data[FirebaseConstants.fieldCreatedAt] as Timestamp)
            .toDate()
            .toUtc(),
        updatedAt: (data[FirebaseConstants.fieldUpdatedAt] as Timestamp)
            .toDate()
            .toUtc(),
      );
    } on TypeError catch (e) {
      throw ServerException('Skema dokumen gudang tidak valid: $e');
    } on ArgumentError catch (e) {
      throw ServerException('Data gudang tidak valid: ${e.message}');
    }
  }

  /// Copy-constructor from a plain domain [WarehouseEntity].
  factory WarehouseModel.fromEntity(WarehouseEntity e) {
    return WarehouseModel(
      id: e.id,
      mitraId: e.mitraId,
      name: e.name,
      address: e.address,
      latitude: e.latitude,
      longitude: e.longitude,
      totalCapacity: e.totalCapacity,
      remainingCapacity: e.remainingCapacity,
      pricePerM3PerDay: e.pricePerM3PerDay,
      temperatureCategory: e.temperatureCategory,
      temperatureThreshold: e.temperatureThreshold,
      photoUrls: List<String>.from(e.photoUrls),
      isActive: e.isActive,
      verificationStatus: e.verificationStatus,
      iotNodeId: e.iotNodeId,
      createdAt: e.createdAt,
      updatedAt: e.updatedAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  /// Serialises this model into a Firestore-ready map for **initial
  /// document creation**.  Partial updates should use [toUpdateMap] so we
  /// never accidentally overwrite `createdAt`, `id`, or `mitraId`.
  Map<String, dynamic> toFirestore() {
    return {
      FirebaseConstants.fieldMitraId: mitraId,
      FirebaseConstants.fieldName: name,
      FirebaseConstants.fieldAddress: address,
      FirebaseConstants.fieldLocation: GeoPoint(latitude, longitude),
      FirebaseConstants.fieldTotalCapacity: totalCapacity,
      FirebaseConstants.fieldRemainingCapacity: remainingCapacity,
      FirebaseConstants.fieldPricePerM3PerDay: pricePerM3PerDay,
      FirebaseConstants.fieldTemperatureCategory:
          temperatureCategory.toStorageString(),
      FirebaseConstants.fieldTemperatureThreshold: temperatureThreshold,
      FirebaseConstants.fieldPhotoUrls: photoUrls,
      FirebaseConstants.fieldIsActiveWarehouse: isActive,
      FirebaseConstants.fieldVerificationStatus:
          verificationStatus.toStorageString(),
      FirebaseConstants.fieldIotNodeId: iotNodeId,
      FirebaseConstants.fieldCreatedAt: Timestamp.fromDate(createdAt),
      FirebaseConstants.fieldUpdatedAt: Timestamp.fromDate(updatedAt),
    };
  }

  /// Serialises this model into a partial-update payload.
  ///
  /// Excludes immutable fields (`id`, `mitraId`, `createdAt`) and always
  /// refreshes [updatedAt] using `FieldValue.serverTimestamp()` so the
  /// server remains the single source of truth for that field.
  Map<String, dynamic> toUpdateMap() {
    return {
      FirebaseConstants.fieldName: name,
      FirebaseConstants.fieldAddress: address,
      FirebaseConstants.fieldLocation: GeoPoint(latitude, longitude),
      FirebaseConstants.fieldTotalCapacity: totalCapacity,
      FirebaseConstants.fieldRemainingCapacity: remainingCapacity,
      FirebaseConstants.fieldPricePerM3PerDay: pricePerM3PerDay,
      FirebaseConstants.fieldTemperatureCategory:
          temperatureCategory.toStorageString(),
      FirebaseConstants.fieldTemperatureThreshold: temperatureThreshold,
      FirebaseConstants.fieldPhotoUrls: photoUrls,
      FirebaseConstants.fieldIsActiveWarehouse: isActive,
      FirebaseConstants.fieldVerificationStatus:
          verificationStatus.toStorageString(),
      FirebaseConstants.fieldIotNodeId: iotNodeId,
      FirebaseConstants.fieldUpdatedAt: FieldValue.serverTimestamp(),
    };
  }
}
