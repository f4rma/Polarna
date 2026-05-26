import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_primitives.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_utils.dart';

/// 12-month revenue bar chart using fl_chart.
///
/// Displays monthly revenue history with tooltips showing
/// compact Rupiah values. (Requirement 8.2)
class RevenueBarChart extends StatelessWidget {
  const RevenueBarChart({super.key, required this.monthlyHistory});

  final List<double> monthlyHistory;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.surfaceDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pendapatan 12 Bulan Terakhir',
            style: AppTextStyles.heading3.copyWith(
              color: AppColors.textPrimaryDark,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _maxY,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        CurrencyUtils.formatRupiahCompact(rod.toY),
                        AppTextStyles.caption.copyWith(
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          CurrencyUtils.formatRupiahCompact(value),
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondaryDark,
                            fontSize: 9,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            _monthLabel(value.toInt()),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondaryDark,
                              fontSize: 9,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.borderDark.withValues(alpha: 0.3),
                    strokeWidth: 0.5,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: _barGroups,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double get _maxY {
    if (monthlyHistory.isEmpty) return 1;
    final max = monthlyHistory.reduce((a, b) => a > b ? a : b);
    return max == 0 ? 1 : max * 1.2;
  }

  List<BarChartGroupData> get _barGroups {
    return List.generate(monthlyHistory.length, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: monthlyHistory[i],
            color: AppColors.accent,
            width: 14,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      );
    });
  }

  String _monthLabel(int index) {
    final now = DateTime.now();
    final month = DateTime(now.year, now.month - (11 - index));
    return DateFormat.MMM('id_ID').format(month);
  }
}
