import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/telemetry_entity.dart';
import '../providers/telemetry_provider.dart';

/// Chart widget displaying temperature history with threshold line.
///
/// Visual states per Figma:
/// - **Normal**: cyan line, red dashed threshold, time axis (hourly).
/// - **Critical (breach)**: red fill area below the line, "LIVE CRITICAL" label.
/// - **Disconnected**: grayed out with "DISCONNECTED" overlay.
class TemperatureChartWidget extends StatelessWidget {
  const TemperatureChartWidget({
    super.key,
    required this.history,
    required this.threshold,
    required this.status,
    required this.isBreach,
    required this.timeRange,
  });

  final List<TelemetryRecord> history;
  final double threshold;
  final SensorStatus status;
  final bool isBreach;
  final TelemetryTimeRange timeRange;

  @override
  Widget build(BuildContext context) {
    // Disconnected state — show overlay.
    if (status == SensorStatus.disconnected ||
        status == SensorStatus.noResponse) {
      return _DisconnectedOverlay(history: history);
    }

    if (history.isEmpty) {
      return _EmptyChart(threshold: threshold);
    }

    return _buildChart();
  }

  Widget _buildChart() {
    final spots = _buildSpots();
    final minX = spots.isEmpty ? 0.0 : spots.first.x;
    final maxX = spots.isEmpty ? 1.0 : spots.last.x;

    // Compute Y bounds with padding.
    double minY = threshold;
    double maxY = threshold;
    for (final s in spots) {
      if (s.y < minY) minY = s.y;
      if (s.y > maxY) maxY = s.y;
    }
    minY = (minY - 2).floorToDouble();
    maxY = (maxY + 2).ceilToDouble();

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: _yInterval(minY, maxY),
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.borderDark.withValues(alpha: 0.3),
              strokeWidth: 0.5,
            ),
          ),
          titlesData: _titlesData(minX, maxX, minY, maxY),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            _temperatureLine(spots),
          ],
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: threshold,
                color: AppColors.error,
                strokeWidth: 1.5,
                dashArray: [6, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                  labelResolver: (_) => 'Batas ${threshold.toStringAsFixed(1)}°C',
                ),
              ),
            ],
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((spot) {
                final dt = DateTime.fromMillisecondsSinceEpoch(
                  spot.x.toInt(),
                );
                return LineTooltipItem(
                  '${spot.y.toStringAsFixed(1)}°C\n${DateFormat.Hm().format(dt)}',
                  AppTextStyles.caption.copyWith(
                    color: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  List<FlSpot> _buildSpots() {
    if (history.isEmpty) return [];
    return history.map((r) {
      return FlSpot(
        r.timestamp.millisecondsSinceEpoch.toDouble(),
        r.temperature,
      );
    }).toList();
  }

  LineChartBarData _temperatureLine(List<FlSpot> spots) {
    final lineColor = isBreach ? AppColors.error : AppColors.accent;

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.2,
      color: lineColor,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: isBreach
          ? BarAreaData(
              show: true,
              color: AppColors.error.withValues(alpha: 0.15),
            )
          : BarAreaData(
              show: true,
              color: AppColors.accent.withValues(alpha: 0.08),
            ),
    );
  }

  FlTitlesData _titlesData(
    double minX,
    double maxX,
    double minY,
    double maxY,
  ) {
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          interval: _xInterval(minX, maxX),
          getTitlesWidget: (value, meta) {
            final dt = DateTime.fromMillisecondsSinceEpoch(value.toInt());
            return SideTitleWidget(
              axisSide: meta.axisSide,
              child: Text(
                DateFormat.Hm().format(dt),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondaryDark,
                  fontSize: 10,
                ),
              ),
            );
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          interval: _yInterval(minY, maxY),
          getTitlesWidget: (value, meta) {
            return Text(
              '${value.toInt()}°',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondaryDark,
                fontSize: 10,
              ),
            );
          },
        ),
      ),
    );
  }

  double _xInterval(double minX, double maxX) {
    final range = maxX - minX;
    if (range <= 0) return 1;
    // Show ~5-6 labels on the X axis.
    return range / 5;
  }

  double _yInterval(double minY, double maxY) {
    final range = maxY - minY;
    if (range <= 4) return 1;
    if (range <= 10) return 2;
    return 5;
  }
}

// ---------------------------------------------------------------------------
// Disconnected overlay
// ---------------------------------------------------------------------------

class _DisconnectedOverlay extends StatelessWidget {
  const _DisconnectedOverlay({required this.history});

  final List<TelemetryRecord> history;

  @override
  Widget build(BuildContext context) {
    final lastTime = history.isNotEmpty
        ? DateFormat('HH:mm').format(history.last.timestamp.toLocal())
        : '--:--';

    return SizedBox(
      height: 200,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceDark.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadius.input),
          border: Border.all(
            color: AppColors.borderDark.withValues(alpha: 0.3),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_off_rounded,
                color: AppColors.textSecondaryDark.withValues(alpha: 0.6),
                size: 36,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'DISCONNECTED',
                style: AppTextStyles.heading3.copyWith(
                  color: AppColors.textSecondaryDark,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Data Terakhir: $lastTime WIB',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondaryDark.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty chart placeholder
// ---------------------------------------------------------------------------

class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.threshold});

  final double threshold;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceDark.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppRadius.input),
          border: Border.all(
            color: AppColors.borderDark.withValues(alpha: 0.3),
          ),
        ),
        child: Center(
          child: Text(
            'Belum ada data telemetri',
            style: AppTextStyles.bodyRegular.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
        ),
      ),
    );
  }
}
