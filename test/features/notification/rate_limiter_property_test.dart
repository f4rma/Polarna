// Property tests for notification rate limiting.
//
// **Validates: Requirements 7.7**
// Reference: .kiro/specs/coldshare-platform/requirements.md#Requirement 7
//
// Property 14: Rate Limiting Notifikasi Pelanggaran
//   Within a 15-minute window, at most 1 notification is sent per recipient
//   per warehouse. The NotificationRateLimiter enforces this by tracking
//   the last-sent timestamp per (recipientId, warehouseId) pair.
//
// Since NotificationRateLimiter uses DateTime.now() internally, the
// "within 15 min" property is tested by calling canSend() immediately
// after recordSent() (which is always < 15 min).

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:glados/glados.dart' hide test, group, expect;
import 'package:polarna/features/notification/domain/services/rate_limiter.dart';

// ---------------------------------------------------------------------------
// Generators
// ---------------------------------------------------------------------------

/// Generates random alphanumeric strings of length 4–12 to serve as IDs.
Generator<String> _idGen() => any
    .listWithLengthInRange(
        4, 12, any.choose('abcdefghijklmnopqrstuvwxyz0123456789'.split('')))
    .map((chars) => chars.join());

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Property 14: Rate Limiting Notifikasi - Requirement 7.7', () {
    // -----------------------------------------------------------------------
    // P14.A — First send is always allowed.
    // For any (recipientId, warehouseId), canSend() returns true on first call.
    // -----------------------------------------------------------------------
    Glados2<String, String>(_idGen(), _idGen()).test(
      'first canSend() always returns true for any recipient+warehouse pair',
      (recipientId, warehouseId) {
        final limiter = NotificationRateLimiter();

        final result = limiter.canSend(
          recipientId: recipientId,
          warehouseId: warehouseId,
        );

        expect(result, isTrue,
            reason:
                'First call to canSend must always be true for ($recipientId, $warehouseId)');
      },
    );

    // -----------------------------------------------------------------------
    // P14.B — Second send within 15 min is blocked.
    // After recordSent(), immediate canSend() returns false.
    // -----------------------------------------------------------------------
    Glados2<String, String>(_idGen(), _idGen()).test(
      'canSend() returns false immediately after recordSent() for same pair',
      (recipientId, warehouseId) {
        final limiter = NotificationRateLimiter();

        // First send is allowed
        expect(
          limiter.canSend(recipientId: recipientId, warehouseId: warehouseId),
          isTrue,
        );

        // Record that notification was sent
        limiter.recordSent(recipientId: recipientId, warehouseId: warehouseId);

        // Immediate second call must be blocked (< 15 min elapsed)
        final result = limiter.canSend(
          recipientId: recipientId,
          warehouseId: warehouseId,
        );

        expect(result, isFalse,
            reason:
                'canSend must return false within 15-min window after recordSent');
      },
    );

    // -----------------------------------------------------------------------
    // P14.C — Different recipients are independent.
    // recordSent for recipient A does NOT block recipient B for same warehouse.
    // -----------------------------------------------------------------------
    Glados(any.combine3(
      _idGen(),
      _idGen(),
      _idGen(),
      (String recipientA, String recipientB, String warehouseId) =>
          (recipientA: recipientA, recipientB: recipientB, warehouseId: warehouseId),
    )).test(
      'recordSent for recipient A does not block recipient B on same warehouse',
      (data) {
        // Skip if both recipients are the same (collision)
        if (data.recipientA == data.recipientB) return;

        final limiter = NotificationRateLimiter();

        // Record sent for recipient A
        limiter.recordSent(
            recipientId: data.recipientA, warehouseId: data.warehouseId);

        // Recipient B should still be allowed
        final result = limiter.canSend(
          recipientId: data.recipientB,
          warehouseId: data.warehouseId,
        );

        expect(result, isTrue,
            reason:
                'Recipient "${data.recipientB}" must not be blocked by "${data.recipientA}" sending');
      },
    );

    // -----------------------------------------------------------------------
    // P14.D — Different warehouses are independent.
    // recordSent for warehouse X does NOT block same recipient for warehouse Y.
    // -----------------------------------------------------------------------
    Glados(any.combine3(
      _idGen(),
      _idGen(),
      _idGen(),
      (String recipientId, String warehouseX, String warehouseY) =>
          (recipientId: recipientId, warehouseX: warehouseX, warehouseY: warehouseY),
    )).test(
      'recordSent for warehouse X does not block same recipient for warehouse Y',
      (data) {
        // Skip if both warehouses are the same (collision)
        if (data.warehouseX == data.warehouseY) return;

        final limiter = NotificationRateLimiter();

        // Record sent for warehouse X
        limiter.recordSent(
            recipientId: data.recipientId, warehouseId: data.warehouseX);

        // Same recipient for warehouse Y should still be allowed
        final result = limiter.canSend(
          recipientId: data.recipientId,
          warehouseId: data.warehouseY,
        );

        expect(result, isTrue,
            reason:
                'Warehouse "${data.warehouseY}" must not be blocked by "${data.warehouseX}" sending');
      },
    );

    // -----------------------------------------------------------------------
    // P14.E — After reset, all entries are cleared.
    // reset() clears all entries so canSend() returns true again.
    // -----------------------------------------------------------------------
    Glados2<String, String>(_idGen(), _idGen()).test(
      'after reset(), canSend() returns true again for previously blocked pair',
      (recipientId, warehouseId) {
        final limiter = NotificationRateLimiter();

        // Record sent → blocked
        limiter.recordSent(recipientId: recipientId, warehouseId: warehouseId);
        expect(
          limiter.canSend(recipientId: recipientId, warehouseId: warehouseId),
          isFalse,
        );

        // Reset clears everything
        limiter.reset();

        // Now should be allowed again
        final result = limiter.canSend(
          recipientId: recipientId,
          warehouseId: warehouseId,
        );

        expect(result, isTrue,
            reason: 'After reset(), all rate-limit entries must be cleared');
      },
    );
  });
}
