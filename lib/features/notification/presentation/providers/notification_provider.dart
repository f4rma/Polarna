import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_router.dart';
import '../../domain/services/notification_service.dart';
import '../../domain/services/rate_limiter.dart';

/// Provider for [FirebaseMessaging] instance.
final firebaseMessagingProvider = Provider<FirebaseMessaging>((ref) {
  return FirebaseMessaging.instance;
});

/// Provider for [NotificationService].
///
/// Initializes FCM token management and incoming message routing.
/// Attaches the [GoRouter] instance for deep-link navigation on
/// notification tap (Requirement 7.3).
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final messaging = ref.watch(firebaseMessagingProvider);
  final router = ref.watch(appRouterProvider);
  final service = NotificationService(messaging: messaging);
  service.attachRouter(router);
  return service;
});

/// Provider for [NotificationRateLimiter].
///
/// Maintains in-memory rate-limit state for the current app session.
final notificationRateLimiterProvider =
    Provider<NotificationRateLimiter>((ref) {
  return NotificationRateLimiter();
});
