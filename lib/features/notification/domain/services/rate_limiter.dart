import '../../../../core/constants/app_constants.dart';

/// In-memory rate limiter for client-side notification throttling.
///
/// Ensures that at most 1 notification is sent per recipient per warehouse
/// within a configurable time window (default: 15 minutes).
///
/// Requirements: 7.7
class NotificationRateLimiter {
  /// Internal map tracking the last sent time per recipient+warehouse pair.
  /// Key format: `{recipientId}:{warehouseId}`
  final Map<String, DateTime> _lastSent = {};

  /// Checks whether a notification can be sent to [recipientId] for
  /// [warehouseId] based on the rate-limit window.
  ///
  /// Returns `true` if no previous notification was sent, or if the last
  /// notification was sent more than [AppConstants.notificationRateLimitMinutes]
  /// minutes ago.
  bool canSend({
    required String recipientId,
    required String warehouseId,
  }) {
    final key = _buildKey(recipientId, warehouseId);
    final lastSentTime = _lastSent[key];

    if (lastSentTime == null) {
      return true;
    }

    final elapsed = DateTime.now().difference(lastSentTime);
    return elapsed.inMinutes >= AppConstants.notificationRateLimitMinutes;
  }

  /// Records that a notification was sent to [recipientId] for [warehouseId]
  /// at the current time.
  void recordSent({
    required String recipientId,
    required String warehouseId,
  }) {
    final key = _buildKey(recipientId, warehouseId);
    _lastSent[key] = DateTime.now();
  }

  /// Clears all rate-limit entries.
  void reset() {
    _lastSent.clear();
  }

  /// Builds the composite key for the internal map.
  String _buildKey(String recipientId, String warehouseId) =>
      '$recipientId:$warehouseId';
}
