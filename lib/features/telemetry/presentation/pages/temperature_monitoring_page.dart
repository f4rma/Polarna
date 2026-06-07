import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_animations.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/telemetry_provider.dart';
import '../widgets/sensor_status_widget.dart';
import '../widgets/temperature_chart_widget.dart';

/// Full-screen temperature monitoring page with dark theme (per Figma).
///
/// Displays real-time temperature/humidity, chart with time range selector,
/// alert banners, and CSV export action.
///
/// Requirements: 6.1–6.5.
class TemperatureMonitoringPage extends ConsumerWidget {
  const TemperatureMonitoringPage({
    super.key,
    required this.warehouseId,
    this.warehouseName = 'Gudang',
    this.threshold = -18.0,
  });

  final String warehouseId;
  final String warehouseName;
  final double threshold;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = TelemetryProviderParams(
      warehouseId: warehouseId,
      threshold: threshold,
    );
    final state = ref.watch(telemetryNotifierProvider(params));

    // Force dark theme for monitoring page per Figma.
    return Theme(
      data: _monitoringDarkTheme(),
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: _buildAppBar(context, ref, params),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Alert banner
                SensorStatusBanner(
                  status: state.status,
                  isBreach: state.isBreach,
                  currentTemp: state.latest?.temperature,
                  threshold: threshold,
                ),
                if (state.status != SensorStatus.connected || state.isBreach)
                  const SizedBox(height: AppSpacing.lg),

                // Stat cards row
                _StatCardsRow(state: state, threshold: threshold)
                    .fadeSlideIn(),
                const SizedBox(height: AppSpacing.xxl),

                // Time range selector
                _TimeRangeSelector(
                  selected: state.timeRange,
                  onChanged: (range) {
                    ref
                        .read(telemetryNotifierProvider(params).notifier)
                        .setTimeRange(range);
                  },
                ),
                const SizedBox(height: AppSpacing.lg),

                // Chart
                if (state.isLoadingHistory)
                  const SizedBox(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accent,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                else
                  TemperatureChartWidget(
                    history: state.history,
                    threshold: threshold,
                    status: state.status,
                    isBreach: state.isBreach,
                    timeRange: state.timeRange,
                  ),

                const SizedBox(height: AppSpacing.lg),

                // Footer
                _FooterStatus(state: state),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    WidgetRef ref,
    TelemetryProviderParams params,
  ) {
    return AppBar(
      backgroundColor: AppColors.backgroundDark,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monitoring Suhu',
            style: AppTextStyles.heading3.copyWith(
              color: AppColors.textPrimaryDark,
            ),
          ),
          Text(
            warehouseName,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
        ],
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimaryDark),
      actions: [
        IconButton(
          icon: const Icon(Icons.file_download_outlined),
          tooltip: 'Ekspor CSV',
          onPressed: () => _exportCsv(context, ref, params),
        ),
      ],
    );
  }

  Future<void> _exportCsv(
    BuildContext context,
    WidgetRef ref,
    TelemetryProviderParams params,
  ) async {
    final notifier = ref.read(telemetryNotifierProvider(params).notifier);
    final csv = await notifier.exportCsv();

    if (!context.mounted) return;

    if (csv != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CSV berhasil diekspor'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal mengekspor CSV'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  ThemeData _monitoringDarkTheme() {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: AppColors.backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        surface: AppColors.surfaceDark,
        onSurface: AppColors.textPrimaryDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stat cards row
// ---------------------------------------------------------------------------

class _StatCardsRow extends StatelessWidget {
  const _StatCardsRow({required this.state, required this.threshold});

  final TelemetryState state;
  final double threshold;

  @override
  Widget build(BuildContext context) {
    final isDisconnected = state.status == SensorStatus.disconnected ||
        state.status == SensorStatus.noResponse;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Suhu Terkini',
            value: isDisconnected
                ? '--.-°C'
                : '${state.latest?.temperature.toStringAsFixed(1) ?? '--.-'}°C',
            icon: isDisconnected
                ? Icons.thermostat_outlined
                : Icons.thermostat_rounded,
            iconCrossedOut: isDisconnected,
            cardColor: state.isBreach
                ? AppColors.error.withValues(alpha: 0.15)
                : const Color(0xFF1A2F4A), // blue card
            accentColor: state.isBreach ? AppColors.error : AppColors.info,
            subtitle: state.isBreach ? 'Suhu terlalu tinggi' : null,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _StatCard(
            label: 'Kelembapan',
            value: isDisconnected
                ? '--.-%'
                : '${state.latest?.humidity.toStringAsFixed(1) ?? '--.'}%',
            icon: isDisconnected
                ? Icons.water_drop_outlined
                : Icons.water_drop_rounded,
            iconCrossedOut: isDisconnected,
            cardColor: const Color(0xFF1A3A3A), // teal card
            accentColor: AppColors.accentAlt,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Individual stat card
// ---------------------------------------------------------------------------

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.cardColor,
    required this.accentColor,
    this.iconCrossedOut = false,
    this.subtitle,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color cardColor;
  final Color accentColor;
  final bool iconCrossedOut;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                children: [
                  Icon(icon, color: accentColor, size: 20),
                  if (iconCrossedOut)
                    Positioned.fill(
                      child: CustomPaint(painter: _CrossOutPainter(accentColor)),
                    ),
                ],
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: AppTextStyles.heading2.copyWith(
              color: AppColors.textPrimaryDark,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle!,
              style: AppTextStyles.caption.copyWith(
                color: accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cross-out painter for disconnected icon state
// ---------------------------------------------------------------------------

class _CrossOutPainter extends CustomPainter {
  final Color color;
  _CrossOutPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Time range selector
// ---------------------------------------------------------------------------

class _TimeRangeSelector extends StatelessWidget {
  const _TimeRangeSelector({
    required this.selected,
    required this.onChanged,
  });

  final TelemetryTimeRange selected;
  final ValueChanged<TelemetryTimeRange> onChanged;

  static const _labels = {
    TelemetryTimeRange.sixHours: '6 Jam',
    TelemetryTimeRange.twentyFourHours: '24 Jam',
    TelemetryTimeRange.sevenDays: '7 Hari',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        children: TelemetryTimeRange.values.map((range) {
          final isSelected = range == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(range),
              child: AnimatedContainer(
                duration: AppDurations.fast,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accent.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                alignment: Alignment.center,
                child: Text(
                  _labels[range]!,
                  style: AppTextStyles.bodyRegular.copyWith(
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Footer status
// ---------------------------------------------------------------------------

class _FooterStatus extends StatelessWidget {
  const _FooterStatus({required this.state});

  final TelemetryState state;

  @override
  Widget build(BuildContext context) {
    String text;
    Color color;

    if (state.isBreach) {
      text = 'KRITIS: SEGERA PERIKSA UNIT PENDINGIN';
      color = AppColors.error;
    } else if (state.status == SensorStatus.disconnected ||
        state.status == SensorStatus.noResponse) {
      text = 'Menghubungkan kembali...';
      color = AppColors.textSecondaryDark;
    } else {
      text = state.lastUpdateText ?? 'Memuat...';
      color = AppColors.textSecondaryDark;
    }

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.isBreach)
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.xs),
              child: Icon(Icons.error, color: AppColors.error, size: 14),
            ),
          if (state.status == SensorStatus.disconnected ||
              state.status == SensorStatus.noResponse)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppColors.textSecondaryDark.withValues(alpha: 0.6),
                ),
              ),
            ),
          Text(
            text,
            style: AppTextStyles.caption.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
