import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cache/memory_cache.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../data/providers/warehouse_data_providers.dart';
import '../../domain/entities/warehouse_entity.dart';
import '../../domain/entities/warehouse_search_filter.dart';
import '../../domain/repositories/warehouse_repository.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Immutable state for the warehouse search/list feature.
class WarehouseState extends Equatable {
  final List<WarehouseEntity> warehouses;
  final WarehouseSearchFilter filter;
  final bool isLoading;
  final Failure? error;
  final WarehouseEntity? selectedWarehouse;

  const WarehouseState({
    this.warehouses = const [],
    this.filter = const WarehouseSearchFilter(),
    this.isLoading = false,
    this.error,
    this.selectedWarehouse,
  });

  WarehouseState copyWith({
    List<WarehouseEntity>? warehouses,
    WarehouseSearchFilter? filter,
    bool? isLoading,
    Failure? error,
    WarehouseEntity? selectedWarehouse,
    bool clearError = false,
    bool clearSelected = false,
  }) {
    return WarehouseState(
      warehouses: warehouses ?? this.warehouses,
      filter: filter ?? this.filter,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      selectedWarehouse:
          clearSelected ? null : (selectedWarehouse ?? this.selectedWarehouse),
    );
  }

  @override
  List<Object?> get props => [
        warehouses,
        filter,
        isLoading,
        error,
        selectedWarehouse,
      ];
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Manages warehouse search state with auto-refresh every 60 seconds.
class WarehouseNotifier extends StateNotifier<WarehouseState> {
  final WarehouseRepository _repository;
  final MemoryCache _cache;
  Timer? _refreshTimer;

  static const _cacheKeySearch = 'warehouse_search';

  WarehouseNotifier(this._repository, this._cache)
      : super(const WarehouseState()) {
    _startAutoRefresh();
  }

  /// Searches warehouses using the current filter.
  Future<void> search() async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _repository.searchWarehouses(state.filter);

    result.fold(
      (failure) {
        // On NoInternetFailure, return cached data if available.
        if (failure is NoInternetFailure) {
          final cached = _cache.get<List<WarehouseEntity>>(_cacheKeySearch);
          if (cached != null) {
            state = state.copyWith(isLoading: false, warehouses: cached);
            return;
          }
        }
        state = state.copyWith(isLoading: false, error: failure);
      },
      (warehouses) {
        _cache.set<List<WarehouseEntity>>(_cacheKeySearch, warehouses);
        state = state.copyWith(isLoading: false, warehouses: warehouses);
      },
    );
  }

  /// Updates the filter and triggers a new search.
  Future<void> updateFilter(WarehouseSearchFilter filter) async {
    state = state.copyWith(filter: filter);
    await search();
  }

  /// Resets the filter to defaults and triggers a new search.
  Future<void> resetFilter() async {
    state = state.copyWith(filter: const WarehouseSearchFilter());
    await search();
  }

  /// Selects a warehouse by ID and fetches its latest data.
  Future<void> selectWarehouse(String id) async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _repository.getById(id);

    result.fold(
      (failure) => state = state.copyWith(isLoading: false, error: failure),
      (warehouse) => state = state.copyWith(
        isLoading: false,
        selectedWarehouse: warehouse,
      ),
    );
  }

  /// Refreshes the current search results (same filter).
  Future<void> refresh() async {
    await search();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(
      const Duration(seconds: AppConstants.warehouseRefreshIntervalSeconds),
      (_) {
        if (state.warehouses.isNotEmpty) {
          search();
        }
      },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Mitra Warehouses State
// ---------------------------------------------------------------------------

/// State for the Mitra "Gudang Saya" page.
class MitraWarehousesState extends Equatable {
  final List<WarehouseEntity> warehouses;
  final bool isLoading;
  final Failure? error;

  const MitraWarehousesState({
    this.warehouses = const [],
    this.isLoading = false,
    this.error,
  });

  MitraWarehousesState copyWith({
    List<WarehouseEntity>? warehouses,
    bool? isLoading,
    Failure? error,
    bool clearError = false,
  }) {
    return MitraWarehousesState(
      warehouses: warehouses ?? this.warehouses,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [warehouses, isLoading, error];
}

/// Manages the Mitra's own warehouse list.
class MitraWarehousesNotifier extends StateNotifier<MitraWarehousesState> {
  final WarehouseRepository _repository;
  final String _mitraId;

  MitraWarehousesNotifier(this._repository, this._mitraId)
      : super(const MitraWarehousesState());

  /// Fetches all warehouses belonging to this Mitra.
  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _repository.getByMitraId(_mitraId);

    result.fold(
      (failure) => state = state.copyWith(isLoading: false, error: failure),
      (warehouses) =>
          state = state.copyWith(isLoading: false, warehouses: warehouses),
    );
  }

  /// Toggles a warehouse's active status.
  Future<void> toggleStatus(String warehouseId, {required bool isActive}) async {
    final result = await _repository.toggleStatus(
      warehouseId: warehouseId,
      isActive: isActive,
    );

    result.fold(
      (failure) => state = state.copyWith(error: failure),
      (_) {
        final updated = state.warehouses.map((w) {
          if (w.id == warehouseId) return w.copyWith(isActive: isActive);
          return w;
        }).toList();
        state = state.copyWith(warehouses: updated);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Provider for UMKM warehouse search.
final warehouseProvider =
    StateNotifierProvider<WarehouseNotifier, WarehouseState>((ref) {
  final repository = ref.watch(warehouseRepositoryProvider);
  final cache = ref.watch(memoryCacheProvider);
  return WarehouseNotifier(repository, cache);
});

/// Provider for Mitra's own warehouses. Requires a mitra ID.
final mitraWarehousesProvider = StateNotifierProvider.family<
    MitraWarehousesNotifier, MitraWarehousesState, String>((ref, mitraId) {
  final repository = ref.watch(warehouseRepositoryProvider);
  return MitraWarehousesNotifier(repository, mitraId);
});
