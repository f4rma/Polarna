import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../booking/domain/entities/booking_entity.dart';
import '../entities/revenue_summary.dart';

/// Abstract data contract between the dashboard_mitra domain and data layers.
///
/// Implementations live in `data/repositories/dashboard_repository_impl.dart`
/// and aggregate data from Firestore bookings and warehouse collections.
abstract class DashboardRepository {
  /// Returns an aggregated revenue summary for the given Mitra.
  ///
  /// Includes daily/monthly revenue, active transaction count, and
  /// capacity utilization percentage (Requirement 8.1).
  Future<Either<Failure, RevenueSummary>> getRevenueSummary(String mitraId);

  /// Returns all bookings with status `active` for the given Mitra's
  /// warehouses (Requirement 8.4).
  Future<Either<Failure, List<BookingEntity>>> getActiveTransactions(
    String mitraId,
  );

  /// Returns all transactions for the given Mitra, optionally filtered
  /// by date range. Used for CSV export (Requirement 8.6).
  Future<Either<Failure, List<BookingEntity>>> getAllTransactions({
    required String mitraId,
    DateTime? from,
    DateTime? to,
  });
}
