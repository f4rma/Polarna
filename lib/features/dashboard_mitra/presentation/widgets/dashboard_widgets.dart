import 'package:flutter/material.dart';

import '../../../../core/theme/app_primitives.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../booking/domain/entities/booking_entity.dart';
import '../../domain/entities/revenue_summary.dart';

// ---------------------------------------------------------------------------
// Stat card — single metric display
// ---------------------------------------------------------------------------

/// A single stat card used in the 2×2 dashboard grid.
class DashboardStatCard extends StatelessWidget {
  const DashboardStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.surfaceDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: AppTextStyles.heading2.copyWith(
              color: AppColors.textPrimaryDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2×2 stat cards grid
// ---------------------------------------------------------------------------

/// Displays 4 stat cards in a 2×2 grid layout.
class DashboardStatCardsGrid extends StatelessWidget {
  const DashboardStatCardsGrid({super.key, required this.summary});

  final RevenueSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DashboardStatCard(
                label: 'Pendapatan Hari Ini',
                value: CurrencyUtils.formatRupiahCompact(
                  summary.dailyRevenue,
                ),
                icon: Icons.today_rounded,
                iconColor: AppColors.accent,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: DashboardStatCard(
                label: 'Pendapatan Bulan Ini',
                value: CurrencyUtils.formatRupiahCompact(
                  summary.monthlyRevenue,
                ),
                icon: Icons.calendar_month_rounded,
                iconColor: AppColors.accentAlt,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: DashboardStatCard(
                label: 'Transaksi Aktif',
                value: '${summary.activeTransactions}',
                icon: Icons.receipt_long_rounded,
                iconColor: AppColors.info,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: DashboardStatCard(
                label: 'Utilisasi',
                value: '${summary.utilizationPercent.toStringAsFixed(1)}%',
                icon: Icons.pie_chart_rounded,
                iconColor: AppColors.success,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// IoT status bar
// ---------------------------------------------------------------------------

/// Horizontal bar showing IoT sensor connection status.
class DashboardIoTStatusBar extends StatelessWidget {
  const DashboardIoTStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceDarkElevated,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'IoT Sensor Terhubung',
            style: AppTextStyles.bodyRegular.copyWith(
              color: AppColors.textPrimaryDark,
            ),
          ),
          const Spacer(),
          Text(
            'Real-time',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Transaction tile
// ---------------------------------------------------------------------------

/// A single active transaction row in the dashboard list.
class DashboardTransactionTile extends StatelessWidget {
  const DashboardTransactionTile({super.key, required this.booking});

  final BookingEntity booking;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        color: AppColors.surfaceDarkElevated,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const AppRoundIconAvatar(
              icon: Icons.inventory_2_outlined,
              size: 36,
              backgroundColor: AppColors.infoSoft,
              iconColor: AppColors.info,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    booking.warehouseName,
                    style: AppTextStyles.bodyRegular.copyWith(
                      color: AppColors.textPrimaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${booking.volumeM3} m³ · ${booking.durationDays} hari',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                ],
              ),
            ),
            AppStatusBadge.active(),
          ],
        ),
      ),
    );
  }
}
