import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_animations.dart';
import '../../../../core/theme/app_primitives.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../booking/domain/entities/booking_entity.dart';
import '../../../booking/presentation/providers/booking_provider.dart';
import '../providers/warehouse_provider.dart';
import '../widgets/warehouse_card_widget.dart';

/// UMKM Home Dashboard — greeting, active booking carousel, gudang terdekat.
class UmkmHomePage extends ConsumerStatefulWidget {
  const UmkmHomePage({super.key});

  @override
  ConsumerState<UmkmHomePage> createState() => _UmkmHomePageState();
}

class _UmkmHomePageState extends ConsumerState<UmkmHomePage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(warehouseProvider.notifier).search();
      final uid = ref.read(authProvider).valueOrNull?.uid;
      if (uid != null) {
        ref.read(bookingProvider.notifier).getHistory(umkmId: uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final user = authState.valueOrNull;
    final warehouseState = ref.watch(warehouseProvider);

    final greeting = _getGreeting();
    final displayName = user?.fullName ?? 'Pengguna';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(warehouseProvider.notifier).refresh();
            final uid = ref.read(authProvider).valueOrNull?.uid;
            if (uid != null) {
              await ref.read(bookingProvider.notifier).getHistory(umkmId: uid);
            }
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              // Header greeting
              const SizedBox(height: AppSpacing.md),
              Text(
                '$greeting,',
                style: AppTextStyles.bodyRegular.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Text(
                displayName,
                style: AppTextStyles.heading1.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Quick action cards
              _QuickActions(
                onSearchTap: () => context.go(RouteConstants.umkmSearch),
                onBookingsTap: () => context.go(RouteConstants.umkmBookings),
              ).fadeSlideIn(delay: 80.msDelay),
              const SizedBox(height: AppSpacing.xxl),

              // Active booking carousel section
              const _ActiveBookingCarousel().fadeSlideIn(delay: 160.msDelay),
              const SizedBox(height: AppSpacing.xxl),

              // Gudang tersedia
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Gudang Tersedia',
                    style: AppTextStyles.heading3.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go(RouteConstants.umkmSearch),
                    child: Text(
                      'Lihat Semua',
                      style: AppTextStyles.bodyRegular.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              if (warehouseState.isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xxl),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (warehouseState.warehouses.isEmpty)
                _EmptyWarehouseHint(
                  onSearch: () => context.go(RouteConstants.umkmSearch),
                )
              else
                ...warehouseState.warehouses.take(3).toList().asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: WarehouseCardWidget(
                          warehouse: entry.value,
                          onTap: () => context.push(
                            RouteConstants.warehouseDetailPath(entry.value.id),
                          ),
                        ).fadeSlideIn(
                          delay: AppAnim.staggerDelay(entry.key),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Selamat Pagi';
    if (hour < 17) return 'Selamat Siang';
    return 'Selamat Malam';
  }
}

// ---------------------------------------------------------------------------
// Quick Actions
// ---------------------------------------------------------------------------

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onSearchTap,
    required this.onBookingsTap,
  });

  final VoidCallback onSearchTap;
  final VoidCallback onBookingsTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            icon: Icons.search,
            label: 'Cari Gudang',
            color: AppColors.accent,
            onTap: onSearchTap,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _ActionCard(
            icon: Icons.receipt_long,
            label: 'Transaksi',
            color: scheme.primary,
            onTap: onBookingsTap,
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Active Booking Carousel
// ---------------------------------------------------------------------------

class _ActiveBookingCarousel extends ConsumerStatefulWidget {
  const _ActiveBookingCarousel();

  @override
  ConsumerState<_ActiveBookingCarousel> createState() =>
      _ActiveBookingCarouselState();
}

class _ActiveBookingCarouselState
    extends ConsumerState<_ActiveBookingCarousel> {
  int _currentPage = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bookingState = ref.watch(bookingProvider);
    final activeBookings = bookingState.history
        .where((b) => b.status == BookingStatus.active)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Text(
              'Booking Aktif',
              style: AppTextStyles.heading3.copyWith(
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '${activeBookings.length}',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        if (bookingState.isLoadingHistory)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xxl),
              child: CircularProgressIndicator(),
            ),
          )
        else if (activeBookings.isEmpty)
          _EmptyBookingCard()
        else ...[
          // Carousel
          SizedBox(
            height: 180,
            child: PageView.builder(
              controller: _pageController,
              itemCount: activeBookings.length,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: _ActiveBookingCard(
                    booking: activeBookings[index],
                  ),
                );
              },
            ),
          ),

          // Page indicator dots
          if (activeBookings.length > 1) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                activeBookings.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentPage == index ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? AppColors.accent
                        : scheme.outlineVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Active Booking Card — dark-themed with cyan accents
// ---------------------------------------------------------------------------

class _ActiveBookingCard extends ConsumerWidget {
  const _ActiveBookingCard({required this.booking});

  final BookingEntity booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('dd MMM yyyy', 'id_ID');
    final now = DateTime.now();
    final daysRemaining = booking.endDate.difference(now).inDays;
    final daysRemainingText =
        daysRemaining > 0 ? '$daysRemaining hari lagi' : 'Berakhir hari ini';

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primaryLight,
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: const [
          BoxShadow(
            color: Color(0x331A3C50),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: warehouse name + status badge
          Row(
            children: [
              Expanded(
                child: Text(
                  booking.warehouseName,
                  style: AppTextStyles.heading3.copyWith(
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  'AKTIF',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Volume & duration info
          Row(
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 14, color: AppColors.accent),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${booking.volumeM3.toStringAsFixed(0)} m³',
                style: AppTextStyles.bodyRegular.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Icon(Icons.schedule, size: 14, color: AppColors.accent),
              const SizedBox(width: AppSpacing.xs),
              Text(
                daysRemainingText,
                style: AppTextStyles.bodyRegular.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          // Date range
          Text(
            '${dateFormat.format(booking.startDate)} - ${dateFormat.format(booking.endDate)}',
            style: AppTextStyles.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),

          const Spacer(),

          // Bottom: "Pantau Suhu" button
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                context.push(
                  RouteConstants.monitoringPath(booking.warehouseId),
                );
              },
              icon: const Icon(Icons.thermostat, size: 16),
              label: const Text('Pantau Suhu'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                textStyle: AppTextStyles.bodyRegular.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty booking card
// ---------------------------------------------------------------------------

class _EmptyBookingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.outlineVariant.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Text(
              'Belum ada booking aktif.\nCari gudang untuk mulai menyewa.',
              style: AppTextStyles.bodyRegular.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty warehouse hint
// ---------------------------------------------------------------------------

class _EmptyWarehouseHint extends StatelessWidget {
  const _EmptyWarehouseHint({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          Icon(
            Icons.warehouse_outlined,
            size: 48,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Belum ada gudang tersedia',
            style: AppTextStyles.bodyRegular.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: onSearch,
            child: const Text('Cari Gudang'),
          ),
        ],
      ),
    );
  }
}
