import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_form_primitives.dart';
import '../../../../core/theme/app_primitives.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/warehouse_entity.dart';
import '../../domain/entities/warehouse_search_filter.dart';

/// Filter bottom sheet for warehouse search.
///
/// Allows the user to filter by temperature category, radius, minimum
/// capacity, and price range. Returns the updated [WarehouseSearchFilter]
/// via [Navigator.pop].
class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({
    super.key,
    required this.currentFilter,
    this.resultCount,
  });

  final WarehouseSearchFilter currentFilter;
  final int? resultCount;

  /// Shows the filter bottom sheet and returns the new filter (or null if
  /// dismissed without applying).
  static Future<WarehouseSearchFilter?> show(
    BuildContext context, {
    required WarehouseSearchFilter currentFilter,
    int? resultCount,
  }) {
    return showModalBottomSheet<WarehouseSearchFilter>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (_) => FilterBottomSheet(
        currentFilter: currentFilter,
        resultCount: resultCount,
      ),
    );
  }

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late TemperatureCategory? _category;
  late double? _radiusKm;
  late double? _minCapacity;
  late double _minPrice;
  late double _maxPrice;

  final _capacityController = TextEditingController();

  static const _radiusOptions = AppConstants.searchRadiusOptions;
  static const _priceMin = 1000.0;
  static const _priceMax = 100000.0;

  @override
  void initState() {
    super.initState();
    _category = widget.currentFilter.category;
    _radiusKm = widget.currentFilter.radiusKm;
    _minCapacity = widget.currentFilter.minCapacityM3;
    _minPrice = widget.currentFilter.minPricePerM3 ?? _priceMin;
    _maxPrice = widget.currentFilter.maxPricePerM3 ?? _priceMax;

    if (_minCapacity != null) {
      _capacityController.text = _minCapacity!.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _capacityController.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _category = null;
      _radiusKm = null;
      _minCapacity = null;
      _minPrice = _priceMin;
      _maxPrice = _priceMax;
      _capacityController.clear();
    });
  }

  void _apply() {
    final filter = WarehouseSearchFilter(
      centerLatitude: widget.currentFilter.centerLatitude,
      centerLongitude: widget.currentFilter.centerLongitude,
      category: _category,
      radiusKm: _radiusKm,
      minCapacityM3: _minCapacity,
      minPricePerM3: _minPrice > _priceMin ? _minPrice : null,
      maxPricePerM3: _maxPrice < _priceMax ? _maxPrice : null,
    );
    Navigator.of(context).pop(filter);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: ListView(
            controller: scrollController,
            children: [
              const SizedBox(height: AppSpacing.md),
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter Pencarian',
                    style: AppTextStyles.heading2.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  TextButton(
                    onPressed: _reset,
                    child: Text(
                      'Reset',
                      style: AppTextStyles.bodyRegular.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),

              // --- Kategori Suhu ---
              _sectionLabel('Kategori Suhu'),
              const SizedBox(height: AppSpacing.sm),
              AppSegmentedToggle<TemperatureCategory?>(
                values: const [
                  TemperatureCategory.frozen,
                  TemperatureCategory.chilled,
                  null,
                ],
                selected: _category,
                onChanged: (v) => setState(() => _category = v),
                labels: const {
                  TemperatureCategory.frozen: 'Frozen',
                  TemperatureCategory.chilled: 'Chilled',
                  null: 'Semua',
                },
                icons: const {
                  TemperatureCategory.frozen: Icons.ac_unit,
                  TemperatureCategory.chilled: Icons.water_drop_outlined,
                },
              ),
              const SizedBox(height: AppSpacing.xxl),

              // --- Jarak Radius ---
              _sectionLabel('Jarak Radius'),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final r in _radiusOptions)
                    AppFilterChip(
                      label: '${r.toInt()} km',
                      selected: _radiusKm == r,
                      onTap: () => setState(() {
                        _radiusKm = _radiusKm == r ? null : r;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),

              // --- Kapasitas Minimum ---
              _sectionLabel('Kapasitas Minimum'),
              const SizedBox(height: AppSpacing.sm),
              AppTextInput(
                controller: _capacityController,
                hint: 'Contoh: 10',
                keyboardType: TextInputType.number,
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: Text(
                    'm³',
                    style: AppTextStyles.bodyRegular.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                onChanged: (value) {
                  final parsed = double.tryParse(value);
                  setState(() => _minCapacity = parsed);
                },
              ),
              const SizedBox(height: AppSpacing.xxl),

              // --- Rentang Harga ---
              _sectionLabel('Rentang Harga (Rp/m³/hari)'),
              const SizedBox(height: AppSpacing.sm),
              RangeSlider(
                values: RangeValues(_minPrice, _maxPrice),
                min: _priceMin,
                max: _priceMax,
                divisions: 99,
                labels: RangeLabels(
                  'Rp ${_minPrice.toInt()}',
                  'Rp ${_maxPrice.toInt()}',
                ),
                onChanged: (values) {
                  setState(() {
                    _minPrice = values.start;
                    _maxPrice = values.end;
                  });
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Rp ${_minPrice.toInt()}',
                    style: AppTextStyles.caption.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    'Rp ${_maxPrice.toInt()}',
                    style: AppTextStyles.caption.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxxl),

              // --- Apply button ---
              AppPrimaryButton(
                label: 'Terapkan Filter',
                onPressed: _apply,
              ),
              const SizedBox(height: AppSpacing.md),

              // Result count
              if (widget.resultCount != null)
                Center(
                  child: Text(
                    '${widget.resultCount} gudang ditemukan',
                    style: AppTextStyles.caption.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: AppTextStyles.labelMedium.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
