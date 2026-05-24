import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_utils.dart';

/// Displays the booking cost formula breakdown and total.
///
/// Shows: "v × Rp p × d hari" + total in large text + "PPN (11%) termasuk".
class CostEstimatorWidget extends StatelessWidget {
  const CostEstimatorWidget({
    super.key,
    required this.volumeM3,
    required this.pricePerM3PerDay,
    required this.durationDays,
    required this.totalCost,
  });

  final double volumeM3;
  final double pricePerM3PerDay;
  final int durationDays;
  final double totalCost;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.infoSoft,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Estimasi Biaya',
            style: AppTextStyles.heading3.copyWith(
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${volumeM3.toStringAsFixed(1)} m³ × '
            '${CurrencyUtils.formatRupiah(pricePerM3PerDay)} × '
            '$durationDays hari',
            style: AppTextStyles.bodyRegular.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            CurrencyUtils.formatRupiah(totalCost),
            style: AppTextStyles.heading1.copyWith(
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'PPN (11%) termasuk',
            style: AppTextStyles.caption.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
