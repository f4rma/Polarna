import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_form_primitives.dart';
import '../../../../core/theme/app_primitives.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../domain/entities/warehouse_entity.dart';
import '../../domain/entities/warehouse_search_filter.dart';
import '../providers/warehouse_provider.dart';
import '../widgets/filter_bottom_sheet.dart';

/// UMKM warehouse search page — search bar, filter chips, result count,
/// and a scrollable list of warehouse cards.
class WarehouseSearchPage extends ConsumerStatefulWidget {
  const WarehouseSearchPage({super.key});

  @override
  ConsumerState<WarehouseSearchPage> createState() =>
      _WarehouseSearchPageState();
}

class _WarehouseSearchPageState extends ConsumerState<WarehouseSearchPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(warehouseProvider.notifier).search());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openFilter() async {
    final state = ref.read(warehouseProvider);
    final newFilter = await FilterBottomSheet.show(
      context,
      currentFilter: state.filter,
      resultCount: state.warehouses.length,
    );
    if (newFilter != null && mounted) {
      ref.read(warehouseProvider.notifier).updateFilter(newFilter);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(warehouseProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ─── Search bar with back arrow ───
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: AppTextInput(
                      controller: _searchController,
                      hint: 'Cari gudang...',
                      prefixIcon: Icons.search,
                      textInputAction: TextInputAction.search,
                      onFieldSubmitted: (_) {
                        ref.read(warehouseProvider.notifier).search();
                      },
                    ),
                  ),
                ],
              ),
            ),

            // ─── Filter chips row ───
            _FilterChipsRow(
              filter: state.filter,
              onFilterTap: _openFilter,
            ),
            const SizedBox(height: AppSpacing.sm),

            // ─── Result count + filter icon ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Text(
                    '${state.warehouses.length} Gudang Ditemukan',
                    style: AppTextStyles.heading3.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.small),
                    onTap: _openFilter,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Icon(
                        Icons.tune,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // ─── Results list ───
            Expanded(
              child: _buildResults(state, scheme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(WarehouseState state, ColorScheme scheme) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: AppSpacing.md),
              Text(
                state.error!.message,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyRegular.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppPrimaryButton(
                label: 'Coba Lagi',
                onPressed: () => ref.read(warehouseProvider.notifier).search(),
              ),
            ],
          ),
        ),
      );
    }

    if (state.warehouses.isEmpty) {
      return _EmptyState(onChangeFilter: _openFilter);
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(warehouseProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        itemCount: state.warehouses.length,
        separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final warehouse = state.warehouses[index];
          return _WarehouseSearchCard(
            warehouse: warehouse,
            onTap: () => context.push(
              RouteConstants.warehouseDetailPath(warehouse.id),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Warehouse Search Card — matches Figma layout
// ---------------------------------------------------------------------------

class _WarehouseSearchCard extends StatelessWidget {
  const _WarehouseSearchCard({
    required this.warehouse,
    required this.onTap,
  });

  final WarehouseEntity warehouse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final capacityRatio = warehouse.totalCapacity > 0
        ? warehouse.remainingCapacity / warehouse.totalCapacity
        : 0.0;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.small),
            child: SizedBox(
              width: 88,
              height: 88,
              child: warehouse.photoUrls.isNotEmpty
                  ? Image.network(
                      warehouse.photoUrls.first,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: scheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.warehouse,
                          size: 32,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : Container(
                      color: scheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.warehouse,
                        size: 32,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category badge row
                Row(
                  children: [
                    warehouse.temperatureCategory == TemperatureCategory.frozen
                        ? AppStatusBadge.frozen()
                        : AppStatusBadge.chilled(),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),

                // Warehouse name
                Text(
                  warehouse.name,
                  style: AppTextStyles.heading3.copyWith(
                    color: scheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),

                // Price
                Text(
                  CurrencyUtils.formatPricePerM3PerDay(
                    warehouse.pricePerM3PerDay,
                  ),
                  style: AppTextStyles.bodyRegular.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Capacity bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: LinearProgressIndicator(
                    value: capacityRatio.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor:
                        scheme.outlineVariant.withValues(alpha: 0.3),
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.accent),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),

                // Remaining capacity text
                Text(
                  '${warehouse.remainingCapacity.toStringAsFixed(0)} m³ tersisa',
                  style: AppTextStyles.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter chips row
// ---------------------------------------------------------------------------

class _FilterChipsRow extends StatelessWidget {
  const _FilterChipsRow({
    required this.filter,
    required this.onFilterTap,
  });

  final WarehouseSearchFilter filter;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          AppFilterChip(
            label: 'Filter',
            selected: false,
            leadingIcon: Icons.tune,
            onTap: onFilterTap,
          ),
          const SizedBox(width: AppSpacing.sm),
          if (filter.category != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: AppFilterChip(
                label: filter.category == TemperatureCategory.frozen
                    ? 'Frozen'
                    : 'Chilled',
                selected: true,
                onTap: onFilterTap,
              ),
            ),
          if (filter.radiusKm != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: AppFilterChip(
                label: '${filter.radiusKm!.toInt()} km',
                selected: true,
                onTap: onFilterTap,
              ),
            ),
          if (filter.maxPricePerM3 != null)
            AppFilterChip(
              label: 'Harga',
              selected: true,
              onTap: onFilterTap,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onChangeFilter});

  final VoidCallback onChangeFilter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Tidak ada gudang yang sesuai\ndengan filter Anda',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyLarge.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppPrimaryButton(
              label: 'Ubah Filter',
              onPressed: onChangeFilter,
            ),
          ],
        ),
      ),
    );
  }
}
