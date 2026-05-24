import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';

/// Styled QR code container for booking verification.
///
/// Wraps [QrImageView] with a bordered container, instruction text,
/// and the booking ID below.
class BookingQrCodeWidget extends StatelessWidget {
  const BookingQrCodeWidget({
    super.key,
    required this.data,
    required this.bookingId,
    this.size = 200,
  });

  final String data;
  final String bookingId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: AppElevation.card,
          ),
          child: QrImageView(
            data: data,
            version: QrVersions.auto,
            size: size,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: AppColors.primary,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Tunjukkan ke petugas gudang',
          style: AppTextStyles.bodyRegular.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'ID: $bookingId',
          style: AppTextStyles.caption.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.5),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
