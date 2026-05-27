// Unit tests for notification domain services:
// - BreachDetector (focused unit tests complementing PBT)
// - NotificationRateLimiter
// - NotificationService (structure/compilation verification)

import 'package:flutter_test/flutter_test.dart';
import 'package:polarna/features/notification/domain/services/breach_detector.dart';
import 'package:polarna/features/notification/domain/services/rate_limiter.dart';
import 'package:polarna/features/notification/domain/services/notification_service.dart';

void main() {
  // ===========================================================================
  // BreachDetector Unit Tests
  // ===========================================================================
  group('BreachDetector', () {
    test('temp > threshold → violation', () {
      final result = BreachDetector.detect(
        currentTemp: 5.0,
        threshold: 4.0,
      );
      expect(result, equals(BreachStatus.violation));
    });

    test('temp == threshold → normal', () {
      final result = BreachDetector.detect(
        currentTemp: 4.0,
        threshold: 4.0,
      );
      expect(result, equals(BreachStatus.normal));
    });

    test('temp < threshold → normal', () {
      final result = BreachDetector.detect(
        currentTemp: 3.0,
        threshold: 4.0,
      );
      expect(result, equals(BreachStatus.normal));
    });
  });

  // ===========================================================================
  // NotificationRateLimiter Unit Tests
  // ===========================================================================
  group('NotificationRateLimiter', () {
    late NotificationRateLimiter limiter;

    setUp(() {
      limiter = NotificationRateLimiter();
    });

    test('first canSend returns true', () {
      final result = limiter.canSend(
        recipientId: 'user-1',
        warehouseId: 'wh-1',
      );
      expect(result, isTrue);
    });

    test('after recordSent, immediate canSend returns false', () {
      limiter.recordSent(recipientId: 'user-1', warehouseId: 'wh-1');

      final result = limiter.canSend(
        recipientId: 'user-1',
        warehouseId: 'wh-1',
      );
      expect(result, isFalse);
    });

    test('different recipients are independent', () {
      limiter.recordSent(recipientId: 'user-1', warehouseId: 'wh-1');

      // user-2 should still be able to send
      final result = limiter.canSend(
        recipientId: 'user-2',
        warehouseId: 'wh-1',
      );
      expect(result, isTrue);
    });

    test('different warehouses are independent', () {
      limiter.recordSent(recipientId: 'user-1', warehouseId: 'wh-1');

      // same user, different warehouse should still be able to send
      final result = limiter.canSend(
        recipientId: 'user-1',
        warehouseId: 'wh-2',
      );
      expect(result, isTrue);
    });

    test('reset() clears all rate-limit entries', () {
      limiter.recordSent(recipientId: 'user-1', warehouseId: 'wh-1');
      limiter.recordSent(recipientId: 'user-2', warehouseId: 'wh-2');

      limiter.reset();

      expect(
        limiter.canSend(recipientId: 'user-1', warehouseId: 'wh-1'),
        isTrue,
      );
      expect(
        limiter.canSend(recipientId: 'user-2', warehouseId: 'wh-2'),
        isTrue,
      );
    });
  });

  // ===========================================================================
  // NotificationService Structure Tests
  // ===========================================================================
  group('NotificationService', () {
    test('class can be referenced and requires FirebaseMessaging', () {
      // Verify the class exists and its constructor signature compiles.
      // We cannot instantiate without a real FirebaseMessaging instance,
      // but we can verify the type is accessible.
      expect(NotificationService, isNotNull);
    });
  });
}
