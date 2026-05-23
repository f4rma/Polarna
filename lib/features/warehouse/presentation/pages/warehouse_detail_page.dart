import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_form_primitives.dart';
import '../../../../core/theme/app_primitives.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../booking/presentation/pages/booking_form_page.dart';
import '../../domain/entities/warehouse_entity.dart';
import '../providers/warehouse_provider.dart';

/// Detail page for a single warehouse.
///
/// Shows hero image, name, address, sensor status, stat cards,
/// facilities list, and a "Pesan Sekarang" CTA.
class WarehouseDetailPage extends ConsumerStatefulWidget {
  const WarehouseDetailPage({super.key, required this.warehouseId});

  final String warehouseId;

  @override
  ConsumerState<WarehouseDetailPage> createState() =>
      _WarehouseDetailPageState();
}

class _WarehouseDetailPageState extends ConsumerState<WarehouseDetailPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(warehouseProvider.notifier).selectWarehouse(
            widget.warehouseId,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(warehouseProvider);
    final warehouse = state.selectedWarehouse;
    final scheme = Theme.of(context).colorScheme;

    if (state.isLoading && warehouse == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (warehouse == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(
            state.error?.message ?? 'Gudang tidak ditemukan',
            style: AppTextStyles.bodyLarge.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero image
          _HeroAppBar(warehouse: warehouse),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + sensor badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          warehouse.name,
                          style: AppTextStyles.heading1.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      if (warehouse.iotNodeId != null)
                        AppStatusBadge.connected()
                      else
                        AppStatusBadge.offline(),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Address
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          warehouse.address,
                          style: AppTextStyles.bodyRegular.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // Stat cards 2x2
                  _StatCardsGrid(warehouse: warehouse),
                  const SizedBox(height: AppSpacing.xxl),

                  // Fasilitas
                  Text(
                    'Fasilitas',
                    style: AppTextStyles.heading3.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _FacilitiesList(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomCta(context, warehouse),
    );
  }

  Widget? _buildBottomCta(BuildContext context, WarehouseEntity warehouse) {
    final user = ref.watch(authProvider).valueOrNull;
    // Hanya tampilkan tombol Pesan untuk UMKM
    if (user == null || user.role != UserRole.umkm) return null;
    return _BookingCta(warehouse: warehouse);
  }
}

// ---------------------------------------------------------------------------
// Hero app bar with image
// ---------------------------------------------------------------------------

class _HeroAppBar extends StatelessWidget {
  const _HeroAppBar({required this.warehouse});

  final WarehouseEntity warehouse;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: warehouse.photoUrls.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: warehouse.photoUrls.first,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: scheme.surfaceContainerHighest,
                ),
                errorWidget: (context, url, error) => Container(
                  color: scheme.surfaceContainerHighest,
                  child: const Icon(Icons.broken_image, size: 48),
                ),
              )
            : Container(
                color: scheme.surfaceContainerHighest,
                child: Icon(
                  Icons.warehouse,
                  size: 64,
                  color: scheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stat cards grid
// ---------------------------------------------------------------------------

class _StatCardsGrid extends StatelessWidget {
  const _StatCardsGrid({required this.warehouse});

  final WarehouseEntity warehouse;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.6,
      children: [
        _StatCard(
          icon: Icons.inventory_2_outlined,
          label: 'Kapasitas Total',
          value: '${warehouse.totalCapacity.toStringAsFixed(0)} m³',
        ),
        _StatCard(
          icon: Icons.space_dashboard_outlined,
          label: 'Sisa Kapasitas',
          value: '${warehouse.remainingCapacity.toStringAsFixed(0)} m³',
        ),
        _StatCard(
          icon: Icons.payments_outlined,
          label: 'Harga',
          value: CurrencyUtils.formatRupiah(warehouse.pricePerM3PerDay),
          subtitle: '/ m³ / hari',
        ),
        _StatCard(
          icon: Icons.thermostat_outlined,
          label: 'Kategori',
          value: warehouse.temperatureCategory == TemperatureCategory.frozen
              ? 'Frozen'
              : 'Chilled',
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: AppColors.accent),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTextStyles.heading3.copyWith(
              color: scheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: AppTextStyles.caption.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Facilities list
// ---------------------------------------------------------------------------

class _FacilitiesList extends StatelessWidget {
  // Hardcoded facilities for now — will be dynamic in future iterations.
  static const _facilities = [
    (Icons.thermostat, 'Suhu Konstan'),
    (Icons.security, 'Keamanan 24/7'),
    (Icons.local_shipping, 'Loading Dock'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        for (final (icon, label) in _facilities)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              children: [
                AppRoundIconAvatar(icon: icon, size: 36),
                const SizedBox(width: AppSpacing.md),
                Text(
                  label,
                  style: AppTextStyles.bodyRegular.copyWith(
                    color: scheme.onSurface,
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
// Booking CTA
// ---------------------------------------------------------------------------

class _BookingCta extends StatelessWidget {
  const _BookingCta({required this.warehouse});

  final WarehouseEntity warehouse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: AppPrimaryButton(
          label: 'Pesan Sekarang',
          icon: Icons.arrow_forward,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BookingFormPage(
                  warehouseId: warehouse.id,
                  warehouseName: warehouse.name,
                  pricePerM3PerDay: warehouse.pricePerM3PerDay,
                  remainingCapacity: warehouse.remainingCapacity,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
