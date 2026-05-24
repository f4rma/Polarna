import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_form_primitives.dart';
import '../../../../core/theme/app_primitives.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../telemetry/presentation/pages/temperature_monitoring_page.dart';
import '../../domain/entities/booking_entity.dart';

/// Detail Pemesanan UMKM — menampilkan QR code untuk check-in/check-out.
///
/// Behavior berdasarkan status:
/// - `paid`: tampilkan QR check-in (besar, "Tunjukkan ke petugas gudang")
/// - `active`: tampilkan QR check-out ("Tunjukkan saat ambil barang")
/// - `completed`: tampilkan ikon lock + "Sewa telah berakhir"
/// - `cancelled`: status badge "Dibatalkan"
class UmkmBookingDetailPage extends ConsumerWidget {
  const UmkmBookingDetailPage({super.key, required this.booking});

  final BookingEntity booking;

  String get _shortId =>
      'POL-${booking.id.substring(0, booking.id.length < 6 ? booking.id.length : 6).toUpperCase()}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Pemesanan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            _StatusBadge(status: booking.status),
            const SizedBox(height: AppSpacing.lg),
            _MitraInfoCard(warehouseId: booking.warehouseId),
            const SizedBox(height: AppSpacing.lg),
            _QrSection(booking: booking, shortId: _shortId),
            const SizedBox(height: AppSpacing.xxl),
            _DetailSection(booking: booking, shortId: _shortId),
            const SizedBox(height: AppSpacing.xxl),
            _ActionButtons(booking: booking),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status badge (top of page)
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;

    switch (status) {
      case BookingStatus.paid:
        label = '● MENUNGGU CHECK-IN';
        color = AppColors.warning;
        break;
      case BookingStatus.active:
        label = '● SEWA AKTIF';
        color = AppColors.success;
        break;
      case BookingStatus.completed:
        label = '● SELESAI';
        color = AppColors.textSecondaryLight;
        break;
      case BookingStatus.cancelled:
        label = '● DIBATALKAN';
        color = AppColors.error;
        break;
      case BookingStatus.pending:
        label = '● MENUNGGU PEMBAYARAN';
        color = AppColors.warning;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelMedium.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mitra info card — fetches mitra name from warehouse → users
// ---------------------------------------------------------------------------

class _MitraInfoCard extends StatelessWidget {
  const _MitraInfoCard({required this.warehouseId});

  final String warehouseId;

  Future<Map<String, String>> _fetchMitra() async {
    try {
      final whSnap = await FirebaseFirestore.instance
          .collection('warehouses')
          .doc(warehouseId)
          .get();
      final mitraId = whSnap.data()?['mitraId'] as String?;
      if (mitraId == null) {
        return {'fullName': 'Mitra', 'phoneNumber': ''};
      }
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(mitraId)
          .get();
      final data = userSnap.data();
      if (data == null) return {'fullName': 'Mitra', 'phoneNumber': ''};
      return {
        'fullName': (data['fullName'] as String?) ?? 'Mitra',
        'phoneNumber': (data['phoneNumber'] as String?) ?? '',
      };
    } catch (_) {
      return {'fullName': 'Mitra', 'phoneNumber': ''};
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<Map<String, String>>(
      future: _fetchMitra(),
      builder: (context, snapshot) {
        final fullName = snapshot.data?['fullName'] ?? 'Memuat...';
        final phone = snapshot.data?['phoneNumber'] ?? '';

        return AppCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  fullName.isNotEmpty ? fullName[0].toUpperCase() : 'M',
                  style: AppTextStyles.heading3.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: AppTextStyles.heading3.copyWith(
                        color: scheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.verified,
                            size: 14, color: AppColors.success),
                        const SizedBox(width: 4),
                        Text(
                          'Mitra Terverifikasi',
                          style: AppTextStyles.caption.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: phone.isNotEmpty ? 'Hubungi $phone' : 'Chat',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        phone.isNotEmpty
                            ? 'Kontak: $phone'
                            : 'Fitur chat segera hadir',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_outlined),
                color: AppColors.accent,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// QR section (or lock icon for completed)
// ---------------------------------------------------------------------------

class _QrSection extends StatelessWidget {
  const _QrSection({required this.booking, required this.shortId});

  final BookingEntity booking;
  final String shortId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Completed / cancelled — tampilkan lock icon
    if (booking.status == BookingStatus.completed ||
        booking.status == BookingStatus.cancelled) {
      return AppCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
          child: Column(
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: scheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                booking.status == BookingStatus.completed
                    ? 'Sewa telah berakhir'
                    : 'Booking dibatalkan',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                shortId,
                style: AppTextStyles.caption.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Paid / active — tampilkan QR
    final caption = booking.status == BookingStatus.paid
        ? 'Tunjukkan QR ini ke petugas gudang\nsaat menyerahkan barang'
        : 'QR Check-Out — tunjukkan saat\nmengambil barang dari gudang';

    return AppCard(
      child: Column(
        children: [
          Text(
            caption,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyRegular.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: QrImageView(
              data: booking.qrCodeData ?? booking.id,
              size: 220,
              backgroundColor: Colors.white,
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            shortId,
            style: AppTextStyles.heading3.copyWith(
              color: scheme.onSurface,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('QR Code disimpan')),
              );
            },
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Unduh QR Code'),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail section
// ---------------------------------------------------------------------------

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.booking, required this.shortId});

  final BookingEntity booking;
  final String shortId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('dd MMM yyyy', 'id_ID');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DETAIL PEMESANAN',
            style: AppTextStyles.labelMedium.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Row(label: 'ID Transaksi', value: shortId),
          _Row(label: 'Gudang', value: booking.warehouseName),
          _Row(
            label: 'Tanggal Mulai',
            value: dateFormat.format(booking.startDate),
          ),
          _Row(
            label: 'Tanggal Berakhir',
            value: dateFormat.format(booking.endDate),
          ),
          _Row(label: 'Volume', value: '${booking.volumeM3.toStringAsFixed(1)} m³'),
          _Row(label: 'Durasi', value: '${booking.durationDays} hari'),
          const Divider(height: AppSpacing.xl),
          _Row(
            label: 'Total Pembayaran',
            value: CurrencyUtils.formatRupiah(booking.totalCost),
            valueStyle: AppTextStyles.heading3.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Status Bayar',
                style: AppTextStyles.bodyRegular.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              AppStatusBadge(
                label: 'TERBAYAR',
                color: AppColors.success,
                bgColor: AppColors.successSoft,
              ),
            ],
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
    this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyRegular.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: valueStyle ??
                  AppTextStyles.bodyRegular.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Action buttons
// ---------------------------------------------------------------------------

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.booking});

  final BookingEntity booking;

  @override
  Widget build(BuildContext context) {
    final isActiveOrPaid = booking.status == BookingStatus.paid ||
        booking.status == BookingStatus.active;

    return Column(
      children: [
        if (isActiveOrPaid) ...[
          AppPrimaryButton(
            label: 'Pantau Suhu Sekarang',
            icon: Icons.thermostat,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TemperatureMonitoringPage(
                    warehouseId: booking.warehouseId,
                    warehouseName: booking.warehouseName,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        AppSecondaryButton(
          label: 'Hubungi Mitra',
          icon: Icons.chat_outlined,
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Fitur chat segera hadir')),
            );
          },
        ),
        if (booking.status == BookingStatus.completed) ...[
          const SizedBox(height: AppSpacing.md),
          AppPrimaryButton(
            label: 'Beri Ulasan',
            icon: Icons.rate_review_outlined,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fitur ulasan segera hadir')),
              );
            },
          ),
        ],
      ],
    );
  }
}
