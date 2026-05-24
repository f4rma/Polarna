import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_form_primitives.dart';
import '../../../../core/theme/app_primitives.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../telemetry/presentation/pages/temperature_monitoring_page.dart';
import '../../domain/entities/booking_entity.dart';
import '../providers/booking_provider.dart';
import 'mitra_booking_detail_page.dart';
import 'umkm_booking_detail_page.dart';

/// Tab filter for booking history.
enum _HistoryTab { semua, aktif, selesai, dibatalkan }

/// Booking history page — shows tabs (Semua/Aktif/Selesai/Dibatalkan)
/// with booking cards and empty state.
class BookingHistoryPage extends ConsumerStatefulWidget {
  const BookingHistoryPage({super.key});

  @override
  ConsumerState<BookingHistoryPage> createState() => _BookingHistoryPageState();
}

class _BookingHistoryPageState extends ConsumerState<BookingHistoryPage> {
  _HistoryTab _selectedTab = _HistoryTab.semua;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).valueOrNull;
      final uid = user?.uid ?? '';
      if (uid.isEmpty) return;

      // Mitra sees bookings made AT their warehouses; UMKM sees their own
      // bookings as a tenant. The data layer handles the warehouse lookup.
      if (user?.role == UserRole.mitra) {
        ref.read(bookingProvider.notifier).getMitraHistory(mitraId: uid);
      } else {
        ref.read(bookingProvider.notifier).getHistory(umkmId: uid);
      }
    });
  }

  List<BookingEntity> _filteredBookings(List<BookingEntity> all) {
    switch (_selectedTab) {
      case _HistoryTab.semua:
        return all;
      case _HistoryTab.aktif:
        return all
            .where((b) =>
                b.status == BookingStatus.active ||
                b.status == BookingStatus.paid)
            .toList();
      case _HistoryTab.selesai:
        return all.where((b) => b.status == BookingStatus.completed).toList();
      case _HistoryTab.dibatalkan:
        return all.where((b) => b.status == BookingStatus.cancelled).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookingProvider);
    final filtered = _filteredBookings(state.history);
    final role = ref.watch(authProvider).valueOrNull?.role;
    final isMitra = role == UserRole.mitra;

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Pemesanan')),
      body: Column(
        children: [
          // Tab bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: _HistoryTab.values.map((tab) {
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: AppFilterChip(
                    label: _tabLabel(tab),
                    selected: _selectedTab == tab,
                    onTap: () => setState(() => _selectedTab = tab),
                  ),
                );
              }).toList(),
            ),
          ),

          // Content
          Expanded(
            child: state.isLoadingHistory
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? _EmptyState(
                        isMitra: isMitra,
                        onCta: () => context.go(
                          isMitra
                              ? RouteConstants.mitraDashboard
                              : RouteConstants.umkmHome,
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, index) {
                          return _BookingCard(booking: filtered[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _tabLabel(_HistoryTab tab) {
    switch (tab) {
      case _HistoryTab.semua:
        return 'Semua';
      case _HistoryTab.aktif:
        return 'Aktif';
      case _HistoryTab.selesai:
        return 'Selesai';
      case _HistoryTab.dibatalkan:
        return 'Dibatalkan';
    }
  }
}

// ---------------------------------------------------------------------------
// Private widgets
// ---------------------------------------------------------------------------

class _BookingCard extends ConsumerWidget {
  const _BookingCard({required this.booking});

  final BookingEntity booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('dd MMM yyyy', 'id_ID');
    final role = ref.watch(authProvider).valueOrNull?.role;
    final isMitra = role == UserRole.mitra;

    return AppCard(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => isMitra
                ? MitraBookingDetailPage(booking: booking)
                : UmkmBookingDetailPage(booking: booking),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Warehouse icon placeholder
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.warehouse_outlined,
                  color: AppColors.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.warehouseName,
                      style: AppTextStyles.heading3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${dateFormat.format(booking.startDate)} - '
                      '${dateFormat.format(booking.endDate)}',
                      style: AppTextStyles.caption.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              _statusBadge(booking.status),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${booking.volumeM3.toStringAsFixed(1)} m³',
                style: AppTextStyles.bodyRegular.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              Text(
                CurrencyUtils.formatRupiah(booking.totalCost),
                style: AppTextStyles.bodyRegular.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (booking.status == BookingStatus.active)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  // Use push (not go) so it works from both UMKM and Mitra shells
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TemperatureMonitoringPage(
                        warehouseId: booking.warehouseId,
                        warehouseName: booking.warehouseName,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.thermostat, size: 16),
                label: const Text('Pantau Suhu'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryLight,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Lihat Detail'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusBadge(BookingStatus status) {
    switch (status) {
      case BookingStatus.paid:
        return AppStatusBadge(
          label: 'MENUNGGU',
          color: AppColors.warning,
          bgColor: AppColors.warningSoft,
        );
      case BookingStatus.active:
        return AppStatusBadge.active();
      case BookingStatus.completed:
        return AppStatusBadge.completed();
      case BookingStatus.cancelled:
        return AppStatusBadge.cancelled();
      case BookingStatus.pending:
        return AppStatusBadge.unpaid();
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCta, this.isMitra = false});

  final VoidCallback onCta;
  final bool isMitra;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: scheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Belum Ada Transaksi',
              style: AppTextStyles.heading3.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              isMitra
                  ? 'Belum ada UMKM yang menyewa gudang Anda'
                  : 'Mulai cari gudang untuk menyimpan produk Anda',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyRegular.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppPrimaryButton(
              label: isMitra ? 'Kembali ke Beranda' : 'Cari Gudang Sekarang',
              onPressed: onCta,
            ),
          ],
        ),
      ),
    );
  }
}
