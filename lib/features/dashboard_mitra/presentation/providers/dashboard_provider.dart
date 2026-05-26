import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cache/memory_cache.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../booking/domain/entities/booking_entity.dart';
import '../../data/providers/dashboard_data_providers.dart';
import '../../domain/entities/revenue_summary.dart';
import '../../domain/usecases/export_transactions_csv_usecase.dart';
import '../../domain/usecases/get_revenue_usecase.dart';

// ---------------------------------------------------------------------------
// Revenue summary provider
// ---------------------------------------------------------------------------

/// Cache key for revenue summary.
const _cacheKeyRevenue = 'dashboard_revenue';

/// Fetches the revenue summary for the currently authenticated Mitra.
///
/// Returns [AsyncValue<RevenueSummary>] — loading, data, or error.
/// On network failure, returns cached data if available (Requirement 11.5).
final revenueSummaryProvider =
    FutureProvider.autoDispose<RevenueSummary>((ref) async {
  final user = ref.watch(authProvider).valueOrNull;
  if (user == null) {
    throw StateError('User not authenticated');
  }

  final cache = ref.watch(memoryCacheProvider);
  final repo = ref.watch(dashboardRepositoryProvider);
  final useCase = GetRevenueUseCase(repo);
  final result = await useCase.call(GetRevenueParams(mitraId: user.uid));

  return result.fold(
    (failure) {
      // Return cached revenue summary when offline.
      final cached = cache.get<RevenueSummary>(_cacheKeyRevenue);
      if (cached != null) return cached;
      throw Exception(failure.toString());
    },
    (summary) {
      cache.set<RevenueSummary>(_cacheKeyRevenue, summary);
      return summary;
    },
  );
});

// ---------------------------------------------------------------------------
// Active transactions provider
// ---------------------------------------------------------------------------

/// Fetches the list of active transactions for the current Mitra.
final activeTransactionsProvider =
    FutureProvider.autoDispose<List<BookingEntity>>((ref) async {
  final user = ref.watch(authProvider).valueOrNull;
  if (user == null) {
    throw StateError('User not authenticated');
  }

  final repo = ref.watch(dashboardRepositoryProvider);
  final result = await repo.getActiveTransactions(user.uid);

  return result.fold(
    (failure) => throw Exception(failure.toString()),
    (transactions) => transactions,
  );
});

// ---------------------------------------------------------------------------
// Dashboard notifier — handles actions like CSV export
// ---------------------------------------------------------------------------

/// State for the dashboard notifier.
class DashboardState {
  final bool isExporting;
  final String? exportedCsv;
  final String? exportError;

  const DashboardState({
    this.isExporting = false,
    this.exportedCsv,
    this.exportError,
  });

  DashboardState copyWith({
    bool? isExporting,
    String? exportedCsv,
    String? exportError,
  }) {
    return DashboardState(
      isExporting: isExporting ?? this.isExporting,
      exportedCsv: exportedCsv ?? this.exportedCsv,
      exportError: exportError ?? this.exportError,
    );
  }
}

/// Manages dashboard actions such as CSV export.
class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier(this._ref) : super(const DashboardState());

  final Ref _ref;

  /// Loads the revenue summary for the given [mitraId].
  ///
  /// This is a convenience method; prefer using [revenueSummaryProvider]
  /// directly for reactive UI updates.
  Future<RevenueSummary?> loadSummary(String mitraId) async {
    final repo = _ref.read(dashboardRepositoryProvider);
    final useCase = GetRevenueUseCase(repo);
    final result = await useCase.call(GetRevenueParams(mitraId: mitraId));

    return result.fold((_) => null, (summary) => summary);
  }

  /// Exports all transactions for the given [mitraId] as a CSV string.
  ///
  /// Updates [DashboardState.exportedCsv] on success or
  /// [DashboardState.exportError] on failure.
  Future<String?> exportCsv(String mitraId) async {
    state = state.copyWith(isExporting: true, exportError: null);

    final repo = _ref.read(dashboardRepositoryProvider);
    final useCase = ExportTransactionsCsvUseCase(repo);
    final result = await useCase.call(
      ExportTransactionsCsvParams(mitraId: mitraId),
    );

    return result.fold(
      (failure) {
        state = state.copyWith(
          isExporting: false,
          exportError: failure.toString(),
        );
        return null;
      },
      (csv) {
        state = state.copyWith(isExporting: false, exportedCsv: csv);
        return csv;
      },
    );
  }
}

/// Provides the [DashboardNotifier] for imperative actions.
final dashboardNotifierProvider =
    StateNotifierProvider.autoDispose<DashboardNotifier, DashboardState>(
  (ref) => DashboardNotifier(ref),
);
