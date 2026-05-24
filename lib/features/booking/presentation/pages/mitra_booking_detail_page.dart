import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_form_primitives.dart';
import '../../../../core/theme/app_primitives.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../telemetry/presentation/pages/temperature_monitoring_page.dart';
import '../../domain/entities/booking_entity.dart';
import 'qr_scanner_page.dart';

/// Detail Transaksi Mitra — menampilkan info booking + tombol scan QR.
///
/// Behavior berdasarkan status:
/// - `paid`: tombol "Scan Check-In" untuk konfirmasi barang masuk
/// - `active`: tombol "Scan Check-Out" untuk konfirmasi barang diambil
/// - `completed`: badge "Sewa Selesai"
class MitraBookingDetailPage extends ConsumerStatefulWidget {
  const MitraBookingDetailPage({super.key, required this.booking});

  final BookingEntity booking;

  @override
  ConsumerState<MitraBookingDetailPage> createState() =>
      _MitraBookingDetailPageState();
}

class _MitraBookingDetailPageState
    extends ConsumerState<MitraBookingDetailPage> {
  late BookingEntity _booking;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
  }

  String get _shortId =>
      'POL-${_booking.id.substring(0, _booking.id.length < 6 ? _booking.id.length : 6).toUpperCase()}';

  Future<void> _openScanner(ScannerMode mode) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QrScannerPage(
          bookingId: _booking.id,
          mode: mode,
        ),
      ),
    );
    if (result == true && mounted) {
      // Update lokal untuk reflect status baru
      setState(() {
        _booking = BookingEntity(
          id: _booking.id,
          umkmId: _booking.umkmId,
          warehouseId: _booking.warehouseId,
          warehouseName: _booking.warehouseName,
          volumeM3: _booking.volumeM3,
          startDate: _booking.startDate,
          endDate: _booking.endDate,
          durationDays: _booking.durationDays,
          pricePerM3PerDay: _booking.pricePerM3PerDay,
          totalCost: _booking.totalCost,
          status: mode == ScannerMode.checkIn
              ? BookingStatus.active
              : BookingStatus.completed,
          paymentStatus: _booking.paymentStatus,
          qrCodeData: _booking.qrCodeData,
          createdAt: _booking.createdAt,
          updatedAt: DateTime.now().toUtc(),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Transaksi')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _UmkmInfoCard(umkmId: _booking.umkmId),
            const SizedBox(height: AppSpacing.lg),
            _TransactionInfoCard(booking: _booking, shortId: _shortId),
            const SizedBox(height: AppSpacing.lg),
            if (_booking.status == BookingStatus.active)
              _TemperatureCard(
                warehouseId: _booking.warehouseId,
                warehouseName: _booking.warehouseName,
              ),
            const SizedBox(height: AppSpacing.xxl),
            _ActionButton(
              status: _booking.status,
              onCheckIn: () => _openScanner(ScannerMode.checkIn),
              onCheckOut: () => _openScanner(ScannerMode.checkOut),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// UMKM info card (top) — fetches name + phone from Firestore
// ---------------------------------------------------------------------------

class _UmkmInfoCard extends StatelessWidget {
  const _UmkmInfoCard({required this.umkmId});

  final String umkmId;

  Future<Map<String, String>> _fetchUmkm() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(umkmId)
          .get();
      final data = snap.data();
      if (data == null) return {'fullName': 'UMKM', 'phoneNumber': ''};
      return {
        'fullName': (data['fullName'] as String?) ?? 'UMKM',
        'phoneNumber': (data['phoneNumber'] as String?) ?? '',
      };
    } catch (_) {
      return {'fullName': 'UMKM', 'phoneNumber': ''};
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<Map<String, String>>(
      future: _fetchUmkm(),
      builder: (context, snapshot) {
        final fullName = snapshot.data?['fullName'] ?? 'Memuat...';
        final phone = snapshot.data?['phoneNumber'] ?? '';

        return AppCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                child: Text(
                  fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                  style: AppTextStyles.heading3.copyWith(
                    color: AppColors.accent,
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
                          'Penyewa Terverifikasi',
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
// Transaction info card
// ---------------------------------------------------------------------------

class _TransactionInfoCard extends StatelessWidget {
  const _TransactionInfoCard({required this.booking, required this.shortId});

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
            'INFORMASI TRANSAKSI',
            style: AppTextStyles.labelMedium.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Row(label: 'ID Transaksi', value: shortId),
          _Row(label: 'Gudang', value: booking.warehouseName),
          _Row(label: 'Volume', value: '${booking.volumeM3.toStringAsFixed(1)} m³'),
          _Row(
            label: 'Periode Sewa',
            value:
                '${dateFormat.format(booking.startDate)} – ${dateFormat.format(booking.endDate)}',
          ),
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
                'Status',
                style: AppTextStyles.bodyRegular.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              _BookingStatusBadge(status: booking.status),
            ],
          ),
        ],
      ),
    );
  }
}

class _BookingStatusBadge extends StatelessWidget {
  const _BookingStatusBadge({required this.status});

  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    Color bgColor;

    switch (status) {
      case BookingStatus.paid:
        label = 'MENUNGGU CHECK-IN';
        color = AppColors.warning;
        bgColor = AppColors.warningSoft;
        break;
      case BookingStatus.active:
        label = 'SEWA AKTIF';
        color = AppColors.success;
        bgColor = AppColors.successSoft;
        break;
      case BookingStatus.completed:
        label = 'SELESAI';
        color = AppColors.textSecondaryLight;
        bgColor = const Color(0xFFE5E7EB);
        break;
      case BookingStatus.cancelled:
        label = 'DIBATALKAN';
        color = AppColors.error;
        bgColor = AppColors.errorSoft;
        break;
      case BookingStatus.pending:
        label = 'MENUNGGU PEMBAYARAN';
        color = AppColors.warning;
        bgColor = AppColors.warningSoft;
        break;
    }

    return AppStatusBadge(label: label, color: color, bgColor: bgColor);
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
// Temperature card (only for active bookings)
// ---------------------------------------------------------------------------

class _TemperatureCard extends StatelessWidget {
  const _TemperatureCard({
    required this.warehouseId,
    required this.warehouseName,
  });

  final String warehouseId;
  final String warehouseName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.thermostat, color: AppColors.accent),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pemantauan Suhu',
                  style: AppTextStyles.bodyRegular.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  'Lihat data real-time',
                  style: AppTextStyles.bodyRegular.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TemperatureMonitoringPage(
                    warehouseId: warehouseId,
                    warehouseName: warehouseName,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.arrow_forward, color: AppColors.accent),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Action button (changes based on status)
// ---------------------------------------------------------------------------

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.status,
    required this.onCheckIn,
    required this.onCheckOut,
  });

  final BookingStatus status;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case BookingStatus.paid:
        return AppPrimaryButton(
          label: 'Scan Check-In',
          icon: Icons.qr_code_scanner,
          onPressed: onCheckIn,
        );
      case BookingStatus.active:
        return AppPrimaryButton(
          label: 'Scan Check-Out',
          icon: Icons.qr_code_scanner,
          onPressed: onCheckOut,
        );
      case BookingStatus.completed:
        return Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.successSoft,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: AppColors.success),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Sewa Telah Selesai',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      case BookingStatus.cancelled:
      case BookingStatus.pending:
        return const SizedBox.shrink();
    }
  }
}
