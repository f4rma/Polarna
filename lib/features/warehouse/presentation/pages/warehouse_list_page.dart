import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_form_primitives.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/warehouse_provider.dart';
import '../widgets/warehouse_card_widget.dart';

/// Mitra "Gudang Saya" page — lists all warehouses owned by the current Mitra.
///
/// Shows warehouse cards with photo, name, address, capacity bar, category
/// badge, sensor status, edit link, and active/inactive toggle.
/// Displays an empty state when no warehouses are registered.
class WarehouseListPage extends ConsumerStatefulWidget {
  const WarehouseListPage({super.key});

  @override
  ConsumerState<WarehouseListPage> createState() => _WarehouseListPageState();
}

class _WarehouseListPageState extends ConsumerState<WarehouseListPage> {
  String get _mitraId =>
      ref.read(authProvider).valueOrNull?.uid ?? '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final uid = ref.read(authProvider).valueOrNull?.uid;
      if (uid != null && uid.isNotEmpty) {
        ref.read(mitraWarehousesProvider(uid).notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mitraWarehousesProvider(_mitraId));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Gudang Saya',
          style: AppTextStyles.heading2.copyWith(color: scheme.onSurface),
        ),
        automaticallyImplyLeading: false,
      ),
      body: _buildBody(state, scheme),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await context.push<bool>(RouteConstants.mitraWarehouseRegister);
          if (result == true && mounted) {
            ref.read(mitraWarehousesProvider(_mitraId).notifier).load();
          }
        },
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildBody(MitraWarehousesState state, ColorScheme scheme) {
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
                onPressed: () => ref
                    .read(mitraWarehousesProvider(_mitraId).notifier)
                    .load(),
                variant: AppButtonVariant.accent,
              ),
            ],
          ),
        ),
      );
    }

    if (state.warehouses.isEmpty) {
      return _EmptyState(
        onRegister: () => context.push(RouteConstants.mitraWarehouseRegister),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(mitraWarehousesProvider(_mitraId).notifier).load(),
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: state.warehouses.length,
        separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final warehouse = state.warehouses[index];
          return WarehouseCardWidget(
            warehouse: warehouse,
            showToggle: true,
            onTap: () => context.push(
              RouteConstants.warehouseDetailPath(warehouse.id),
            ),
            onToggleActive: (isActive) {
              ref
                  .read(mitraWarehousesProvider(_mitraId).notifier)
                  .toggleStatus(warehouse.id, isActive: isActive);
            },
            onEdit: () => context.push(
              RouteConstants.warehouseEditPath(warehouse.id),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRegister});

  final VoidCallback onRegister;

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
              Icons.warehouse_outlined,
              size: 64,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Belum Ada Gudang',
              style: AppTextStyles.heading2.copyWith(
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Daftarkan gudang pertama Anda untuk\nmulai menerima pemesanan',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyRegular.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppPrimaryButton(
              label: 'Daftarkan Gudang Pertama',
              icon: Icons.add,
              onPressed: onRegister,
              variant: AppButtonVariant.accent,
            ),
          ],
        ),
      ),
    );
  }
}
