import 'package:equatable/equatable.dart';

/// Immutable data class representing a Mitra's revenue summary.
///
/// Used by [GetRevenueUseCase] to present aggregated financial and
/// utilization data on the Revenue_Dashboard (Requirements 8.1–8.2).
class RevenueSummary extends Equatable {
  /// Total revenue earned today (Rp).
  final double dailyRevenue;

  /// Total revenue earned in the current month (Rp).
  final double monthlyRevenue;

  /// Number of bookings currently in `active` status.
  final int activeTransactions;

  /// Capacity utilization percentage: (used / total) × 100.
  final double utilizationPercent;

  /// Monthly revenue history for the last 12 months, ordered from
  /// oldest (index 0) to most recent (index 11).
  final List<double> monthlyRevenueHistory;

  const RevenueSummary({
    required this.dailyRevenue,
    required this.monthlyRevenue,
    required this.activeTransactions,
    required this.utilizationPercent,
    required this.monthlyRevenueHistory,
  });

  @override
  List<Object?> get props => [
        dailyRevenue,
        monthlyRevenue,
        activeTransactions,
        utilizationPercent,
        monthlyRevenueHistory,
      ];
}
