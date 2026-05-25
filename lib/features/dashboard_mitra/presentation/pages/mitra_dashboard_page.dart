import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_primitives.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../booking/domain/entities/booking_entity.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/dashboard_widgets.dart';

/// Mitra Dashboard — dark theme landing page.
///
/// Displays greeting, 4 stat cards (2×2 grid), IoT status bar,
/// active transactions list (top 3), and a "Lihat Semua" link.
/// (Requirement 8.1, 8.4)
class MitraDashboardPage extends ConsumerWidget {
  const MitraDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final summaryAsync = ref.watch(revenueSummaryProvider);
    final transactionsAsync = ref.watch(activeTransactionsProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(revenueSummaryProvider);
            ref.invalidate(activeTransactionsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _GreetingHeader(name: user?.fullName ?? 'Mitra'),
              const SizedBox(height: AppSpacing.xxl),
              summaryAsync.when(
                data: (summary) =>
                    DashboardStatCardsGrid(summary: summary),
                loading: () => const SizedBox(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, st) => AppCard(
                  color: AppColors.surfaceDark,
                  child: Text(
                    'Gagal memuat data. Tarik untuk refresh.',
                    style: AppTextStyles.bodyRegular.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              _ActiveTransactionsSection(
                transactionsAsync: transactionsAsync,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Greeting header with notification bell
// ---------------------------------------------------------------------------

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.name});

  final String name;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Selamat Pagi';
    if (hour < 17) return 'Selamat Siang';
    return 'Selamat Malam';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_greeting,',
                style: AppTextStyles.bodyRegular.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                name,
                style: AppTextStyles.heading1.copyWith(
                  color: AppColors.textPrimaryDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            // TODO: Navigate to notifications
          },
          icon: const Icon(
            Icons.notifications_outlined,
            color: AppColors.textPrimaryDark,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Active transactions section
// ---------------------------------------------------------------------------

class _ActiveTransactionsSection extends StatelessWidget {
  const _ActiveTransactionsSection({required this.transactionsAsync});

  final AsyncValue<List<BookingEntity>> transactionsAsync;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Transaksi Aktif',
              style: AppTextStyles.heading3.copyWith(
                color: AppColors.textPrimaryDark,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/mitra/revenue-report'),
              child: Text(
                'Lihat Semua',
                style: AppTextStyles.bodyRegular.copyWith(
                  color: AppColors.accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        transactionsAsync.when(
          data: (transactions) {
            if (transactions.isEmpty) {
              return AppCard(
                color: AppColors.surfaceDark,
                child: Center(
                  child: Text(
                    'Belum ada transaksi aktif.',
                    style: AppTextStyles.bodyRegular.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                ),
              );
            }
            final top3 = transactions.take(3).toList();
            return Column(
              children: top3
                  .map((t) => DashboardTransactionTile(booking: t))
                  .toList(),
            );
          },
          loading: () => const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, st) => Text(
            'Gagal memuat transaksi.',
            style: AppTextStyles.bodyRegular.copyWith(
              color: AppColors.textSecondaryDark,
            ),
          ),
        ),
      ],
    );
  }
}
