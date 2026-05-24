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
import '../providers/booking_provider.dart';
import '../widgets/qr_code_widget.dart';

/// Booking confirmation page — shows payment processing → success screen
/// with QR code, transaction summary, and navigation buttons.
class BookingConfirmationPage extends ConsumerWidget {
  const BookingConfirmationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bookingProvider);
    final scheme = Theme.of(context).colorScheme;

    // Processing state
    if (state.phase == BookingPhase.processingPayment) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'Memproses pembayaran...',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Failed state
    if (state.phase == BookingPhase.paymentFailed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pembayaran Gagal')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  state.errorMessage ?? 'Pembayaran gagal',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.xxl),
                AppPrimaryButton(
                  label: 'Kembali',
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Success state
    final booking = state.activeBooking;
    if (booking == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Konfirmasi')),
        body: const Center(child: Text('Tidak ada data pemesanan')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pemesanan Berhasil'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            // Success icon
            const Icon(
              Icons.check_circle,
              size: 72,
              color: AppColors.success,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Pembayaran Berhasil!',
              style: AppTextStyles.heading2.copyWith(
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // QR Code
            if (booking.qrCodeData != null)
              BookingQrCodeWidget(
                data: booking.qrCodeData!,
                bookingId: booking.id,
              ),
            const SizedBox(height: AppSpacing.xxl),

            // Transaction summary
            _TransactionSummaryCard(booking: booking),
            const SizedBox(height: AppSpacing.lg),

            // TERBAYAR badge
            AppStatusBadge.paid(),
            const SizedBox(height: AppSpacing.xxxl),

            // Action buttons
            AppPrimaryButton(
              label: 'Pantau Suhu',
              onPressed: () => context.go(
                RouteConstants.monitoringPath(booking.warehouseId),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppSecondaryButton(
              label: 'Lihat Riwayat',
              onPressed: () => context.go(RouteConstants.umkmBookings),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private widgets
// ---------------------------------------------------------------------------

class _TransactionSummaryCard extends StatelessWidget {
  const _TransactionSummaryCard({required this.booking});

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
            'Ringkasan Transaksi',
            style: AppTextStyles.heading3.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SummaryRow(label: 'ID Transaksi', value: booking.id),
          _SummaryRow(label: 'Gudang', value: booking.warehouseName),
          _SummaryRow(
            label: 'Periode',
            value:
                '${dateFormat.format(booking.startDate)} - ${dateFormat.format(booking.endDate)}',
          ),
          _SummaryRow(
            label: 'Volume',
            value: '${booking.volumeM3.toStringAsFixed(1)} m³',
          ),
          _SummaryRow(
            label: 'Total',
            value: CurrencyUtils.formatRupiah(booking.totalCost),
            isBold: true,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
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
