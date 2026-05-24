import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_form_primitives.dart';
import '../../../../core/theme/app_primitives.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/booking_provider.dart';
import '../widgets/cost_estimator_widget.dart';

/// Booking form page — allows UMKM to configure volume, start date,
/// and duration, then confirm the booking.
class BookingFormPage extends ConsumerStatefulWidget {
  const BookingFormPage({
    super.key,
    required this.warehouseId,
    required this.warehouseName,
    required this.pricePerM3PerDay,
    required this.remainingCapacity,
  });

  final String warehouseId;
  final String warehouseName;
  final double pricePerM3PerDay;
  final double remainingCapacity;

  @override
  ConsumerState<BookingFormPage> createState() => _BookingFormPageState();
}

class _BookingFormPageState extends ConsumerState<BookingFormPage> {
  double _volumeM3 = 0.5;
  int _durationDays = 1;
  DateTime _startDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    Future.microtask(_recalculate);
  }

  void _recalculate() {
    ref.read(bookingProvider.notifier).calculateCost(
          volumeM3: _volumeM3,
          pricePerM3PerDay: widget.pricePerM3PerDay,
          durationDays: _durationDays,
        );
  }

  void _incrementVolume() {
    if (_volumeM3 + 0.5 <= 500) {
      setState(() => _volumeM3 += 0.5);
      _recalculate();
    }
  }

  void _decrementVolume() {
    if (_volumeM3 - 0.5 >= 0.5) {
      setState(() => _volumeM3 -= 0.5);
      _recalculate();
    }
  }

  void _incrementDuration() {
    if (_durationDays + 1 <= 365) {
      setState(() => _durationDays += 1);
      _recalculate();
    }
  }

  void _decrementDuration() {
    if (_durationDays - 1 >= 1) {
      setState(() => _durationDays -= 1);
      _recalculate();
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _confirmBooking() async {
    final user = ref.read(authProvider).valueOrNull;
    if (user == null) return;

    await ref.read(bookingProvider.notifier).confirmBooking(
          umkmId: user.uid,
          warehouseId: widget.warehouseId,
          warehouseName: widget.warehouseName,
          volumeM3: _volumeM3,
          pricePerM3PerDay: widget.pricePerM3PerDay,
          startDate: _startDate,
          durationDays: _durationDays,
          remainingCapacity: widget.remainingCapacity,
        );

    if (!mounted) return;
    final state = ref.read(bookingProvider);
    if (state.phase == BookingPhase.bookingActive) {
      // Booking berhasil — tampilkan dialog sukses lalu pop
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: AppColors.accent, size: 48),
          title: const Text('Pemesanan Berhasil!'),
          content: Text(
            'Gudang ${widget.warehouseName} telah dipesan.\n'
            'Volume: ${_volumeM3.toStringAsFixed(1)} m³\n'
            'Durasi: $_durationDays hari\n'
            'Total: ${CurrencyUtils.formatRupiah(state.estimatedCost ?? 0)}',
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(true);
              },
              child: const Text('Kembali'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bookingProvider);
    final capacityExceeded = _volumeM3 > widget.remainingCapacity;

    return Scaffold(
      appBar: AppBar(title: const Text('Pemesanan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Warehouse info card
            _WarehouseInfoCard(
              name: widget.warehouseName,
              pricePerM3PerDay: widget.pricePerM3PerDay,
              remainingCapacity: widget.remainingCapacity,
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Volume stepper
            _StepperField(
              label: 'Volume (m³)',
              value: _volumeM3.toStringAsFixed(1),
              onIncrement: _incrementVolume,
              onDecrement: _decrementVolume,
            ),

            // Capacity error
            if (capacityExceeded) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Kapasitas tidak mencukupi',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),

            // Start date picker
            _DatePickerField(
              label: 'Tanggal Mulai',
              date: _startDate,
              onTap: _pickStartDate,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Duration stepper
            _StepperField(
              label: 'Durasi Sewa (hari)',
              value: '$_durationDays',
              onIncrement: _incrementDuration,
              onDecrement: _decrementDuration,
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Cost estimator
            if (state.phase == BookingPhase.costDisplayed &&
                state.estimatedCost != null)
              CostEstimatorWidget(
                volumeM3: _volumeM3,
                pricePerM3PerDay: widget.pricePerM3PerDay,
                durationDays: _durationDays,
                totalCost: state.estimatedCost!,
              ),

            if (state.errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                state.errorMessage!,
                style: AppTextStyles.caption.copyWith(color: AppColors.error),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),

            // CTA
            AppPrimaryButton(
              label: 'Konfirmasi Pemesanan',
              onPressed: capacityExceeded ||
                      state.phase == BookingPhase.processingPayment
                  ? null
                  : _confirmBooking,
              isLoading: state.phase == BookingPhase.processingPayment,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private widgets
// ---------------------------------------------------------------------------

class _WarehouseInfoCard extends StatelessWidget {
  const _WarehouseInfoCard({
    required this.name,
    required this.pricePerM3PerDay,
    required this.remainingCapacity,
  });

  final String name;
  final double pricePerM3PerDay;
  final double remainingCapacity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: AppTextStyles.heading3),
          const SizedBox(height: AppSpacing.sm),
          Text(
            CurrencyUtils.formatPricePerM3PerDay(pricePerM3PerDay),
            style: AppTextStyles.bodyRegular.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Sisa kapasitas: ${remainingCapacity.toStringAsFixed(1)} m³',
            style: AppTextStyles.caption.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepperField extends StatelessWidget {
  const _StepperField({
    required this.label,
    required this.value,
    required this.onIncrement,
    required this.onDecrement,
  });

  final String label;
  final String value;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.labelMedium.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(AppRadius.input),
          ),
          child: Row(
            children: [
              _StepperButton(icon: Icons.remove, onTap: onDecrement),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.heading3,
                ),
              ),
              _StepperButton(icon: Icons.add, onTap: onIncrement),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.full),
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: AppColors.accent),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final formatted = DateFormat('dd MMMM yyyy', 'id_ID').format(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.labelMedium.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.input),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md + 2,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(AppRadius.input),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 18, color: scheme.onSurface),
                const SizedBox(width: AppSpacing.md),
                Text(formatted, style: AppTextStyles.bodyRegular),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
