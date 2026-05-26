import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_primitives.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../telemetry/presentation/providers/telemetry_provider.dart';
import '../../../telemetry/presentation/widgets/temperature_chart_widget.dart';

/// Warehouse Health page — shows current temperature, 24h trend chart,
/// and IoT connection status for a specific warehouse.
///
/// Reuses [TemperatureChartWidget] and [TelemetryNotifier] from the
/// telemetry feature. (Requirement 8.3, 8.7)
class WarehouseHealthPage extends ConsumerWidget {
  const WarehouseHealthPage({
    super.key,
    required this.warehouseId,
    this.threshold = -18.0,
  });

  final String warehouseId;
  final double threshold;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = TelemetryProviderParams(
      warehouseId: warehouseId,
      threshold: threshold,
    );
    final telemetryState = ref.watch(telemetryNotifierProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kesehatan Gudang'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _CurrentTemperatureCard(state: telemetryState),
          const SizedBox(height: AppSpacing.lg),
          _TrendSection(
            state: telemetryState,
            params: params,
            ref: ref,
          ),
          const SizedBox(height: AppSpacing.lg),
          _IoTConnectionStatus(state: telemetryState),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Current temperature card
// ---------------------------------------------------------------------------

class _CurrentTemperatureCard extends StatelessWidget {
  const _CurrentTemperatureCard({required this.state});

  final TelemetryState state;

  @override
  Widget build(BuildContext context) {
    final temp = state.latest?.temperature;
    final humidity = state.latest?.humidity;

    return AppCard(
      color: AppColors.surfaceDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suhu Terkini',
            style: AppTextStyles.heading3.copyWith(
              color: AppColors.textPrimaryDark,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                temp != null ? temp.toStringAsFixed(1) : '--.-',
                style: AppTextStyles.heading1.copyWith(
                  color: state.isBreach
                      ? AppColors.error
                      : AppColors.accent,
                  fontSize: 48,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '°C',
                  style: AppTextStyles.heading2.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Kelembapan',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    humidity != null
                        ? '${humidity.toStringAsFixed(1)}%'
                        : '--.-%',
                    style: AppTextStyles.heading3.copyWith(
                      color: AppColors.textPrimaryDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (state.lastUpdateText != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              state.lastUpdateText!,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondaryDark,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 24h trend section — reuses TemperatureChartWidget
// ---------------------------------------------------------------------------

class _TrendSection extends StatelessWidget {
  const _TrendSection({
    required this.state,
    required this.params,
    required this.ref,
  });

  final TelemetryState state;
  final TelemetryProviderParams params;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.surfaceDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tren Suhu 24 Jam',
                style: AppTextStyles.heading3.copyWith(
                  color: AppColors.textPrimaryDark,
                ),
              ),
              _TimeRangeSelector(
                selected: state.timeRange,
                onChanged: (range) {
                  ref
                      .read(telemetryNotifierProvider(params).notifier)
                      .setTimeRange(range);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          state.isLoadingHistory
              ? const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                )
              : TemperatureChartWidget(
                  history: state.history,
                  threshold: params.threshold,
                  status: state.status,
                  isBreach: state.isBreach,
                  timeRange: state.timeRange,
                ),
        ],
      ),
    );
  }
}

class _TimeRangeSelector extends StatelessWidget {
  const _TimeRangeSelector({
    required this.selected,
    required this.onChanged,
  });

  final TelemetryTimeRange selected;
  final ValueChanged<TelemetryTimeRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: TelemetryTimeRange.values.map((range) {
        final isSelected = range == selected;
        return Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xs),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            onTap: () => onChanged(range),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.accent.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                _label(range),
                style: AppTextStyles.caption.copyWith(
                  color: isSelected
                      ? AppColors.accent
                      : AppColors.textSecondaryDark,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _label(TelemetryTimeRange range) {
    switch (range) {
      case TelemetryTimeRange.sixHours:
        return '6h';
      case TelemetryTimeRange.twentyFourHours:
        return '24h';
      case TelemetryTimeRange.sevenDays:
        return '7d';
    }
  }
}

// ---------------------------------------------------------------------------
// IoT connection status
// ---------------------------------------------------------------------------

class _IoTConnectionStatus extends StatelessWidget {
  const _IoTConnectionStatus({required this.state});

  final TelemetryState state;

  @override
  Widget build(BuildContext context) {
    final isConnected = state.status == SensorStatus.connected;

    return AppCard(
      color: AppColors.surfaceDark,
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: isConnected ? AppColors.success : AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status IoT Node',
                  style: AppTextStyles.bodyRegular.copyWith(
                    color: AppColors.textPrimaryDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isConnected ? 'Terhubung' : 'Tidak Terhubung',
                  style: AppTextStyles.caption.copyWith(
                    color: isConnected
                        ? AppColors.success
                        : AppColors.error,
                  ),
                ),
              ],
            ),
          ),
          isConnected
              ? AppStatusBadge.connected()
              : AppStatusBadge.offline(),
        ],
      ),
    );
  }
}
