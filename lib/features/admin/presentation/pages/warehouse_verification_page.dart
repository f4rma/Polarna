import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/firebase_constants.dart';
import '../../../../core/theme/app_primitives.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';

/// Admin page for verifying pending warehouse registrations.
///
/// Queries Firestore directly for warehouses with `verificationStatus == 'pending'`
/// and provides approve/reject actions.
class WarehouseVerificationPage extends StatefulWidget {
  const WarehouseVerificationPage({super.key});

  @override
  State<WarehouseVerificationPage> createState() =>
      _WarehouseVerificationPageState();
}

class _WarehouseVerificationPageState extends State<WarehouseVerificationPage> {
  final _firestore = FirebaseFirestore.instance;
  bool _isProcessing = false;

  Stream<QuerySnapshot> get _pendingStream => _firestore
      .collection(FirebaseConstants.warehousesCollection)
      .where(
        FirebaseConstants.fieldVerificationStatus,
        isEqualTo: 'pending',
      )
      .orderBy(FirebaseConstants.fieldCreatedAt, descending: true)
      .snapshots();

  Future<void> _approve(String warehouseId) async {
    setState(() => _isProcessing = true);
    try {
      await _firestore
          .collection(FirebaseConstants.warehousesCollection)
          .doc(warehouseId)
          .update({
        FirebaseConstants.fieldVerificationStatus: 'approved',
        FirebaseConstants.fieldIsActiveWarehouse: true,
        FirebaseConstants.fieldUpdatedAt: FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gudang berhasil disetujui')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyetujui: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _reject(String warehouseId) async {
    setState(() => _isProcessing = true);
    try {
      await _firestore
          .collection(FirebaseConstants.warehousesCollection)
          .doc(warehouseId)
          .update({
        FirebaseConstants.fieldVerificationStatus: 'rejected',
        FirebaseConstants.fieldIsActiveWarehouse: false,
        FirebaseConstants.fieldUpdatedAt: FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gudang ditolak')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menolak: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<String> _getMitraName(String mitraId) async {
    try {
      final doc = await _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(mitraId)
          .get();
      if (doc.exists) {
        return (doc.data()?[FirebaseConstants.fieldFullName] as String?) ??
            'Mitra tidak diketahui';
      }
    } catch (_) {}
    return 'Mitra tidak diketahui';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Verifikasi Gudang',
          style: AppTextStyles.heading2.copyWith(color: scheme.onSurface),
        ),
        centerTitle: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _pendingStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: AppColors.error),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Gagal memuat data: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyRegular,
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_outlined,
                      size: 64,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Tidak Ada Gudang Pending',
                      style: AppTextStyles.heading3.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Semua gudang sudah diverifikasi',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyRegular.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: docs.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data()! as Map<String, dynamic>;
              return _PendingWarehouseCard(
                warehouseId: doc.id,
                data: data,
                onApprove: () => _approve(doc.id),
                onReject: () => _reject(doc.id),
                isProcessing: _isProcessing,
                getMitraName: _getMitraName,
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pending warehouse card
// ---------------------------------------------------------------------------

class _PendingWarehouseCard extends StatefulWidget {
  const _PendingWarehouseCard({
    required this.warehouseId,
    required this.data,
    required this.onApprove,
    required this.onReject,
    required this.isProcessing,
    required this.getMitraName,
  });

  final String warehouseId;
  final Map<String, dynamic> data;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final bool isProcessing;
  final Future<String> Function(String) getMitraName;

  @override
  State<_PendingWarehouseCard> createState() => _PendingWarehouseCardState();
}

class _PendingWarehouseCardState extends State<_PendingWarehouseCard> {
  String _mitraName = '...';

  @override
  void initState() {
    super.initState();
    _loadMitraName();
  }

  Future<void> _loadMitraName() async {
    final mitraId =
        widget.data[FirebaseConstants.fieldMitraId] as String? ?? '';
    if (mitraId.isNotEmpty) {
      final name = await widget.getMitraName(mitraId);
      if (mounted) setState(() => _mitraName = name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name =
        widget.data[FirebaseConstants.fieldName] as String? ?? 'Tanpa Nama';
    final address =
        widget.data[FirebaseConstants.fieldAddress] as String? ?? '-';
    final photos = List<String>.from(
      (widget.data[FirebaseConstants.fieldPhotoUrls] as List<dynamic>?) ??
          const <dynamic>[],
    );
    final totalCapacity =
        (widget.data[FirebaseConstants.fieldTotalCapacity] as num?)
                ?.toDouble() ??
            0;
    final pricePerM3 =
        (widget.data[FirebaseConstants.fieldPricePerM3PerDay] as num?)
                ?.toDouble() ??
            0;
    final tempCategory =
        widget.data[FirebaseConstants.fieldTemperatureCategory] as String? ??
            'frozen';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photos row
          if (photos.isNotEmpty) ...[
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final url = photos[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.small),
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: url.startsWith('http')
                          ? CachedNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: scheme.surfaceContainerHighest,
                                child: const Icon(Icons.image, size: 24),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: scheme.surfaceContainerHighest,
                                child:
                                    const Icon(Icons.broken_image, size: 24),
                              ),
                            )
                          : Container(
                              color: scheme.surfaceContainerHighest,
                              child: const Icon(Icons.image, size: 24),
                            ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Warehouse name
          Text(
            name,
            style: AppTextStyles.heading3.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: AppSpacing.xs),

          // Mitra name
          Row(
            children: [
              Icon(Icons.person_outline,
                  size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.xs),
              Text(
                _mitraName,
                style: AppTextStyles.caption.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          // Address
          Row(
            children: [
              Icon(Icons.location_on_outlined,
                  size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  address,
                  style: AppTextStyles.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Details row
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              _InfoChip(
                icon: Icons.straighten,
                label: '${totalCapacity.toStringAsFixed(0)} m³',
              ),
              _InfoChip(
                icon: Icons.payments_outlined,
                label: 'Rp ${pricePerM3.toStringAsFixed(0)}/m³/hari',
              ),
              _InfoChip(
                icon: tempCategory == 'frozen'
                    ? Icons.ac_unit
                    : Icons.water_drop_outlined,
                label: tempCategory == 'frozen' ? 'Frozen' : 'Chilled',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.isProcessing ? null : widget.onReject,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Tolak'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton.icon(
                  onPressed: widget.isProcessing ? null : widget.onApprove,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Setujui'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info chip
// ---------------------------------------------------------------------------

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
