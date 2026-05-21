/// Firestore collection and field name constants.
/// Centralising these prevents typos and makes refactoring easier.
class FirebaseConstants {
  FirebaseConstants._();

  // ---------------------------------------------------------------------------
  // Collection Names
  // ---------------------------------------------------------------------------
  static const String usersCollection = 'users';
  static const String warehousesCollection = 'warehouses';
  static const String bookingsCollection = 'bookings';
  static const String telemetryCollection = 'telemetry';
  static const String incidentLogsCollection = 'incident_logs';

  // ---------------------------------------------------------------------------
  // users/{userId} field names
  // ---------------------------------------------------------------------------
  static const String fieldUid = 'uid';
  static const String fieldEmail = 'email';
  static const String fieldFullName = 'fullName';
  static const String fieldPhoneNumber = 'phoneNumber';
  static const String fieldRole = 'role';
  static const String fieldIsEmailVerified = 'isEmailVerified';
  static const String fieldIsActive = 'isActive';
  static const String fieldFcmToken = 'fcmToken';
  static const String fieldCreatedAt = 'createdAt';
  static const String fieldLastLoginAt = 'lastLoginAt';
  static const String fieldFailedLoginAttempts = 'failedLoginAttempts';
  static const String fieldLockedUntil = 'lockedUntil';

  // ---------------------------------------------------------------------------
  // warehouses/{warehouseId} field names
  // ---------------------------------------------------------------------------
  static const String fieldMitraId = 'mitraId';
  static const String fieldName = 'name';
  static const String fieldAddress = 'address';
  static const String fieldLocation = 'location';
  static const String fieldTotalCapacity = 'totalCapacity';
  static const String fieldRemainingCapacity = 'remainingCapacity';
  static const String fieldPricePerM3PerDay = 'pricePerM3PerDay';
  static const String fieldTemperatureCategory = 'temperatureCategory';
  static const String fieldTemperatureThreshold = 'temperatureThreshold';
  static const String fieldPhotoUrls = 'photoUrls';
  static const String fieldIotNodeId = 'iotNodeId';
  static const String fieldUpdatedAt = 'updatedAt';

  // Shared field
  static const String fieldIsActiveWarehouse = 'isActive';
  static const String fieldVerificationStatus = 'verificationStatus';

  // ---------------------------------------------------------------------------
  // bookings/{bookingId} field names
  // ---------------------------------------------------------------------------
  static const String fieldUmkmId = 'umkmId';
  static const String fieldWarehouseId = 'warehouseId';
  static const String fieldWarehouseName = 'warehouseName';
  static const String fieldVolumeM3 = 'volumeM3';
  static const String fieldStartDate = 'startDate';
  static const String fieldEndDate = 'endDate';
  static const String fieldDurationDays = 'durationDays';
  static const String fieldPriceSnapshot = 'pricePerM3PerDay';
  static const String fieldTotalCost = 'totalCost';
  static const String fieldStatus = 'status';
  static const String fieldPaymentStatus = 'paymentStatus';
  static const String fieldQrCodeData = 'qrCodeData';

  // ---------------------------------------------------------------------------
  // telemetry/{telemetryId} field names
  // ---------------------------------------------------------------------------
  static const String fieldTemperature = 'temperature';
  static const String fieldHumidity = 'humidity';
  static const String fieldTimestamp = 'timestamp';
  static const String fieldReceivedAt = 'receivedAt';

  // ---------------------------------------------------------------------------
  // incident_logs/{logId} field names
  // ---------------------------------------------------------------------------
  static const String fieldThreshold = 'threshold';
  static const String fieldSeverity = 'severity';
  static const String fieldEventType = 'eventType';
  static const String fieldAffectedUmkmIds = 'affectedUmkmIds';
  static const String fieldNotificationsSent = 'notificationsSent';
  static const String fieldNotificationsFailed = 'notificationsFailed';
  static const String fieldResolvedAt = 'resolvedAt';

  // ---------------------------------------------------------------------------
  // Firebase Storage paths
  // ---------------------------------------------------------------------------
  static const String warehousePhotosPath = 'warehouse_photos';
  static const String userAvatarsPath = 'user_avatars';

  // ---------------------------------------------------------------------------
  // Cloud Functions endpoint names
  // ---------------------------------------------------------------------------
  static const String telemetryEndpoint = 'receiveTelemetry';
  static const String notificationEndpoint = 'sendViolationNotification';
}
