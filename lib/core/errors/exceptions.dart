// Custom exceptions for the ColdShare Platform.
// These are thrown by data sources and caught by repository implementations,
// which convert them into [Failure] objects for the domain layer.

/// Base class for all custom exceptions.
abstract class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

// ---------------------------------------------------------------------------
// Auth Exceptions
// ---------------------------------------------------------------------------

/// Thrown when attempting to register with an already-registered email.
class EmailAlreadyInUseException extends AppException {
  const EmailAlreadyInUseException()
      : super('Email sudah terdaftar');
}

/// Thrown when email or password credentials are invalid.
class InvalidCredentialsException extends AppException {
  const InvalidCredentialsException()
      : super('Email atau kata sandi tidak valid');
}

/// Thrown when the account has been locked due to too many failed attempts.
class AccountLockedException extends AppException {
  final int remainingMinutes;
  const AccountLockedException({this.remainingMinutes = 15})
      : super('Akun dikunci sementara. Coba lagi dalam $remainingMinutes menit');
}

/// Thrown when the user's email has not been verified.
class EmailNotVerifiedException extends AppException {
  const EmailNotVerifiedException()
      : super('Silakan verifikasi email Anda terlebih dahulu');
}

/// Thrown when a password reset link has expired.
class ResetLinkExpiredException extends AppException {
  const ResetLinkExpiredException()
      : super('Tautan reset telah kedaluwarsa. Silakan minta tautan baru');
}

// ---------------------------------------------------------------------------
// Network Exceptions
// ---------------------------------------------------------------------------

/// Thrown when there is no internet connection.
class NoInternetException extends AppException {
  const NoInternetException() : super('Tidak ada koneksi internet');
}

/// Thrown when a network request times out.
class TimeoutException extends AppException {
  const TimeoutException() : super('Permintaan habis waktu');
}

// ---------------------------------------------------------------------------
// Booking Exceptions
// ---------------------------------------------------------------------------

/// Thrown when the requested volume exceeds available warehouse capacity.
class InsufficientCapacityException extends AppException {
  final double remainingCapacity;
  InsufficientCapacityException({required this.remainingCapacity})
      : super(
            'Kapasitas tidak mencukupi. Sisa kapasitas: $remainingCapacity m³');
}

/// Thrown when a booking date is invalid (e.g., in the past).
class InvalidDateException extends AppException {
  const InvalidDateException()
      : super('Tanggal mulai tidak boleh di masa lalu');
}

/// Thrown when the payment gateway is unavailable or fails.
class PaymentGatewayException extends AppException {
  const PaymentGatewayException()
      : super('Layanan pembayaran tidak tersedia. Silakan coba lagi nanti');
}

// ---------------------------------------------------------------------------
// Telemetry Exceptions
// ---------------------------------------------------------------------------

/// Thrown when a telemetry payload is malformed or out of range.
class InvalidPayloadException extends AppException {
  final List<String> invalidFields;
  InvalidPayloadException({required this.invalidFields})
      : super('Payload tidak valid: ${invalidFields.join(', ')}');
}

/// Thrown when the sensor fails to produce a reading.
class SensorReadException extends AppException {
  const SensorReadException() : super('Gagal membaca sensor');
}

// ---------------------------------------------------------------------------
// Warehouse Exceptions
// ---------------------------------------------------------------------------

/// Thrown by the data layer when a `remainingCapacity` update would violate
/// the invariant `remainingCapacity <= totalCapacity` (Requirement 2.6).
/// [totalCapacity] is the current stored capacity, which the repository
/// layer surfaces in the resulting [Failure].
class InvalidRemainingCapacityException extends AppException {
  final double totalCapacity;
  InvalidRemainingCapacityException({required this.totalCapacity})
      : super(
            'Sisa kapasitas tidak boleh melebihi kapasitas total: $totalCapacity m³');
}

/// Thrown when a warehouse document cannot be located (deleted, missing id).
class WarehouseNotFoundException extends AppException {
  const WarehouseNotFoundException()
      : super('Gudang tidak ditemukan');
}

// ---------------------------------------------------------------------------
// Server / Generic Exceptions
// ---------------------------------------------------------------------------

/// Thrown for unexpected server-side errors.
class ServerException extends AppException {
  const ServerException([super.message = 'Terjadi kesalahan pada server']);
}

/// Thrown when a Firestore or storage operation fails.
class CacheException extends AppException {
  const CacheException(
      [super.message = 'Terjadi kesalahan penyimpanan lokal']);
}
