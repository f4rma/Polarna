import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_primitives.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../domain/entities/warehouse_entity.dart';

/// Reusable warehouse card used in both UMKM search results and Mitra list.
///
/// Shows: photo thumbnail, name, distance (optional), price, capacity bar,
/// and temperature category badge. Tapping invokes [onTap].
class WarehouseCardWidget extends StatelessWidget {
  const WarehouseCardWidget({
    super.key,
    required this.warehouse,
    required this.onTap,
    this.distanceKm,
    this.showToggle = false,
    this.onToggleActive,
    this.onEdit,
  });

  final WarehouseEntity warehouse;
  final VoidCallback onTap;

  /// Distance from user's location in km (shown in UMKM search results).
  final double? distanceKm;

  /// Whether to show the active/inactive toggle (Mitra list).
  final bool showToggle;

  /// Callback when the active toggle is changed (Mitra list).
  final ValueChanged<bool>? onToggleActive;

  /// Callback for the edit action (Mitra list).
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final capacityRatio = warehouse.totalCapacity > 0
        ? warehouse.remainingCapacity / warehouse.totalCapacity
        : 0.0;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: photo + main info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.small),
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: _buildThumbnail(scheme),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Info section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + category badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            warehouse.name,
                            style: AppTextStyles.heading3.copyWith(
                              color: scheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _categoryBadge(),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    // Price
                    Text(
                      CurrencyUtils.formatPricePerM3PerDay(
                        warehouse.pricePerM3PerDay,
                      ),
                      style: AppTextStyles.bodyRegular.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Capacity bar
                    _CapacityBar(ratio: capacityRatio),
                    if (distanceKm != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${distanceKm!.toStringAsFixed(1)} km',
                            style: AppTextStyles.caption.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // Mitra controls — only shown when toggle is enabled
          if (showToggle) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
            // Verification status badge
            if (warehouse.verificationStatus != VerificationStatus.approved)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _VerificationBadge(status: warehouse.verificationStatus),
              ),
            _SensorStatusRow(
              isConnected: warehouse.iotNodeId != null,
            ),
            const SizedBox(height: AppSpacing.sm),
            _MitraControlsRow(
              isActive: warehouse.isActive,
              onToggleActive: onToggleActive,
              onEdit: onEdit,
            ),
          ] else ...[
            // For UMKM view — show sensor status with same clear format as Mitra
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
            _SensorStatusRow(
              isConnected: warehouse.iotNodeId != null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThumbnail(ColorScheme scheme) {
    if (warehouse.photoUrls.isEmpty) {
      return Container(
        color: scheme.surfaceContainerHighest,
        child: Icon(
          Icons.warehouse,
          size: 32,
          color: scheme.onSurfaceVariant,
        ),
      );
    }

    final url = warehouse.photoUrls.first;

    // Local file path (from image picker)
    if (!url.startsWith('http')) {
      final file = File(url);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
      return Container(
        color: scheme.surfaceContainerHighest,
        child: Icon(
          Icons.warehouse,
          size: 32,
          color: scheme.onSurfaceVariant,
        ),
      );
    }

    // Network URL
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, u) => Container(
        color: scheme.surfaceContainerHighest,
        child: const Icon(Icons.warehouse, size: 32),
      ),
      errorWidget: (context, u, error) => Container(
        color: scheme.surfaceContainerHighest,
        child: const Icon(Icons.broken_image, size: 32),
      ),
    );
  }

  Widget _categoryBadge() {
    return warehouse.temperatureCategory == TemperatureCategory.frozen
        ? AppStatusBadge.frozen()
        : AppStatusBadge.chilled();
  }
}

// ---------------------------------------------------------------------------
// Sensor status row — clear label + colored dot for IoT connection state
// ---------------------------------------------------------------------------

class _SensorStatusRow extends StatelessWidget {
  const _SensorStatusRow({required this.isConnected});

  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = isConnected ? AppColors.success : AppColors.warning;
    final label = isConnected ? 'Sensor mengirim data suhu' : 'Sensor Belum Terhubung';

    return Row(
      children: [
        // Status dot with pulse-like ring
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Mitra controls row — toggle aktif/non-aktif + tombol Edit yang jelas
// ---------------------------------------------------------------------------

class _MitraControlsRow extends StatelessWidget {
  const _MitraControlsRow({
    required this.isActive,
    required this.onToggleActive,
    required this.onEdit,
  });

  final bool isActive;
  final ValueChanged<bool>? onToggleActive;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        // Active toggle with explicit label
        Expanded(
          child: Row(
            children: [
              Switch(
                value: isActive,
                onChanged: onToggleActive,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  isActive ? 'Tersedia untuk disewa' : 'Tidak tersedia',
                  style: AppTextStyles.caption.copyWith(
                    color: isActive
                        ? AppColors.success
                        : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        // Edit button — clearly a button, not just text
        if (onEdit != null)
          OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: BorderSide(color: AppColors.accent.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Verification status badge
// ---------------------------------------------------------------------------

class _VerificationBadge extends StatelessWidget {
  const _VerificationBadge({required this.status});

  final VerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color textColor;
    final String label;

    switch (status) {
      case VerificationStatus.pending:
        bgColor = AppColors.warning.withValues(alpha: 0.15);
        textColor = AppColors.warning;
        label = 'Menunggu Verifikasi';
      case VerificationStatus.rejected:
        bgColor = AppColors.error.withValues(alpha: 0.15);
        textColor = AppColors.error;
        label = 'Ditolak';
      case VerificationStatus.approved:
        bgColor = AppColors.success.withValues(alpha: 0.15);
        textColor = AppColors.success;
        label = 'Disetujui';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status == VerificationStatus.pending
                ? Icons.hourglass_top
                : status == VerificationStatus.rejected
                    ? Icons.cancel_outlined
                    : Icons.check_circle_outline,
            size: 14,
            color: textColor,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Capacity bar
// ---------------------------------------------------------------------------

class _CapacityBar extends StatelessWidget {
  const _CapacityBar({required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: scheme.outlineVariant.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation(AppColors.accent),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Sisa: ${(ratio * 100).toStringAsFixed(0)}%',
          style: AppTextStyles.caption.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
