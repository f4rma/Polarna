import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/photo_upload_service.dart';
import '../../../../core/theme/app_form_primitives.dart';
import '../../../../core/theme/app_primitives.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/validators.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/providers/warehouse_data_providers.dart';
import '../../domain/entities/warehouse_entity.dart';
import '../screens/location_picker_screen.dart';

/// Mitra warehouse registration page.
///
/// Includes photo upload grid, form fields with validation, GPS input,
/// temperature category selector, and a "Lanjutkan" button.
class WarehouseRegistrationPage extends ConsumerStatefulWidget {
  const WarehouseRegistrationPage({super.key});

  @override
  ConsumerState<WarehouseRegistrationPage> createState() =>
      _WarehouseRegistrationPageState();
}

class _WarehouseRegistrationPageState
    extends ConsumerState<WarehouseRegistrationPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  final _capacityController = TextEditingController();
  final _priceController = TextEditingController();

  TemperatureCategory _category = TemperatureCategory.frozen;
  final List<String> _photoUrls = []; // file paths from image picker
  bool _isSubmitting = false;
  final _picker = ImagePicker();

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

  String? _validateName(String? value) {
    final result = Validators.validateWarehouseName(value);
    return result.isValid ? null : result.errorMessage;
  }

  String? _validateAddress(String? value) {
    final result = Validators.validateRequired(value, fieldName: 'Alamat');
    return result.isValid ? null : result.errorMessage;
  }

  String? _validateLatitude(String? value) {
    final parsed = double.tryParse(value ?? '');
    final result = Validators.validateLatitude(parsed);
    return result.isValid ? null : result.errorMessage;
  }

  String? _validateLongitude(String? value) {
    final parsed = double.tryParse(value ?? '');
    final result = Validators.validateLongitude(parsed);
    return result.isValid ? null : result.errorMessage;
  }

  String? _validateCapacity(String? value) {
    final parsed = double.tryParse(value ?? '');
    final result = Validators.validateWarehouseCapacity(parsed);
    return result.isValid ? null : result.errorMessage;
  }

  String? _validatePrice(String? value) {
    final parsed = double.tryParse(value ?? '');
    final result = Validators.validateWarehousePrice(parsed);
    return result.isValid ? null : result.errorMessage;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final user = ref.read(authProvider).valueOrNull;
    if (user == null) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesi login tidak valid')),
        );
      }
      return;
    }

    final now = DateTime.now();

    // Upload photos to Firebase Storage
    List<String> uploadedUrls = [];
    if (_photoUrls.isNotEmpty) {
      try {
        final uploadService = ref.read(photoUploadServiceProvider);
        // Use a temporary ID for the storage path; will be replaced by Firestore doc ID
        final tempId = '${user.uid}_${now.millisecondsSinceEpoch}';
        uploadedUrls = await uploadService.uploadWarehousePhotos(
          localPaths: _photoUrls,
          warehouseId: tempId,
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengunggah foto: $e')),
        );
        return;
      }
    }

    final warehouse = WarehouseEntity(
      id: '', // akan di-generate oleh Firestore
      mitraId: user.uid,
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      latitude: double.parse(_latController.text),
      longitude: double.parse(_lonController.text),
      totalCapacity: double.parse(_capacityController.text),
      remainingCapacity: double.parse(_capacityController.text),
      pricePerM3PerDay: double.parse(_priceController.text),
      temperatureCategory: _category,
      temperatureThreshold: _category == TemperatureCategory.frozen ? -18.0 : 8.0,
      photoUrls: uploadedUrls,
      isActive: false,
      verificationStatus: VerificationStatus.pending,
      iotNodeId: null,
      createdAt: now,
      updatedAt: now,
    );

    final repository = ref.read(warehouseRepositoryProvider);
    final result = await repository.registerWarehouse(warehouse);

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
          const SnackBar(
            content: Text('Gudang berhasil didaftarkan. Menunggu verifikasi admin.'),
          ),
        );
        Navigator.of(context).pop(true); // return true to signal refresh
      },
    );
  }

  void _addPhoto() {
    if (_photoUrls.length >= AppConstants.maxWarehousePhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maksimal 5 foto')),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeri'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (picked != null && mounted) {
        setState(() => _photoUrls.add(picked.path));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengambil foto')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Daftarkan Gudang',
          style: AppTextStyles.heading2.copyWith(color: scheme.onSurface),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // Step indicator
            Text(
              'Langkah 1 dari 2',
              style: AppTextStyles.caption.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Photo upload grid
            _PhotoUploadGrid(
              photoUrls: _photoUrls,
              onAdd: _addPhoto,
              onRemove: (index) {
                setState(() => _photoUrls.removeAt(index));
              },
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Nama Gudang
            AppTextInput(
              controller: _nameController,
              label: 'Nama Gudang',
              hint: 'Contoh: Cold Storage Surabaya',
              validator: _validateName,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Alamat
            AppTextInput(
              controller: _addressController,
              label: 'Alamat',
              hint: 'Alamat lengkap gudang',
              validator: _validateAddress,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSpacing.lg),

            // GPS Coordinates
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
                    validator: _validateLatitude,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^-?\d*\.?\d*'),
                      ),
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
                    validator: _validateLongitude,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^-?\d*\.?\d*'),
                      ),
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
                final result = await Navigator.of(context).push<Map<String, dynamic>>(
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

            // Kapasitas Total
            AppTextInput(
              controller: _capacityController,
              label: 'Kapasitas Total (m³)',
              hint: 'Contoh: 100',
              keyboardType: TextInputType.number,
              validator: _validateCapacity,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Harga
            AppTextInput(
              controller: _priceController,
              label: 'Harga (Rp/m³/hari)',
              hint: 'Contoh: 5000',
              keyboardType: TextInputType.number,
              validator: _validatePrice,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Temperature category
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

            // Submit
            AppPrimaryButton(
              label: 'Lanjutkan',
              icon: Icons.arrow_forward,
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

// ---------------------------------------------------------------------------
// Photo upload grid
// ---------------------------------------------------------------------------

class _PhotoUploadGrid extends StatelessWidget {
  const _PhotoUploadGrid({
    required this.photoUrls,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> photoUrls;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final itemCount = photoUrls.length + 1; // +1 for the add button

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: itemCount.clamp(0, AppConstants.maxWarehousePhotos + 1),
        separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          if (index == photoUrls.length) {
            // Add button
            if (photoUrls.length >= AppConstants.maxWarehousePhotos) {
              return const SizedBox.shrink();
            }
            return GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  border: Border.all(
                    color: scheme.outlineVariant,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Tambah',
                      style: AppTextStyles.caption.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Photo thumbnail
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.small),
                child: Image.file(
                  File(photoUrls[index]),
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (_, e, st) => Container(
                    width: 100,
                    height: 100,
                    color: scheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.broken_image,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => onRemove(index),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
