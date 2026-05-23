import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_form_primitives.dart';
import '../../../../core/theme/app_primitives.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/validators.dart';
import '../../data/providers/warehouse_data_providers.dart';
import '../../domain/entities/warehouse_entity.dart';
import '../screens/location_picker_screen.dart';

/// Mitra warehouse edit page — pre-fills form with existing warehouse data
/// and saves changes via the warehouse repository.
class WarehouseEditPage extends ConsumerStatefulWidget {
  const WarehouseEditPage({super.key, required this.warehouseId});

  final String warehouseId;

  @override
  ConsumerState<WarehouseEditPage> createState() => _WarehouseEditPageState();
}

class _WarehouseEditPageState extends ConsumerState<WarehouseEditPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  final _capacityController = TextEditingController();
  final _priceController = TextEditingController();

  TemperatureCategory _category = TemperatureCategory.frozen;
  WarehouseEntity? _warehouse;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadWarehouse);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lonController.dispose();
    _capacityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadWarehouse() async {
    final repo = ref.read(warehouseRepositoryProvider);
    final result = await repo.getById(widget.warehouseId);

    if (!mounted) return;

    result.fold(
      (failure) {
        setState(() {
          _isLoading = false;
          _loadError = failure.message;
        });
      },
      (w) {
        setState(() {
          _warehouse = w;
          _nameController.text = w.name;
          _addressController.text = w.address;
          _latController.text = w.latitude.toString();
          _lonController.text = w.longitude.toString();
          _capacityController.text = w.totalCapacity.toStringAsFixed(0);
          _priceController.text = w.pricePerM3PerDay.toStringAsFixed(0);
          _category = w.temperatureCategory;
          _isLoading = false;
        });
      },
    );
  }

  String? _validateName(String? v) {
    final r = Validators.validateWarehouseName(v);
    return r.isValid ? null : r.errorMessage;
  }

  String? _validateAddress(String? v) {
    final r = Validators.validateRequired(v, fieldName: 'Alamat');
    return r.isValid ? null : r.errorMessage;
  }

  String? _validateLat(String? v) {
    final r = Validators.validateLatitude(double.tryParse(v ?? ''));
    return r.isValid ? null : r.errorMessage;
  }

  String? _validateLon(String? v) {
    final r = Validators.validateLongitude(double.tryParse(v ?? ''));
    return r.isValid ? null : r.errorMessage;
  }

  String? _validateCapacity(String? v) {
    final r = Validators.validateWarehouseCapacity(double.tryParse(v ?? ''));
    return r.isValid ? null : r.errorMessage;
  }

  String? _validatePrice(String? v) {
    final r = Validators.validateWarehousePrice(double.tryParse(v ?? ''));
    return r.isValid ? null : r.errorMessage;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_warehouse == null) return;

    setState(() => _isSubmitting = true);

    final newTotalCapacity = double.parse(_capacityController.text);
    // Hitung selisih kapasitas → adjust remainingCapacity proporsional
    final oldTotal = _warehouse!.totalCapacity;
    final oldRemaining = _warehouse!.remainingCapacity;
    final used = oldTotal - oldRemaining; // yang sedang dipakai
    final newRemaining =
        (newTotalCapacity - used).clamp(0.0, newTotalCapacity);

    final updated = _warehouse!.copyWith(
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      latitude: double.parse(_latController.text),
      longitude: double.parse(_lonController.text),
      totalCapacity: newTotalCapacity,
      remainingCapacity: newRemaining,
      pricePerM3PerDay: double.parse(_priceController.text),
      temperatureCategory: _category,
      temperatureThreshold:
          _category == TemperatureCategory.frozen ? -18.0 : 8.0,
      updatedAt: DateTime.now(),
    );

    final repo = ref.read(warehouseRepositoryProvider);
    final result = await repo.updateWarehouse(updated);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: ${failure.message}')),
        );
      },
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gudang berhasil diperbarui')),
        );
        Navigator.of(context).pop(true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null || _warehouse == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Gudang')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppColors.error),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _loadError ?? 'Gudang tidak ditemukan',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyRegular,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit Gudang',
          style: AppTextStyles.heading2.copyWith(color: scheme.onSurface),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // Photo preview row (read-only — photos can be re-uploaded later)
            if (_warehouse!.photoUrls.isNotEmpty) ...[
              Text(
                'FOTO GUDANG',
                style: AppTextStyles.labelMedium.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _warehouse!.photoUrls.length,
                  separatorBuilder: (_, i) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final url = _warehouse!.photoUrls[index];
                    return ClipRRect(
                      borderRadius:
                          BorderRadius.circular(AppRadius.small),
                      child: SizedBox(
                        width: 100,
                        height: 100,
                        child: url.startsWith('http')
                            ? Image.network(url, fit: BoxFit.cover)
                            : Image.file(File(url), fit: BoxFit.cover),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],

            // Nama Gudang
            AppTextInput(
              controller: _nameController,
              label: 'Nama Gudang',
              validator: _validateName,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Alamat
            AppTextInput(
              controller: _addressController,
              label: 'Alamat',
              validator: _validateAddress,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSpacing.lg),

            // GPS
            Text(
              'KOORDINAT GPS',
              style: AppTextStyles.labelMedium.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: AppTextInput(
                    controller: _latController,
                    hint: 'Latitude',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: _validateLat,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^-?\d*\.?\d*')),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppTextInput(
                    controller: _lonController,
                    hint: 'Longitude',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: _validateLon,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^-?\d*\.?\d*')),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            AppSecondaryButton(
              label: 'Pilih di Peta',
              icon: Icons.map_outlined,
              onPressed: () async {
                final result =
                    await Navigator.of(context).push<Map<String, dynamic>>(
                  MaterialPageRoute(
                    builder: (_) => LocationPickerScreen(
                      initialLat: double.tryParse(_latController.text),
                      initialLng: double.tryParse(_lonController.text),
                    ),
                  ),
                );
                if (result != null && mounted) {
                  setState(() {
                    _latController.text = result['lat'].toString();
                    _lonController.text = result['lng'].toString();
                    _addressController.text = result['address'] as String;
                  });
                }
              },
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Kapasitas
            AppTextInput(
              controller: _capacityController,
              label: 'Kapasitas Total (m³)',
              keyboardType: TextInputType.number,
              validator: _validateCapacity,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Saat ini terpakai: ${(_warehouse!.totalCapacity - _warehouse!.remainingCapacity).toStringAsFixed(0)} m³',
              style: AppTextStyles.caption.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Harga
            AppTextInput(
              controller: _priceController,
              label: 'Harga (Rp/m³/hari)',
              keyboardType: TextInputType.number,
              validator: _validatePrice,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Kategori suhu
            Text(
              'KATEGORI SUHU',
              style: AppTextStyles.labelMedium.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppSegmentedToggle<TemperatureCategory>(
              values: TemperatureCategory.values,
              selected: _category,
              onChanged: (v) => setState(() => _category = v),
              labels: const {
                TemperatureCategory.frozen: 'Frozen',
                TemperatureCategory.chilled: 'Chilled',
              },
              icons: const {
                TemperatureCategory.frozen: Icons.ac_unit,
                TemperatureCategory.chilled: Icons.water_drop_outlined,
              },
            ),
            const SizedBox(height: AppSpacing.xxxl),

            // Save button
            AppPrimaryButton(
              label: 'Simpan Perubahan',
              icon: Icons.save_outlined,
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? null : _submit,
              variant: AppButtonVariant.accent,
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}
