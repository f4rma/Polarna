import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_primitives.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/incident_log_entity.dart';
import '../providers/incident_log_provider.dart';

/// Displays incident logs for UMKM/Mitra users.
///
/// Each log is rendered as a card with a colored left border:
/// - Red border for violations (temperature exceeded threshold)
/// - Green border for recovery events (temperature returned to normal)
///
/// Requirements: 7.3, 7.4, 7.5
class IncidentLogPage extends ConsumerStatefulWidget {
  const IncidentLogPage({super.key, this.warehouseId});

  /// Optional warehouse filter. When null, shows all logs for the user.
  final String? warehouseId;

  @override
  ConsumerState<IncidentLogPage> createState() => _IncidentLogPageState();
}

class _IncidentLogPageState extends ConsumerState<IncidentLogPage> {
  @override
  void initState() {
    super.initState();
    // Load logs on first build.
    Future.microtask(() {
      ref.read(incidentLogProvider.notifier).loadLogs(
            warehouseId: widget.warehouseId,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(incidentLogProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Insiden'),
        centerTitle: true,
      ),
      body: _buildBody(state, scheme),
    );
  }

  Widget _buildBody(IncidentLogState state, ColorScheme scheme) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: scheme.error),
              const SizedBox(height: AppSpacing.lg),
              Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyRegular.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.logs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 48,
                color: AppColors.success,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Tidak ada insiden tercatat.',
                style: AppTextStyles.bodyRegular.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: state.logs.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) => _IncidentCard(log: state.logs[index]),
      ),
    );
  }

  Future<void> _refresh() {
    return ref.read(incidentLogProvider.notifier).loadLogs(
          warehouseId: widget.warehouseId,
        );
  }
}

// ---------------------------------------------------------------------------
// Incident Card
// ---------------------------------------------------------------------------

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({required this.log});

  final IncidentLogEntity log;

  bool get _isViolation => log.eventType == 'violation';

  Color get _borderColor =>
      _isViolation ? AppColors.error : AppColors.success;

  IconData get _icon =>
      _isViolation ? Icons.warning_amber_rounded : Icons.check_circle_outline;

  Color get _iconColor => _borderColor;

  String get _title => _isViolation ? 'Peringatan Suhu!' : 'Suhu Kembali Normal';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      padding: EdgeInsets.zero,
      border: Border(
        left: BorderSide(color: _borderColor, width: 4),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppRoundIconAvatar(
              icon: _icon,
              size: 40,
              backgroundColor: _isViolation
                  ? AppColors.errorSoft
                  : AppColors.successSoft,
              iconColor: _iconColor,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _content(scheme)),
          ],
        ),
      ),
    );
  }

  Widget _content(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title row with severity badge
        Row(
          children: [
            Expanded(
              child: Text(
                _title,
                style: AppTextStyles.heading3.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ),
            _SeverityBadge(severity: log.severity, isNew: _isViolation),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        // Warehouse name
        Text(
          log.warehouseName,
          style: AppTextStyles.bodyRegular.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        // Temperature info
        Text(
          _isViolation
              ? 'Suhu: ${log.temperature.toStringAsFixed(1)}°C '
                  '(batas: ${log.threshold.toStringAsFixed(1)}°C)'
              : 'Suhu kembali: ${log.temperature.toStringAsFixed(1)}°C '
                  '(batas: ${log.threshold.toStringAsFixed(1)}°C)',
          style: AppTextStyles.caption.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Timestamp
        Text(
          _formatTimestamp(log.timestamp),
          style: AppTextStyles.caption.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }
}

// ---------------------------------------------------------------------------
// Severity Badge
// ---------------------------------------------------------------------------

class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({required this.severity, required this.isNew});

  final String severity;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    // No badge for UMKM/Mitra notification view
    return const SizedBox.shrink();
  }
}
