import 'package:equatable/equatable.dart';

/// Lifecycle status of a booking.
///
/// - [pending]   — booking record created but not yet paid.
/// - [paid]      — payment captured, awaiting check-in at warehouse.
/// - [active]    — Mitra scanned check-in QR, goods are in storage.
/// - [completed] — Mitra scanned check-out QR, capacity returned.
/// - [cancelled] — booking aborted (payment failed, user cancelled, etc.).
enum BookingStatus {
  pending,
  paid,
  active,
  completed,
  cancelled;

  /// Canonical storage representation (used by Firestore).
  String toStorageString() => name;

  /// Parses a stored string (case-insensitive, trimmed) into a [BookingStatus].
  ///
  /// Throws [ArgumentError] on unknown values so callers are forced to
  /// handle data-corruption explicitly.
  static BookingStatus fromString(String value) {
    final normalized = value.trim().toLowerCase();
    for (final s in BookingStatus.values) {
      if (s.name == normalized) return s;
    }
    throw ArgumentError.value(
      value,
      'value',
      'Unknown BookingStatus. Expected one of: '
          '${BookingStatus.values.map((e) => e.name).join(', ')}',
    );
  }
}

/// Payment lifecycle of a booking, tracked separately from [BookingStatus].
///
/// - [unpaid]   — transaction created, payment not yet captured.
/// - [paid]     — Payment_Gateway confirmed successful capture.
/// - [refunded] — funds returned to the UMKM (e.g. cancellation flow).
enum PaymentStatus {
  unpaid,
  paid,
  refunded;

  /// Canonical storage representation (used by Firestore).
  String toStorageString() => name;

  /// Parses a stored string (case-insensitive, trimmed) into a [PaymentStatus].
  ///
  /// Throws [ArgumentError] on unknown values.
  static PaymentStatus fromString(String value) {
    final normalized = value.trim().toLowerCase();
    for (final s in PaymentStatus.values) {
      if (s.name == normalized) return s;
    }
    throw ArgumentError.value(
      value,
      'value',
      'Unknown PaymentStatus. Expected one of: '
          '${PaymentStatus.values.map((e) => e.name).join(', ')}',
    );
  }
}

/// Immutable domain entity representing a UMKM ↔ warehouse booking.
///
/// Mirrors the `bookings/{bookingId}` document in Cloud Firestore
/// (see design.md §Data Models).
///
/// - [pricePerM3PerDay] is a **snapshot** of the warehouse price at the
///   moment of booking, so later price changes on the warehouse do not
///   retroactively affect this record (Requirement 4.5a).
/// - [totalCost] is computed as `volumeM3 × pricePerM3PerDay × durationDays`
///   with **no undocumented rounding** (Requirement 4.2).
/// - [qrCodeData] is populated only after a successful booking is activated
///   (Requirement 4.5b); it is null during the `pending` state.
class BookingEntity extends Equatable {
  final String id;
  final String umkmId;
  final String warehouseId;
  final String warehouseName;
  final double volumeM3;
  final DateTime startDate;
  final DateTime endDate;
  final int durationDays;
  final double pricePerM3PerDay;
  final double totalCost;
  final BookingStatus status;
  final PaymentStatus paymentStatus;
  final String? qrCodeData;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BookingEntity({
    required this.id,
    required this.umkmId,
    required this.warehouseId,
    required this.warehouseName,
    required this.volumeM3,
    required this.startDate,
    required this.endDate,
    required this.durationDays,
    required this.pricePerM3PerDay,
    required this.totalCost,
    required this.status,
    required this.paymentStatus,
    required this.qrCodeData,
    required this.createdAt,
    required this.updatedAt,
  });

  BookingEntity copyWith({
    String? id,
    String? umkmId,
    String? warehouseId,
    String? warehouseName,
    double? volumeM3,
    DateTime? startDate,
    DateTime? endDate,
    int? durationDays,
    double? pricePerM3PerDay,
    double? totalCost,
    BookingStatus? status,
    PaymentStatus? paymentStatus,
    String? qrCodeData,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BookingEntity(
      id: id ?? this.id,
      umkmId: umkmId ?? this.umkmId,
      warehouseId: warehouseId ?? this.warehouseId,
      warehouseName: warehouseName ?? this.warehouseName,
      volumeM3: volumeM3 ?? this.volumeM3,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      durationDays: durationDays ?? this.durationDays,
      pricePerM3PerDay: pricePerM3PerDay ?? this.pricePerM3PerDay,
      totalCost: totalCost ?? this.totalCost,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      qrCodeData: qrCodeData ?? this.qrCodeData,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        umkmId,
        warehouseId,
        warehouseName,
        volumeM3,
        startDate,
        endDate,
        durationDays,
        pricePerM3PerDay,
        totalCost,
        status,
        paymentStatus,
        qrCodeData,
        createdAt,
        updatedAt,
      ];
}
