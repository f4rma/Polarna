import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/firebase_constants.dart';
import '../../../../core/theme/app_animations.dart';
import '../../../../core/theme/app_primitives.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';

/// Admin page for managing warehouse registrations.
///
/// Two tabs:
/// - "Menunggu": warehouses with `verificationStatus == 'pending'` — admin can
///   approve/reject them.
/// - "Disetujui": warehouses with `verificationStatus == 'approved'` — read-only
///   list whose main purpose is exposing each warehouse's document ID (UID) so
///   the admin can copy it for IoT sensor setup, even after approval.
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

  /// Approved warehouses. No `orderBy` so it relies only on Firestore's
  /// automatic single-field index (no composite index needed) and still shows
  /// older warehouses that may be missing the `createdAt` field. Sorted by name
  /// client-side.
  Stream<QuerySnapshot> get _approvedStream => _firestore
      .collection(FirebaseConstants.warehousesCollection)
      .where(
        FirebaseConstants.fieldVerificationStatus,
        isEqualTo: 'approved',
      )
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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Verifikasi Gudang',
            style: AppTextStyles.heading2.copyWith(color: scheme.onSurface),
          ),
          centerTitle: false,
          bottom: TabBar(
            labelColor: scheme.primary,
            unselectedLabelColor: scheme.onSurfaceVariant,
            indicatorColor: scheme.primary,
            labelStyle: AppTextStyles.bodyRegular.copyWith(
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: 'Menunggu'),
              Tab(text: 'Disetujui'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPendingTab(scheme),
            _buildApprovedTab(scheme),
          ],
        ),
      ),
    );
  }

  // --- Tab 1: pending warehouses (approve / reject) -----------------------

  Widget _buildPendingTab(ColorScheme scheme) {
    return StreamBuilder<QuerySnapshot>(
      stream: _pendingStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorState(error: snapshot.error);
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const _EmptyState(
            icon: Icons.verified_outlined,
            title: 'Tidak Ada Gudang Pending',
            subtitle: 'Semua gudang sudah diverifikasi',
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
    );
  }

  // --- Tab 2: approved warehouses (read-only, exposes UID for IoT) ---------

  Widget _buildApprovedTab(ColorScheme scheme) {
    return StreamBuilder<QuerySnapshot>(
      stream: _approvedStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorState(error: snapshot.error);
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs.toList() ?? [];
        // Sort by name client-side (no composite index required).
        docs.sort((a, b) {
          final an = ((a.data()! as Map<String, dynamic>)[
                      FirebaseConstants.fieldName] as String? ??
                  '')
              .toLowerCase();
          final bn = ((b.data()! as Map<String, dynamic>)[
                      FirebaseConstants.fieldName] as String? ??
                  '')
              .toLowerCase();
          return an.compareTo(bn);
        });

        if (docs.isEmpty) {
          return const _EmptyState(
            icon: Icons.warehouse_outlined,
            title: 'Belum Ada Gudang Disetujui',
            subtitle: 'Gudang yang sudah disetujui akan muncul di sini',
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
            return _ApprovedWarehouseCard(
              warehouseId: doc.id,
              data: data,
              getMitraName: _getMitraName,
            );
          },
        );
      },
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

          // Warehouse ID (for IoT setup)
          _WarehouseIdBox(warehouseId: widget.warehouseId),
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
// Approved warehouse card — read-only, surfaces the UID for IoT setup
// ---------------------------------------------------------------------------

class _ApprovedWarehouseCard extends StatefulWidget {
  const _ApprovedWarehouseCard({
    required this.warehouseId,
    required this.data,
    required this.getMitraName,
  });

  final String warehouseId;
  final Map<String, dynamic> data;
  final Future<String> Function(String) getMitraName;

  @override
  State<_ApprovedWarehouseCard> createState() => _ApprovedWarehouseCardState();
}

class _ApprovedWarehouseCardState extends State<_ApprovedWarehouseCard> {
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
    final isActive =
        widget.data[FirebaseConstants.fieldIsActiveWarehouse] as bool? ?? true;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + active status
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style:
                      AppTextStyles.heading3.copyWith(color: scheme.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              isActive ? AppStatusBadge.active() : AppStatusBadge.offline(),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          // Mitra name
          Row(
            children: [
              Icon(Icons.person_outline,
                  size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  _mitraName,
                  style: AppTextStyles.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

          // Warehouse ID (for IoT setup) — the whole point of this tab
          _WarehouseIdBox(warehouseId: widget.warehouseId),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared empty + error states
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

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
              icon,
              size: 64,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: AppTextStyles.heading3.copyWith(color: scheme.onSurface),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyRegular.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ).fadeScaleIn();
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Gagal memuat data: $error',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyRegular,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Warehouse ID box (for IoT setup)
// ---------------------------------------------------------------------------

class _WarehouseIdBox extends StatelessWidget {
  const _WarehouseIdBox({required this.warehouseId});

  final String warehouseId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.sensors, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ID Gudang',
                  style: AppTextStyles.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
                Text(
                  warehouseId,
                  style: AppTextStyles.caption.copyWith(
                    color: scheme.onSurface,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 16),
            visualDensity: VisualDensity.compact,
            tooltip: 'Salin ID',
            color: scheme.primary,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: warehouseId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('ID gudang disalin'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
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
