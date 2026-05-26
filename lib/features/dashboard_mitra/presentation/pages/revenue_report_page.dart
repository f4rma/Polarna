import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_primitives.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../booking/domain/entities/booking_entity.dart';
import '../../domain/entities/revenue_summary.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/revenue_chart_widget.dart';

/// Revenue Report page — tabs (Hari Ini / Bulan Ini / Tahun Ini),
/// stat cards, 12-month bar chart, transaction table, CSV export button.
/// (Requirement 8.1, 8.2, 8.6)
class RevenueReportPage extends ConsumerStatefulWidget {
  const RevenueReportPage({super.key});

  @override
  ConsumerState<RevenueReportPage> createState() => _RevenueReportPageState();
}

class _RevenueReportPageState extends ConsumerState<RevenueReportPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(revenueSummaryProvider);
    final transactionsAsync = ref.watch(activeTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Pendapatan'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textSecondaryDark,
          tabs: const [
            Tab(text: 'Hari Ini'),
            Tab(text: 'Bulan Ini'),
            Tab(text: 'Tahun Ini'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TabContent(
            summaryAsync: summaryAsync,
            transactionsAsync: transactionsAsync,
            period: _Period.daily,
          ),
          _TabContent(
            summaryAsync: summaryAsync,
            transactionsAsync: transactionsAsync,
            period: _Period.monthly,
          ),
          _TabContent(
            summaryAsync: summaryAsync,
            transactionsAsync: transactionsAsync,
            period: _Period.yearly,
          ),
        ],
      ),
    );
  }
}

enum _Period { daily, monthly, yearly }

class _TabContent extends ConsumerWidget {
  const _TabContent({
    required this.summaryAsync,
    required this.transactionsAsync,
    required this.period,
  });

  final AsyncValue<RevenueSummary> summaryAsync;
  final AsyncValue<List<BookingEntity>> transactionsAsync;
  final _Period period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        summaryAsync.when(
          data: (s) => _StatRow(summary: s, period: period),
          loading: () => const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, st) => const SizedBox.shrink(),
        ),
        const SizedBox(height: AppSpacing.xxl),
        summaryAsync.when(
          data: (s) => RevenueBarChart(monthlyHistory: s.monthlyRevenueHistory),
          loading: () => const SizedBox(height: 220),
          error: (e, st) => const SizedBox.shrink(),
        ),
        const SizedBox(height: AppSpacing.xxl),
        _TransactionTable(transactionsAsync: transactionsAsync),
        const SizedBox(height: AppSpacing.lg),
        _ExportCsvButton(ref: ref),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.summary, required this.period});

  final RevenueSummary summary;
  final _Period period;

  @override
  Widget build(BuildContext context) {
    final revenue = switch (period) {
      _Period.daily => summary.dailyRevenue,
      _Period.monthly => summary.monthlyRevenue,
      _Period.yearly => summary.monthlyRevenue * 12,
    };
    return Row(
      children: [
        Expanded(
          child: AppCard(
            color: AppColors.surfaceDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pendapatan', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondaryDark)),
                const SizedBox(height: AppSpacing.xs),
                Text(CurrencyUtils.formatRupiahCompact(revenue), style: AppTextStyles.heading2.copyWith(color: AppColors.accent)),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: AppCard(
            color: AppColors.surfaceDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Transaksi Aktif', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondaryDark)),
                const SizedBox(height: AppSpacing.xs),
                Text('${summary.activeTransactions}', style: AppTextStyles.heading2.copyWith(color: AppColors.textPrimaryDark)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TransactionTable extends StatelessWidget {
  const _TransactionTable({required this.transactionsAsync});

  final AsyncValue<List<BookingEntity>> transactionsAsync;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.surfaceDark,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daftar Transaksi',
            style: AppTextStyles.heading3.copyWith(
              color: AppColors.textPrimaryDark,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          transactionsAsync.when(
            data: (transactions) {
              if (transactions.isEmpty) {
                return Text(
                  'Belum ada transaksi.',
                  style: AppTextStyles.bodyRegular.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
                );
              }
              return _buildTable(transactions);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Text(
              'Gagal memuat data.',
              style: AppTextStyles.bodyRegular.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(List<BookingEntity> transactions) {
    final dateFormat = DateFormat('dd/MM/yy');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingTextStyle: AppTextStyles.labelMedium.copyWith(
          color: AppColors.textSecondaryDark,
        ),
        dataTextStyle: AppTextStyles.caption.copyWith(
          color: AppColors.textPrimaryDark,
        ),
        columnSpacing: AppSpacing.lg,
        columns: const [
          DataColumn(label: Text('UMKM')),
          DataColumn(label: Text('Volume')),
          DataColumn(label: Text('Mulai')),
          DataColumn(label: Text('Berakhir')),
          DataColumn(label: Text('Status')),
        ],
        rows: transactions.map((t) {
          return DataRow(cells: [
            DataCell(Text(
              t.warehouseName,
              overflow: TextOverflow.ellipsis,
            )),
            DataCell(Text('${t.volumeM3} m³')),
            DataCell(Text(dateFormat.format(t.startDate))),
            DataCell(Text(dateFormat.format(t.endDate))),
            DataCell(_paymentBadge(t.paymentStatus)),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _paymentBadge(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paid:
        return AppStatusBadge.paid();
      case PaymentStatus.unpaid:
        return AppStatusBadge.unpaid();
      case PaymentStatus.refunded:
        return const AppStatusBadge(
          label: 'REFUND',
          color: AppColors.neutralStrong,
          bgColor: AppColors.neutralSoft,
        );
    }
  }
}

class _ExportCsvButton extends StatelessWidget {
  const _ExportCsvButton({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final dashState = ref.watch(dashboardNotifierProvider);
    final user = ref.watch(authProvider).valueOrNull;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: dashState.isExporting || user == null
            ? null
            : () async {
                final notifier =
                    ref.read(dashboardNotifierProvider.notifier);
                final csv = await notifier.exportCsv(user.uid);
                if (csv != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('CSV berhasil diekspor'),
                    ),
                  );
                }
              },
        icon: dashState.isExporting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download_rounded),
        label: const Text('Ekspor CSV'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
          ),
        ),
      ),
    );
  }
}
