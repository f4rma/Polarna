import 'package:equatable/equatable.dart';

import '../../../../core/constants/app_constants.dart';

/// Immutable summary of platform-wide metrics for the Admin dashboard.
///
/// Revenue model:
/// - [grossMerchandiseValue] (GMV) — total of all booking values
/// - [platformRevenue] — what Polarna keeps (GMV × commissionRate)
/// - [mitraPayout] — what Mitra receive (GMV × (1 - commissionRate))
class PlatformSummary extends Equatable {
  final int totalUsers;
  final int activeWarehouses;
  final int activeTransactions;

  /// Gross Merchandise Value — total nominal of all bookings.
  final double grossMerchandiseValue;

  const PlatformSummary({
    required this.totalUsers,
    required this.activeWarehouses,
    required this.activeTransactions,
    required this.grossMerchandiseValue,
  });

  /// Backward-compatible getter — alias for [grossMerchandiseValue].
  double get totalRevenue => grossMerchandiseValue;

  /// Platform's commission revenue (10% of GMV).
  double get platformRevenue =>
      grossMerchandiseValue * AppConstants.commissionRate;

  /// Total payout to all Mitras (90% of GMV).
  double get mitraPayout =>
      grossMerchandiseValue * (1 - AppConstants.commissionRate);

  @override
  List<Object?> get props => [
        totalUsers,
        activeWarehouses,
        activeTransactions,
        grossMerchandiseValue,
      ];
}
