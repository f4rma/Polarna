import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_animations.dart';
import '../../../../core/theme/app_primitives.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/account_switcher_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/platform_summary.dart';
import '../providers/admin_provider.dart';

/// Admin dashboard showing platform-wide summary metrics.
///
/// Displays 4 stat cards: total users, active warehouses,
/// active transactions, and total revenue.
class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  @override
  void initState() {
    super.initState();
    // Load summary on first build.
    Future.microtask(
      () => ref.read(adminNotifierProvider.notifier).loadSummary(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminNotifierProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Dashboard Admin',
          style: AppTextStyles.heading2.copyWith(color: scheme.onSurface),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(adminNotifierProvider.notifier).loadSummary(),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // Account switcher at top
            const AccountSwitcherWidget(),
            const SizedBox(height: AppSpacing.lg),

            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: AppBanner(
                  message: state.errorMessage!,
                  variant: AppBannerVariant.error,
                ),
              ),
            if (state.isLoading && state.summary == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xxxl),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              Text(
                'Ringkasan Platform',
                style: AppTextStyles.heading3.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildStatGrid(context, state),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatGrid(BuildContext context, AdminState state) {
    final summary = state.summary;
    final currencyFormat = NumberFormat.compactCurrency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Column(
      children: [
        // Top row: Users + Warehouses
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.lg,
          crossAxisSpacing: AppSpacing.lg,
          childAspectRatio: 1.3,
          children: [
            _StatCard(
              icon: Icons.people,
              label: 'Total Pengguna',
              value: '${summary?.totalUsers ?? 0}',
              color: AppColors.info,
            ).fadeSlideIn(delay: AppAnim.staggerDelay(0)),
            _StatCard(
              icon: Icons.warehouse,
              label: 'Gudang Aktif',
              value: '${summary?.activeWarehouses ?? 0}',
              color: AppColors.success,
            ).fadeSlideIn(delay: AppAnim.staggerDelay(1)),
            _StatCard(
              icon: Icons.receipt_long,
              label: 'Transaksi Aktif',
              value: '${summary?.activeTransactions ?? 0}',
              color: AppColors.accent,
            ).fadeSlideIn(delay: AppAnim.staggerDelay(2)),
            _StatCard(
              icon: Icons.show_chart,
              label: 'GMV (Total Transaksi)',
              value: currencyFormat.format(summary?.grossMerchandiseValue ?? 0),
              color: AppColors.warning,
            ).fadeSlideIn(delay: AppAnim.staggerDelay(3)),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),

        // Revenue breakdown card
        _RevenueBreakdownCard(summary: summary)
            .fadeSlideIn(delay: AppAnim.staggerDelay(4)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Stat card widget
// ---------------------------------------------------------------------------

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppRoundIconAvatar(
            icon: icon,
            size: 36,
            backgroundColor: color.withValues(alpha: 0.15),
            iconColor: color,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            style: AppTextStyles.heading2.copyWith(
              color: scheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Revenue breakdown card — splits GMV into platform fee + mitra payout
// ---------------------------------------------------------------------------

class _RevenueBreakdownCard extends StatelessWidget {
  const _RevenueBreakdownCard({required this.summary});

  final PlatformSummary? summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    
    final gmv = summary?.grossMerchandiseValue ?? 0;
    final platformRevenue = summary?.platformRevenue ?? 0;
    final mitraPayout = summary?.mitraPayout ?? 0;
    final commissionPct =
        (AppConstants.commissionRate * 100).toStringAsFixed(0);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance,
                  color: AppColors.success, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Rincian Pendapatan',
                style: AppTextStyles.heading3.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Platform Revenue (highlighted)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.small),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Pendapatan Platform',
                      style: AppTextStyles.bodyRegular.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  currencyFormat.format(platformRevenue),
                  style: AppTextStyles.heading1.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // GMV row
          _BreakdownRow(
            label: 'GMV (Total Transaksi)',
            value: currencyFormat.format(gmv),
            color: scheme.onSurfaceVariant,
          ),
          const Divider(height: AppSpacing.lg),

          // Mitra payout
          _BreakdownRow(
            label: 'Disalurkan ke Mitra',
            sublabel: '${100 - int.parse(commissionPct)}% dari GMV',
            value: currencyFormat.format(mitraPayout),
            color: scheme.onSurface,
          ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.value,
    required this.color,
    this.sublabel,
  });

  final String label;
  final String value;
  final Color color;
  final String? sublabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTextStyles.bodyRegular.copyWith(color: color),
            ),
            if (sublabel != null)
              Text(
                sublabel!,
                style: AppTextStyles.caption.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        Text(
          value,
          style: AppTextStyles.bodyLarge.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
