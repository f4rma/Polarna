import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_info.dart';
import '../../../auth/data/providers/auth_data_providers.dart';
import '../../domain/repositories/booking_repository.dart';
import '../datasources/booking_remote_datasource.dart';
import '../repositories/booking_repository_impl.dart';
import '../services/payment_service.dart';

/// Riverpod wiring for the booking data layer.
///
/// Reuses [firestoreProvider] from the auth feature so every feature shares
/// the same [FirebaseFirestore] singleton.

/// Provides the [BookingRemoteDataSource] wired to Cloud Firestore.
final bookingRemoteDataSourceProvider =
    Provider<BookingRemoteDataSource>((ref) {
  return BookingRemoteDataSourceImpl(
    firestore: ref.watch(firestoreProvider),
  );
});

/// Provides the [PaymentService] implementation.
///
/// Currently uses [StubPaymentService] for MVP. Replace with a real
/// gateway implementation when credentials are available.
final paymentServiceProvider = Provider<PaymentService>((ref) {
  return const StubPaymentService();
});

/// Provides the fully-wired [BookingRepository].
final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepositoryImpl(
    remote: ref.watch(bookingRemoteDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
});
