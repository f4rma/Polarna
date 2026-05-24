import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firebase_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/booking_entity.dart';

/// Data-layer representation of a booking, coupled to Firestore.
///
/// Extends [BookingEntity] so it can be returned directly from the
/// repository without a manual `toEntity()` call — the domain layer still
/// only depends on the base entity interface.
///
/// The mapping to/from the Firestore document follows the schema defined
/// in `design.md §Data Models` for `bookings/{bookingId}`.
class BookingModel extends BookingEntity {
  const BookingModel({
    required super.id,
    required super.umkmId,
    required super.warehouseId,
    required super.warehouseName,
    required super.volumeM3,
    required super.startDate,
    required super.endDate,
    required super.durationDays,
    required super.pricePerM3PerDay,
    required super.totalCost,
    required super.status,
    required super.paymentStatus,
    required super.qrCodeData,
    required super.createdAt,
    required super.updatedAt,
  });

  // ---------------------------------------------------------------------------
  // Factories
  // ---------------------------------------------------------------------------

  /// Builds a [BookingModel] from a Firestore `bookings/{id}` document.
  ///
  /// Throws [ServerException] when the document does not exist or a
  /// required field is missing / has an unexpected type.
  factory BookingModel.fromFirestore(DocumentSnapshot<Object?> doc) {
    final data = doc.data();
    if (data == null || data is! Map<String, dynamic>) {
      throw const ServerException('Dokumen booking tidak ditemukan');
    }
    try {
      return BookingModel(
        id: doc.id,
        umkmId: data[FirebaseConstants.fieldUmkmId] as String,
        warehouseId: data[FirebaseConstants.fieldWarehouseId] as String,
        warehouseName: data[FirebaseConstants.fieldWarehouseName] as String,
        volumeM3: (data[FirebaseConstants.fieldVolumeM3] as num).toDouble(),
        startDate:
            (data[FirebaseConstants.fieldStartDate] as Timestamp).toDate().toUtc(),
        endDate:
            (data[FirebaseConstants.fieldEndDate] as Timestamp).toDate().toUtc(),
        durationDays: (data[FirebaseConstants.fieldDurationDays] as num).toInt(),
        pricePerM3PerDay:
            (data[FirebaseConstants.fieldPriceSnapshot] as num).toDouble(),
        totalCost: (data[FirebaseConstants.fieldTotalCost] as num).toDouble(),
        status: BookingStatus.fromString(
          data[FirebaseConstants.fieldStatus] as String,
        ),
        paymentStatus: PaymentStatus.fromString(
          data[FirebaseConstants.fieldPaymentStatus] as String,
        ),
        qrCodeData: data[FirebaseConstants.fieldQrCodeData] as String?,
        createdAt:
            (data[FirebaseConstants.fieldCreatedAt] as Timestamp).toDate().toUtc(),
        updatedAt:
            (data[FirebaseConstants.fieldUpdatedAt] as Timestamp).toDate().toUtc(),
      );
    } on TypeError catch (e) {
      throw ServerException('Skema dokumen booking tidak valid: $e');
    } on ArgumentError catch (e) {
      throw ServerException('Data booking tidak valid: ${e.message}');
    }
  }

  /// Copy-constructor from a plain domain [BookingEntity].
  factory BookingModel.fromEntity(BookingEntity e) {
    return BookingModel(
      id: e.id,
      umkmId: e.umkmId,
      warehouseId: e.warehouseId,
      warehouseName: e.warehouseName,
      volumeM3: e.volumeM3,
      startDate: e.startDate,
      endDate: e.endDate,
      durationDays: e.durationDays,
      pricePerM3PerDay: e.pricePerM3PerDay,
      totalCost: e.totalCost,
      status: e.status,
      paymentStatus: e.paymentStatus,
      qrCodeData: e.qrCodeData,
      createdAt: e.createdAt,
      updatedAt: e.updatedAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  /// Serialises this model into a Firestore-ready map for document creation.
  Map<String, dynamic> toFirestore() {
    return {
      FirebaseConstants.fieldUmkmId: umkmId,
      FirebaseConstants.fieldWarehouseId: warehouseId,
      FirebaseConstants.fieldWarehouseName: warehouseName,
      FirebaseConstants.fieldVolumeM3: volumeM3,
      FirebaseConstants.fieldStartDate: Timestamp.fromDate(startDate),
      FirebaseConstants.fieldEndDate: Timestamp.fromDate(endDate),
      FirebaseConstants.fieldDurationDays: durationDays,
      FirebaseConstants.fieldPriceSnapshot: pricePerM3PerDay,
      FirebaseConstants.fieldTotalCost: totalCost,
      FirebaseConstants.fieldStatus: status.toStorageString(),
      FirebaseConstants.fieldPaymentStatus: paymentStatus.toStorageString(),
      FirebaseConstants.fieldQrCodeData: qrCodeData,
      FirebaseConstants.fieldCreatedAt: Timestamp.fromDate(createdAt),
      FirebaseConstants.fieldUpdatedAt: Timestamp.fromDate(updatedAt),
    };
  }
}
