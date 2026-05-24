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
import '../../domain/entities/booking_entity.dart';
import '../widgets/qr_code_widget.dart';

/// Booking detail page — shows different layouts for active vs completed.
///
/// Active: QR code + detail table + "Pantau Suhu Sekarang" + "Hubungi Mitra".
/// Completed: lock icon + "Sewa telah berakhir" + detail table + rating.
class BookingDetailPage extends ConsumerWidget {
  const BookingDetailPage({super.key, required this.booking});

  final BookingEntity booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Pemesanan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: booking.status == BookingStatus.active
            ? _ActiveBookingContent(booking: booking)
            : _CompletedBookingContent(booking: booking),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Active booking content
// ---------------------------------------------------------------------------

class _ActiveBookingContent extends StatelessWidget {
  const _ActiveBookingContent({required this.booking});

  final BookingEntity booking;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // QR Code
        if (booking.qrCodeData != null) ...[
          BookingQrCodeWidget(
            data: booking.qrCodeData!,
            bookingId: booking.id,
          ),
          const SizedBox(height: AppSpacing.md),
          AppSecondaryButton(
            label: 'Unduh QR Code',
            icon: Icons.download,
            onPressed: () {
              // Download functionality — placeholder
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('QR Code disimpan')),
              );
            },
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),

        // Detail table
        _DetailTable(booking: booking),
        const SizedBox(height: AppSpacing.xxl),

        // Action buttons
        AppPrimaryButton(
          label: 'Pantau Suhu Sekarang',
          icon: Icons.thermostat,
          onPressed: () => context.go(
            RouteConstants.monitoringPath(booking.warehouseId),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppSecondaryButton(
          label: 'Hubungi Mitra',
          icon: Icons.chat_outlined,
          onPressed: () {
            // Contact mitra — placeholder
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Completed booking content
// ---------------------------------------------------------------------------

class _CompletedBookingContent extends StatelessWidget {
  const _CompletedBookingContent({required this.booking});

  final BookingEntity booking;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Lock icon + message
        Icon(
          Icons.lock_outline,
          size: 56,
          color: scheme.onSurface.withValues(alpha: 0.4),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Sewa telah berakhir',
          style: AppTextStyles.heading3.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),

        // Detail table
        _DetailTable(booking: booking),
        const SizedBox(height: AppSpacing.xxl),

        // Rating section
        AppCard(
          child: Column(
            children: [
              Text(
                'Beri penilaian pengalaman Anda',
                style: AppTextStyles.bodyRegular.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    onPressed: () {},
                    icon: Icon(
                      Icons.star_border,
                      color: AppColors.warning,
                      size: 32,
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Action buttons
        AppPrimaryButton(
          label: 'Beri Ulasan',
          icon: Icons.rate_review_outlined,
          onPressed: () {
            // Review functionality — placeholder
          },
        ),
        const SizedBox(height: AppSpacing.md),
        AppSecondaryButton(
          label: 'Hubungi Mitra',
          icon: Icons.chat_outlined,
          onPressed: () {
            // Contact mitra — placeholder
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared detail table
// ---------------------------------------------------------------------------

class _DetailTable extends StatelessWidget {
  const _DetailTable({required this.booking});

  final BookingEntity booking;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('dd MMM yyyy', 'id_ID');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detail Pemesanan',
            style: AppTextStyles.heading3.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Row(label: 'ID Transaksi', value: booking.id),
          _Row(label: 'Gudang', value: booking.warehouseName),
          _Row(
            label: 'Tanggal Mulai',
            value: dateFormat.format(booking.startDate),
          ),
          _Row(
            label: 'Tanggal Berakhir',
            value: dateFormat.format(booking.endDate),
          ),
          _Row(label: 'Durasi', value: '${booking.durationDays} hari'),
          _Row(
            label: 'Volume',
            value: '${booking.volumeM3.toStringAsFixed(1)} m³',
          ),
          _Row(
            label: 'Harga',
            value: CurrencyUtils.formatPricePerM3PerDay(
              booking.pricePerM3PerDay,
            ),
          ),
          const Divider(height: AppSpacing.lg),
          _Row(
            label: 'Total',
            value: CurrencyUtils.formatRupiah(booking.totalCost),
            isBold: true,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  final String label;
  final String value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyRegular.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTextStyles.bodyRegular.copyWith(
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
