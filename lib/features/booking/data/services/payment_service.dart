/// Abstract payment gateway interface.
///
/// Implementations handle the actual payment processing (e.g. Midtrans,
/// Xendit). The domain layer depends only on this contract.
abstract class PaymentService {
  /// Processes a payment for the given [amount] and [bookingId].
  ///
  /// Returns `true` if the payment was captured successfully, `false`
  /// otherwise.
  Future<bool> processPayment({
    required double amount,
    required String bookingId,
  });
}

/// Stub implementation of [PaymentService] for demo/tugas purposes.
///
/// Always returns `true` after a simulated 500ms network delay.
/// Sufficient for academic demos — no payment gateway account needed.
///
/// To switch to Midtrans Sandbox (free, no business verification):
///   1. Register at https://dashboard.sandbox.midtrans.com
///   2. Get Server Key from Settings → Access Keys
///   3. Replace this class with [MidtransSandboxPaymentService] below
///      and set [_serverKey] to your key.
class StubPaymentService implements PaymentService {
  const StubPaymentService();

  @override
  Future<bool> processPayment({
    required double amount,
    required String bookingId,
  }) async {
    // Simulate payment gateway network latency.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return true;
  }
}

// ---------------------------------------------------------------------------
// Optional: Midtrans Sandbox (free, no business verification required)
//
// Uncomment and use this class when you want to demo with a real payment
// gateway. Register at https://dashboard.sandbox.midtrans.com (free).
// ---------------------------------------------------------------------------

// import 'dart:convert';
// import 'package:http/http.dart' as http;
//
// class MidtransSandboxPaymentService implements PaymentService {
//   // Get this from Midtrans Dashboard → Settings → Access Keys
//   static const String _serverKey = 'YOUR_MIDTRANS_SANDBOX_SERVER_KEY';
//   static const String _baseUrl =
//       'https://api.sandbox.midtrans.com/v2/charge';
//
//   const MidtransSandboxPaymentService();
//
//   @override
//   Future<bool> processPayment({
//     required double amount,
//     required String bookingId,
//   }) async {
//     try {
//       final credentials = base64Encode(utf8.encode('$_serverKey:'));
//       final response = await http.post(
//         Uri.parse(_baseUrl),
//         headers: {
//           'Authorization': 'Basic $credentials',
//           'Content-Type': 'application/json',
//         },
//         body: jsonEncode({
//           'payment_type': 'bank_transfer',
//           'transaction_details': {
//             'order_id': bookingId,
//             'gross_amount': amount.toInt(),
//           },
//           'bank_transfer': {'bank': 'bca'},
//         }),
//       );
//       final data = jsonDecode(response.body) as Map<String, dynamic>;
//       final status = data['transaction_status'] as String?;
//       return status == 'pending' || status == 'settlement';
//     } catch (_) {
//       return false;
//     }
//   }
// }
