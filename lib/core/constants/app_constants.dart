/// Global application constants for the ColdShare Platform.
class AppConstants {
  AppConstants._();

  // ---------------------------------------------------------------------------
  // App Info
  // ---------------------------------------------------------------------------
  static const String appName = 'Polarna';
  static const String appVersion = '1.0.0';

  // ---------------------------------------------------------------------------
  // Search & Map
  // ---------------------------------------------------------------------------
  /// Default search radius in kilometres.
  static const double defaultSearchRadiusKm = 50.0;

  /// Available radius filter options (km).
  static const List<double> searchRadiusOptions = [5, 10, 25, 50];

  /// Auto-refresh interval for warehouse capacity (seconds).
  static const int warehouseRefreshIntervalSeconds = 60;

  // ---------------------------------------------------------------------------
  // Booking
  // ---------------------------------------------------------------------------

  /// Platform commission rate — percentage of total booking cost taken
  /// by Polarna as platform fee. Mitra menerima (1 - commissionRate).
  /// Industry standard: 5-15%. Polarna uses 10%.
  static const double commissionRate = 0.10;
  /// Minimum bookable volume in m³.
  static const double minBookingVolumeM3 = 0.5;

  /// Maximum bookable volume in m³.
  static const double maxBookingVolumeM3 = 500.0;

  /// Volume step (kelipatan) in m³.
  static const double bookingVolumeStep = 0.5;

  /// Minimum booking duration in days.
  static const int minBookingDurationDays = 1;

  /// Maximum booking duration in days.
  static const int maxBookingDurationDays = 365;

  /// Payment gateway timeout in seconds.
  static const int paymentTimeoutSeconds = 30;

  // ---------------------------------------------------------------------------
  // Warehouse Validation
  // ---------------------------------------------------------------------------
  /// Minimum warehouse capacity in m³.
  static const double minWarehouseCapacityM3 = 1.0;

  /// Maximum warehouse capacity in m³.
  static const double maxWarehouseCapacityM3 = 999999.0;

  /// Minimum warehouse price per m³ per day (Rp).
  static const double minWarehousePriceRp = 1000.0;

  /// Maximum warehouse price per m³ per day (Rp).
  static const double maxWarehousePriceRp = 999999999.0;

  /// Maximum number of warehouse photos.
  static const int maxWarehousePhotos = 5;

  /// Maximum photo file size in bytes (5 MB).
  static const int maxPhotoSizeBytes = 5 * 1024 * 1024;

  // ---------------------------------------------------------------------------
  // GPS — Indonesia Bounds
  // ---------------------------------------------------------------------------
  static const double indonesiaMinLatitude = -11.0;
  static const double indonesiaMaxLatitude = 6.0;
  static const double indonesiaMinLongitude = 95.0;
  static const double indonesiaMaxLongitude = 141.0;

  // ---------------------------------------------------------------------------
  // Temperature & Sensor
  // ---------------------------------------------------------------------------
  /// Minimum temperature threshold that a Mitra can set (°C).
  static const double minTemperatureThreshold = -40.0;

  /// Maximum temperature threshold that a Mitra can set (°C).
  static const double maxTemperatureThreshold = 30.0;

  /// Minimum valid sensor temperature reading (°C).
  static const double minSensorTemperature = -40.0;

  /// Maximum valid sensor temperature reading (°C).
  static const double maxSensorTemperature = 80.0;

  /// Minimum valid sensor humidity reading (%).
  static const double minSensorHumidity = 0.0;

  /// Maximum valid sensor humidity reading (%).
  static const double maxSensorHumidity = 100.0;

  /// Sensor data timeout before showing "Sensor Tidak Merespons" (seconds).
  static const int sensorTimeoutSeconds = 300; // 5 minutes

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------
  /// Rate-limit window for violation notifications (minutes).
  static const int notificationRateLimitMinutes = 15;

  /// Recovery window: temperature must stay below threshold for this long (minutes).
  static const int temperatureRecoveryMinutes = 5;

  /// Maximum notification retry attempts.
  static const int maxNotificationRetries = 3;

  /// Interval between notification retries (seconds).
  static const int notificationRetryIntervalSeconds = 30;

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------
  /// Maximum failed login attempts before account lock.
  static const int maxFailedLoginAttempts = 5;

  /// Account lock duration (minutes).
  static const int accountLockDurationMinutes = 15;

  /// Session duration (days).
  static const int sessionDurationDays = 30;

  /// Password reset link expiry (minutes).
  static const int resetLinkExpiryMinutes = 60;

  // ---------------------------------------------------------------------------
  // User Input Validation
  // ---------------------------------------------------------------------------
  static const int maxEmailLength = 254;
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 64;
  static const int maxFullNameLength = 100;
  static const int maxPhoneDigits = 15;
  static const int maxWarehouseNameLength = 100;

  // ---------------------------------------------------------------------------
  // Offline / Cache
  // ---------------------------------------------------------------------------
  /// Maximum duration to retain cached data during offline mode (minutes).
  static const int offlineCacheDurationMinutes = 60;

  // ---------------------------------------------------------------------------
  // IoT / Telemetry
  // ---------------------------------------------------------------------------
  /// IoT sensor read interval (seconds).
  static const int iotReadIntervalSeconds = 30;

  /// Maximum local storage entries on ESP32.
  static const int esp32MaxLocalEntries = 1000;

  /// Maximum IoT send retry attempts.
  static const int iotMaxRetries = 3;

  /// Interval between IoT retries (seconds).
  static const int iotRetryIntervalSeconds = 10;
}
