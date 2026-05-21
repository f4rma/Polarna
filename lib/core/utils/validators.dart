import '../constants/app_constants.dart';

/// Validation result returned by all validator functions.
class ValidationResult {
  /// `true` if the value is valid.
  final bool isValid;

  /// Human-readable error message when [isValid] is `false`; `null` otherwise.
  final String? errorMessage;

  const ValidationResult.valid()
      : isValid = true,
        errorMessage = null;

  const ValidationResult.invalid(this.errorMessage) : isValid = false;
}

/// Collection of input validation functions for the ColdShare Platform.
///
/// All functions return a [ValidationResult] so callers can display
/// field-specific error messages.
class Validators {
  Validators._();

  // ---------------------------------------------------------------------------
  // Email — RFC 5321, max 254 characters
  // ---------------------------------------------------------------------------

  /// Validates an email address.
  /// Rules: RFC 5321 format, maximum 254 characters.
  static ValidationResult validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return const ValidationResult.invalid('Email tidak boleh kosong');
    }
    final trimmed = value.trim();
    if (trimmed.length > AppConstants.maxEmailLength) {
      return ValidationResult.invalid(
          'Email tidak boleh lebih dari ${AppConstants.maxEmailLength} karakter');
    }
    // RFC 5321 basic regex: local@domain.tld
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&' "'" r'*+/=?^_`{|}~-]+'
      r'@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?'
      r'(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*'
      r'\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(trimmed)) {
      return const ValidationResult.invalid('Format email tidak valid');
    }
    return const ValidationResult.valid();
  }

  // ---------------------------------------------------------------------------
  // Password — 8–64 chars, ≥1 uppercase, ≥1 digit
  // ---------------------------------------------------------------------------

  /// Validates a password.
  /// Rules: 8–64 characters, at least 1 uppercase letter, at least 1 digit.
  static ValidationResult validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return const ValidationResult.invalid('Kata sandi tidak boleh kosong');
    }
    if (value.length < AppConstants.minPasswordLength) {
      return ValidationResult.invalid(
          'Kata sandi minimal ${AppConstants.minPasswordLength} karakter');
    }
    if (value.length > AppConstants.maxPasswordLength) {
      return ValidationResult.invalid(
          'Kata sandi maksimal ${AppConstants.maxPasswordLength} karakter');
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return const ValidationResult.invalid(
          'Kata sandi harus mengandung minimal 1 huruf kapital');
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return const ValidationResult.invalid(
          'Kata sandi harus mengandung minimal 1 angka');
    }
    return const ValidationResult.valid();
  }

  // ---------------------------------------------------------------------------
  // Full Name — max 100 characters
  // ---------------------------------------------------------------------------

  /// Validates a full name.
  /// Rules: not empty, maximum 100 characters.
  static ValidationResult validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return const ValidationResult.invalid('Nama lengkap tidak boleh kosong');
    }
    if (value.trim().length > AppConstants.maxFullNameLength) {
      return ValidationResult.invalid(
          'Nama lengkap maksimal ${AppConstants.maxFullNameLength} karakter');
    }
    return const ValidationResult.valid();
  }

  // ---------------------------------------------------------------------------
  // Phone — E.164 format, max 15 digits
  // ---------------------------------------------------------------------------

  /// Validates a phone number.
  /// Rules: E.164 format (+[country code][number]), maximum 15 digits total.
  static ValidationResult validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return const ValidationResult.invalid(
          'Nomor telepon tidak boleh kosong');
    }
    final trimmed = value.trim();
    // E.164: starts with +, followed by 1–15 digits
    final e164Regex = RegExp(r'^\+[1-9]\d{1,14}$');
    if (!e164Regex.hasMatch(trimmed)) {
      return const ValidationResult.invalid(
          'Format nomor telepon tidak valid (gunakan format E.164, contoh: +6281234567890)');
    }
    // Count digits only (excluding the leading +)
    final digits = trimmed.substring(1);
    if (digits.length > AppConstants.maxPhoneDigits) {
      return ValidationResult.invalid(
          'Nomor telepon maksimal ${AppConstants.maxPhoneDigits} digit');
    }
    return const ValidationResult.valid();
  }

  // ---------------------------------------------------------------------------
  // GPS Coordinates — Indonesia bounds
  // ---------------------------------------------------------------------------

  /// Validates a GPS latitude value for Indonesia.
  /// Rules: -11° ≤ latitude ≤ 6°
  static ValidationResult validateLatitude(double? value) {
    if (value == null) {
      return const ValidationResult.invalid('Latitude tidak boleh kosong');
    }
    if (value < AppConstants.indonesiaMinLatitude ||
        value > AppConstants.indonesiaMaxLatitude) {
      return ValidationResult.invalid(
          'Latitude harus berada dalam rentang wilayah Indonesia '
          '(${AppConstants.indonesiaMinLatitude}° hingga ${AppConstants.indonesiaMaxLatitude}°)');
    }
    return const ValidationResult.valid();
  }

  /// Validates a GPS longitude value for Indonesia.
  /// Rules: 95° ≤ longitude ≤ 141°
  static ValidationResult validateLongitude(double? value) {
    if (value == null) {
      return const ValidationResult.invalid('Longitude tidak boleh kosong');
    }
    if (value < AppConstants.indonesiaMinLongitude ||
        value > AppConstants.indonesiaMaxLongitude) {
      return ValidationResult.invalid(
          'Longitude harus berada dalam rentang wilayah Indonesia '
          '(${AppConstants.indonesiaMinLongitude}° hingga ${AppConstants.indonesiaMaxLongitude}°)');
    }
    return const ValidationResult.valid();
  }

  /// Validates both latitude and longitude for Indonesia.
  /// Returns the first invalid result, or [ValidationResult.valid] if both pass.
  static ValidationResult validateGpsCoordinates(
      double? latitude, double? longitude) {
    final latResult = validateLatitude(latitude);
    if (!latResult.isValid) return latResult;
    return validateLongitude(longitude);
  }

  // ---------------------------------------------------------------------------
  // Warehouse Capacity — 1 to 999,999 m³
  // ---------------------------------------------------------------------------

  /// Validates warehouse total capacity.
  /// Rules: 1 ≤ capacity ≤ 999,999 m³
  static ValidationResult validateWarehouseCapacity(double? value) {
    if (value == null) {
      return const ValidationResult.invalid('Kapasitas tidak boleh kosong');
    }
    if (value < AppConstants.minWarehouseCapacityM3 ||
        value > AppConstants.maxWarehouseCapacityM3) {
      return ValidationResult.invalid(
          'Kapasitas harus antara ${AppConstants.minWarehouseCapacityM3.toInt()} '
          'dan ${AppConstants.maxWarehouseCapacityM3.toInt()} m³');
    }
    return const ValidationResult.valid();
  }

  // ---------------------------------------------------------------------------
  // Warehouse Price — 1,000 to 999,999,999 Rp
  // ---------------------------------------------------------------------------

  /// Validates warehouse price per m³ per day.
  /// Rules: 1,000 ≤ price ≤ 999,999,999 Rp
  static ValidationResult validateWarehousePrice(double? value) {
    if (value == null) {
      return const ValidationResult.invalid('Harga tidak boleh kosong');
    }
    if (value < AppConstants.minWarehousePriceRp ||
        value > AppConstants.maxWarehousePriceRp) {
      return ValidationResult.invalid(
          'Harga harus antara Rp ${AppConstants.minWarehousePriceRp.toInt()} '
          'dan Rp ${AppConstants.maxWarehousePriceRp.toInt()} per m³ per hari');
    }
    return const ValidationResult.valid();
  }

  // ---------------------------------------------------------------------------
  // Temperature Threshold — -40 to +30°C, 0.1 precision
  // ---------------------------------------------------------------------------

  /// Validates a temperature threshold set by a Mitra.
  /// Rules: -40.0 ≤ threshold ≤ +30.0°C, precision 0.1°C
  static ValidationResult validateTemperatureThreshold(double? value) {
    if (value == null) {
      return const ValidationResult.invalid(
          'Threshold suhu tidak boleh kosong');
    }
    if (value < AppConstants.minTemperatureThreshold ||
        value > AppConstants.maxTemperatureThreshold) {
      return ValidationResult.invalid(
          'Threshold suhu harus antara ${AppConstants.minTemperatureThreshold}°C '
          'dan ${AppConstants.maxTemperatureThreshold}°C');
    }
    // Check 0.1 precision: the value rounded to 1 decimal must equal itself
    final rounded = double.parse(value.toStringAsFixed(1));
    if ((rounded - value).abs() > 1e-9) {
      return const ValidationResult.invalid(
          'Threshold suhu harus memiliki presisi 0,1°C');
    }
    return const ValidationResult.valid();
  }

  // ---------------------------------------------------------------------------
  // Sensor Temperature — -40 to +80°C
  // ---------------------------------------------------------------------------

  /// Validates a sensor temperature reading.
  /// Rules: -40.0 ≤ temperature ≤ +80.0°C
  static ValidationResult validateSensorTemperature(double? value) {
    if (value == null) {
      return const ValidationResult.invalid('Nilai suhu tidak boleh kosong');
    }
    if (value < AppConstants.minSensorTemperature ||
        value > AppConstants.maxSensorTemperature) {
      return ValidationResult.invalid(
          'Nilai suhu sensor harus antara ${AppConstants.minSensorTemperature}°C '
          'dan ${AppConstants.maxSensorTemperature}°C');
    }
    return const ValidationResult.valid();
  }

  // ---------------------------------------------------------------------------
  // Sensor Humidity — 0 to 100%
  // ---------------------------------------------------------------------------

  /// Validates a sensor humidity reading.
  /// Rules: 0.0 ≤ humidity ≤ 100.0%
  static ValidationResult validateSensorHumidity(double? value) {
    if (value == null) {
      return const ValidationResult.invalid(
          'Nilai kelembapan tidak boleh kosong');
    }
    if (value < AppConstants.minSensorHumidity ||
        value > AppConstants.maxSensorHumidity) {
      return ValidationResult.invalid(
          'Nilai kelembapan sensor harus antara ${AppConstants.minSensorHumidity}% '
          'dan ${AppConstants.maxSensorHumidity}%');
    }
    return const ValidationResult.valid();
  }

  // ---------------------------------------------------------------------------
  // Booking Volume — multiples of 0.5, 0.5–500 m³
  // ---------------------------------------------------------------------------

  /// Validates a booking volume.
  /// Rules: 0.5 ≤ volume ≤ 500 m³, must be a multiple of 0.5
  static ValidationResult validateBookingVolume(double? value) {
    if (value == null) {
      return const ValidationResult.invalid('Volume tidak boleh kosong');
    }
    if (value < 0.5 || value > 500.0) {
      return const ValidationResult.invalid(
          'Volume harus antara 0,5 m³ dan 500 m³');
    }
    // Check multiple of 0.5: (value / 0.5) must be an integer
    final remainder = (value * 10).round() % 5;
    if (remainder != 0) {
      return const ValidationResult.invalid(
          'Volume harus merupakan kelipatan 0,5 m³');
    }
    return const ValidationResult.valid();
  }

  // ---------------------------------------------------------------------------
  // Booking Duration — 1–365 days
  // ---------------------------------------------------------------------------

  /// Validates a booking duration.
  /// Rules: 1 ≤ duration ≤ 365 days
  static ValidationResult validateBookingDuration(int? value) {
    if (value == null) {
      return const ValidationResult.invalid('Durasi tidak boleh kosong');
    }
    if (value < 1 || value > 365) {
      return const ValidationResult.invalid(
          'Durasi sewa harus antara 1 dan 365 hari');
    }
    return const ValidationResult.valid();
  }

  // ---------------------------------------------------------------------------
  // Warehouse Name — max 100 characters
  // ---------------------------------------------------------------------------

  /// Validates a warehouse name.
  /// Rules: not empty, maximum 100 characters.
  static ValidationResult validateWarehouseName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return const ValidationResult.invalid('Nama gudang tidak boleh kosong');
    }
    if (value.trim().length > AppConstants.maxWarehouseNameLength) {
      return ValidationResult.invalid(
          'Nama gudang maksimal ${AppConstants.maxWarehouseNameLength} karakter');
    }
    return const ValidationResult.valid();
  }

  // ---------------------------------------------------------------------------
  // Generic required field
  // ---------------------------------------------------------------------------

  /// Validates that a string field is not empty.
  static ValidationResult validateRequired(String? value,
      {String fieldName = 'Field'}) {
    if (value == null || value.trim().isEmpty) {
      return ValidationResult.invalid('$fieldName tidak boleh kosong');
    }
    return const ValidationResult.valid();
  }
}
