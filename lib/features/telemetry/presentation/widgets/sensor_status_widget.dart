import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/telemetry_provider.dart';

/// Alert banner widget that displays sensor connectivity or breach warnings.
///
/// Matches Figma states:
/// - **Breach (red)**: "SUHU MELEBIHI BATAS! -12.3°C > -15°C"
/// - **Sensor issue (yellow)**: "SENSOR TIDAK MERESPONS"
/// - **Connected**: hidden (returns SizedBox.shrink)
class SensorStatusBanner extends StatelessWidget {
  const SensorStatusBanner({
    super.key,
    required this.status,
    required this.isBreach,
    this.currentTemp,
    this.threshold,
  });

  final SensorStatus status;
  final bool isBreach;
  final double? currentTemp;
  final double? threshold;

  @override
  Widget build(BuildContext context) {
    // Breach takes priority over sensor status.
    if (isBreach && currentTemp != null && threshold != null) {
      return _BreachBanner(
        currentTemp: currentTemp!,
        threshold: threshold!,
      );
    }

    switch (status) {
      case SensorStatus.connected:
        return const SizedBox.shrink();
      case SensorStatus.disconnected:
        return const _SensorIssueBanner(
          message: 'KONEKSI JARINGAN TERPUTUS',
          icon: Icons.wifi_off_rounded,
        );
      case SensorStatus.noResponse:
        return const _SensorIssueBanner(
          message: 'SENSOR TIDAK MERESPONS',
          icon: Icons.sensors_off_rounded,
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Breach banner (red)
// ---------------------------------------------------------------------------

class _BreachBanner extends StatelessWidget {
  const _BreachBanner({
    required this.currentTemp,
    required this.threshold,
  });

  final double currentTemp;
  final double threshold;

  @override
  Widget build(BuildContext context) {
    final tempStr = currentTemp.toStringAsFixed(1);
    final threshStr = threshold.toStringAsFixed(1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.15),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_rounded,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'SUHU MELEBIHI BATAS! $tempStr°C > $threshStr°C',
              style: AppTextStyles.bodyRegular.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sensor issue banner (yellow/warning)
// ---------------------------------------------------------------------------

class _SensorIssueBanner extends StatelessWidget {
  const _SensorIssueBanner({
    required this.message,
    required this.icon,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.warning, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodyRegular.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
