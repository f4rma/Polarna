import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_primitives.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/data/providers/auth_data_providers.dart';
import '../../../notification/domain/entities/incident_log_entity.dart';

/// Admin incident log page with filters: warehouse dropdown, date range
/// picker, and severity filter.
class IncidentLogAdminPage extends ConsumerStatefulWidget {
  const IncidentLogAdminPage({super.key});

  @override
  ConsumerState<IncidentLogAdminPage> createState() =>
      _IncidentLogAdminPageState();
}

class _IncidentLogAdminPageState extends ConsumerState<IncidentLogAdminPage> {
  String? _selectedWarehouseId;
  String? _selectedSeverity;
  DateTimeRange? _dateRange;

  List<_WarehouseOption> _warehouses = [];
  List<IncidentLogEntity> _incidents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadData);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadWarehouses(), _loadIncidents()]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadWarehouses() async {
    final firestore = ref.read(firestoreProvider);
    final snap = await firestore.collection('warehouses').get();
    _warehouses = snap.docs.map((doc) {
      final data = doc.data();
      return _WarehouseOption(
        id: doc.id,
        name: data['name'] as String? ?? 'Gudang',
      );
    }).toList();
  }

  Future<void> _loadIncidents() async {
    final firestore = ref.read(firestoreProvider);
    Query<Map<String, dynamic>> query =
        firestore.collection('incident_logs').orderBy('timestamp', descending: true);

    if (_selectedWarehouseId != null) {
      query = query.where('warehouseId', isEqualTo: _selectedWarehouseId);
    }
    if (_selectedSeverity != null) {
      query = query.where('severity', isEqualTo: _selectedSeverity);
    }
    if (_dateRange != null) {
      query = query
          .where('timestamp',
              isGreaterThanOrEqualTo:
                  Timestamp.fromDate(_dateRange!.start))
          .where('timestamp',
              isLessThanOrEqualTo: Timestamp.fromDate(
                _dateRange!.end.add(const Duration(days: 1)),
              ));
    }

    final snap = await query.limit(100).get();
    _incidents = snap.docs.map((doc) {
      final d = doc.data();
      return IncidentLogEntity(
        id: doc.id,
        warehouseId: d['warehouseId'] as String? ?? '',
        warehouseName: d['warehouseName'] as String? ?? '',
        temperature: (d['temperature'] as num?)?.toDouble() ?? 0,
        threshold: (d['threshold'] as num?)?.toDouble() ?? 0,
        severity: d['severity'] as String? ?? 'warning',
        eventType: d['eventType'] as String? ?? 'violation',
        affectedUmkmIds: List<String>.from(d['affectedUmkmIds'] ?? []),
        notificationsSent: List<String>.from(d['notificationsSent'] ?? []),
        notificationsFailed:
            List<String>.from(d['notificationsFailed'] ?? []),
        timestamp:
            (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        resolvedAt: (d['resolvedAt'] as Timestamp?)?.toDate(),
      );
    }).toList();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Log Insiden',
          style: AppTextStyles.heading2.copyWith(color: scheme.onSurface),
        ),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Column(
          children: [
            _buildFilters(context, scheme),
            const Divider(height: 1),
            Expanded(child: _buildBody(scheme)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(BuildContext context, ColorScheme scheme) {
    final dateFormat = DateFormat('dd/MM/yy');

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          // Warehouse dropdown
          _FilterDropdown(
            hint: 'Semua Gudang',
            value: _selectedWarehouseId,
            items: _warehouses
                .map((w) => DropdownMenuItem(
                      value: w.id,
                      child: Text(
                        w.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: (val) {
              setState(() => _selectedWarehouseId = val);
              _loadData();
            },
          ),
          // Severity filter
          _FilterDropdown(
            hint: 'Semua Severity',
            value: _selectedSeverity,
            items: const [
              DropdownMenuItem(value: 'warning', child: Text('Warning')),
              DropdownMenuItem(value: 'critical', child: Text('Critical')),
            ],
            onChanged: (val) {
              setState(() => _selectedSeverity = val);
              _loadData();
            },
          ),
          // Date range picker
          ActionChip(
            avatar: const Icon(Icons.date_range, size: 16),
            label: Text(
              _dateRange != null
                  ? '${dateFormat.format(_dateRange!.start)} – ${dateFormat.format(_dateRange!.end)}'
                  : 'Pilih Tanggal',
              style: AppTextStyles.caption,
            ),
            onPressed: _pickDateRange,
          ),
          // Clear filters
          if (_selectedWarehouseId != null ||
              _selectedSeverity != null ||
              _dateRange != null)
            ActionChip(
              avatar: const Icon(Icons.clear, size: 16),
              label: Text('Reset', style: AppTextStyles.caption),
              onPressed: () {
                setState(() {
                  _selectedWarehouseId = null;
                  _selectedSeverity = null;
                  _dateRange = null;
                });
                _loadData();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_incidents.isEmpty) {
      return Center(
        child: Text(
          'Tidak ada insiden ditemukan.',
          style: AppTextStyles.bodyRegular.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      itemCount: _incidents.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, index) => _IncidentLogCard(incident: _incidents[index]),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter dropdown widget
// ---------------------------------------------------------------------------

class _FilterDropdown extends StatelessWidget {
  final String hint;
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: AppTextStyles.caption),
          isExpanded: false,
          isDense: true,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Incident log card (reusable pattern from notification feature)
// ---------------------------------------------------------------------------

class _IncidentLogCard extends StatelessWidget {
  final IncidentLogEntity incident;

  const _IncidentLogCard({required this.incident});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
    final isCritical = incident.severity == 'critical';

    return AppCard(
      border: Border.all(
        color: isCritical
            ? AppColors.error.withValues(alpha: 0.4)
            : AppColors.warning.withValues(alpha: 0.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: warehouse name + severity badge
          Row(
            children: [
              Expanded(
                child: Text(
                  incident.warehouseName,
                  style: AppTextStyles.heading3.copyWith(
                    color: scheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AppStatusBadge(
                label: isCritical ? 'CRITICAL' : 'WARNING',
                color: isCritical ? AppColors.error : AppColors.warning,
                bgColor: isCritical
                    ? AppColors.errorSoft
                    : AppColors.warningSoft,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Temperature info
          Row(
            children: [
              Icon(
                Icons.thermostat,
                size: 16,
                color: isCritical ? AppColors.error : AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${incident.temperature.toStringAsFixed(1)}°C '
                '(threshold: ${incident.threshold.toStringAsFixed(1)}°C)',
                style: AppTextStyles.bodyRegular.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // Event type + timestamp
          Row(
            children: [
              Icon(
                incident.eventType == 'violation'
                    ? Icons.warning_amber
                    : Icons.check_circle_outline,
                size: 14,
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                incident.eventType == 'violation'
                    ? 'Pelanggaran'
                    : 'Pemulihan',
                style: AppTextStyles.caption.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const Spacer(),
              Text(
                dateFormat.format(incident.timestamp),
                style: AppTextStyles.caption.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          // Resolved status
          if (incident.resolvedAt != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Pulih: ${dateFormat.format(incident.resolvedAt!)}',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.success,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper model
// ---------------------------------------------------------------------------

class _WarehouseOption {
  final String id;
  final String name;

  const _WarehouseOption({required this.id, required this.name});
}
