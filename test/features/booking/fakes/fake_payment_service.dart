// Hand-rolled fake for [PaymentService] used by BookingNotifier tests.

import 'dart:collection';

import 'package:polarna/features/booking/data/services/payment_service.dart';

class FakePaymentService implements PaymentService {
  final Queue<bool> processPaymentResponses = Queue();
  int processPaymentCallCount = 0;

  @override
  Future<bool> processPayment({
    required double amount,
    required String bookingId,
  }) async {
    processPaymentCallCount += 1;
    if (processPaymentResponses.isEmpty) {
      throw StateError('No processPaymentResponses queued');
    }
    return processPaymentResponses.removeFirst();
  }
}
