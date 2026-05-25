import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_constants.dart';

/// Lightweight client-side notification service.
///
/// Handles FCM token management and incoming message routing.
/// The actual push notification sending is handled by Cloud Functions,
/// not by the Flutter client.
///
/// Requirements: 7.1, 7.3, 7.4, 7.5
class NotificationService {
  final FirebaseMessaging _messaging;
  GoRouter? _router;

  NotificationService({required FirebaseMessaging messaging})
      : _messaging = messaging;

  /// Attaches the [GoRouter] instance so deep-link navigation can be
  /// performed when a notification is tapped.
  void attachRouter(GoRouter router) {
    _router = router;
  }

  /// Requests notification permission and retrieves the FCM token.
  ///
  /// Should be called once during app initialization.
  Future<void> initialize() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Retrieve and store the initial FCM token.
    await _messaging.getToken();

    // Listen for incoming messages while the app is in the foreground.
    FirebaseMessaging.onMessage.listen(handleIncomingNotification);

    // Handle notification taps when the app is in background/terminated.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if the app was opened from a terminated state via notification.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  /// Returns the current FCM registration token, or `null` if unavailable.
  Future<String?> getToken() async {
    return _messaging.getToken();
  }

  /// Routes an incoming [RemoteMessage] to the appropriate handler.
  ///
  /// For foreground messages, this displays an in-app indicator.
  /// Deep-link navigation is handled by [_handleNotificationTap].
  void handleIncomingNotification(RemoteMessage message) {
    // Foreground messages are informational — no navigation.
    // The UI can listen to a stream or show a snackbar if needed.
  }

  /// Handles notification tap (background/terminated) by navigating to the
  /// appropriate monitoring page based on the notification payload.
  ///
  /// Expected data fields:
  /// - `type`: "violation" | "recovery"
  /// - `warehouseId`: the warehouse that triggered the alert
  ///
  /// Requirement 7.3: push notification navigates to monitoring page.
  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = data['type'];
    final warehouseId = data['warehouseId'];

    if (_router == null) return;

    if ((type == 'violation' || type == 'recovery') &&
        warehouseId != null &&
        warehouseId.isNotEmpty) {
      _router!.go(RouteConstants.monitoringPath(warehouseId));
    }
  }
}
