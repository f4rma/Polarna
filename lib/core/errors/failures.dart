import 'package:equatable/equatable.dart';

/// Base class for all domain-layer failures.
/// Used with the Either[Failure, Success] pattern from `dartz`.
abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

// ---------------------------------------------------------------------------
// Auth Failures
// ---------------------------------------------------------------------------

/// Parent class for all authentication-related failures.
abstract class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

/// The email address is already registered.
class EmailAlreadyInUseFailure extends AuthFailure {
  const EmailAlreadyInUseFailure()
      : super('Email sudah terdaftar');
}

/// The provided credentials (email/password) are invalid.
class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure()
      : super('Email atau kata sandi tidak valid');
}

/// The account has been locked after too many failed login attempts.
class AccountLockedFailure extends AuthFailure {
  final int remainingMinutes;
  const AccountLockedFailure({this.remainingMinutes = 15})
      : super(
            'Akun dikunci sementara. Coba lagi dalam $remainingMinutes menit');

  @override
  List<Object?> get props => [message, remainingMinutes];
}

/// The user's email address has not been verified.
class EmailNotVerifiedFailure extends AuthFailure {
  const EmailNotVerifiedFailure()
      : super('Silakan verifikasi email Anda terlebih dahulu');
}

/// The password reset link has expired.
class ResetLinkExpiredFailure extends AuthFailure {
  const ResetLinkExpiredFailure()
      : super('Tautan reset telah kedaluwarsa. Silakan minta tautan baru');
}

// ---------------------------------------------------------------------------
// Network Failures
// ---------------------------------------------------------------------------

/// Parent class for all network-related failures.
abstract class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

/// There is no active internet connection.
class NoInternetFailure extends NetworkFailure {
  const NoInternetFailure() : super('Tidak ada koneksi internet');
}

/// A network request timed out.
class TimeoutFailure extends NetworkFailure {
  const TimeoutFailure() : super('Permintaan habis waktu');
}

// ---------------------------------------------------------------------------
// Booking Failures
// ---------------------------------------------------------------------------

/// Parent class for all booking-related failures.
abstract class BookingFailure extends Failure {
  const BookingFailure(super.message);
}

/// The requested volume exceeds the warehouse's remaining capacity.
class InsufficientCapacityFailure extends BookingFailure {
  final double remainingCapacity;
  // ignore: prefer_const_constructors_in_immutables
  InsufficientCapacityFailure({required this.remainingCapacity})
      : super(
            'Kapasitas tidak mencukupi. Sisa kapasitas: $remainingCapacity m³');

  @override
  List<Object?> get props => [message, remainingCapacity];
}

/// The booking start date is invalid (e.g., in the past).
class InvalidDateFailure extends BookingFailure {
  const InvalidDateFailure()
      : super('Tanggal mulai tidak boleh di masa lalu');
}

/// The payment gateway is unavailable or returned an error.
class PaymentGatewayFailure extends BookingFailure {
  const PaymentGatewayFailure()
      : super('Layanan pembayaran tidak tersedia. Silakan coba lagi nanti');
}

// ---------------------------------------------------------------------------
// Telemetry Failures
// ---------------------------------------------------------------------------

/// Parent class for all telemetry-related failures.
abstract class TelemetryFailure extends Failure {
  const TelemetryFailure(super.message);
}

/// The telemetry payload is malformed or contains out-of-range values.
class InvalidPayloadFailure extends TelemetryFailure {
  final List<String> invalidFields;
  InvalidPayloadFailure({required this.invalidFields})
      : super('Payload tidak valid: ${invalidFields.join(', ')}');

  @override
  List<Object?> get props => [message, invalidFields];
}

/// The IoT sensor failed to produce a reading.
class SensorReadFailure extends TelemetryFailure {
  const SensorReadFailure() : super('Gagal membaca sensor');
}

// ---------------------------------------------------------------------------
// Server Failure
// ---------------------------------------------------------------------------

/// A generic server-side failure.
class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Terjadi kesalahan pada server']);
}

/// A generic cache/local-storage failure.
class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Terjadi kesalahan penyimpanan lokal']);
}

// ---------------------------------------------------------------------------
// Warehouse Failures
// ---------------------------------------------------------------------------

/// Parent class for all warehouse-related failures.
abstract class WarehouseFailure extends Failure {
  const WarehouseFailure(super.message);
}

/// The new `remainingCapacity` value exceeds `totalCapacity`.
/// Enforces invariant from Requirement 2.6.
class InvalidRemainingCapacityFailure extends WarehouseFailure {
  final double totalCapacity;
  // ignore: prefer_const_constructors_in_immutables
  InvalidRemainingCapacityFailure({required this.totalCapacity})
      : super(
            'Sisa kapasitas tidak boleh melebihi kapasitas total: $totalCapacity m³');

  @override
  List<Object?> get props => [message, totalCapacity];
}

/// GPS coordinates are outside the Indonesian region (Requirement 2.2).
/// Latitude must be -11° to 6°, longitude 95° to 141°.
class InvalidGpsCoordinatesFailure extends WarehouseFailure {
  const InvalidGpsCoordinatesFailure()
      : super(
            'Koordinat GPS harus berada dalam wilayah Indonesia '
            '(lintang -11° hingga 6°, bujur 95° hingga 141°)');
}

/// Generic catch-all for warehouse input validation errors.
/// `fields` lists the names of fields that failed validation.
class InvalidWarehouseInputFailure extends WarehouseFailure {
  final List<String> fields;
  // ignore: prefer_const_constructors_in_immutables
  InvalidWarehouseInputFailure({required this.fields})
      : super('Data gudang tidak valid: ${fields.join(', ')}');

  @override
  List<Object?> get props => [message, fields];
}
