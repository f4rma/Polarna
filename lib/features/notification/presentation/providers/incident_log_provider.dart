import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/notification_data_providers.dart';
import '../../domain/entities/incident_log_entity.dart';
import '../../domain/repositories/notification_repository.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Immutable state for the incident log list.
class IncidentLogState {
  const IncidentLogState({
    this.logs = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  final List<IncidentLogEntity> logs;
  final bool isLoading;
  final String? errorMessage;

  IncidentLogState copyWith({
    List<IncidentLogEntity>? logs,
    bool? isLoading,
    String? errorMessage,
  }) {
    return IncidentLogState(
      logs: logs ?? this.logs,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Manages fetching and filtering of incident logs.
///
/// Supports optional filters: [warehouseId], [from], and [to].
/// Requirements: 7.4, 10.6
class IncidentLogNotifier extends StateNotifier<IncidentLogState> {
  final NotificationRepository _repository;

  IncidentLogNotifier({required NotificationRepository repository})
      : _repository = repository,
        super(const IncidentLogState());

  /// Loads incident logs with optional filters.
  Future<void> loadLogs({
    String? warehouseId,
    DateTime? from,
    DateTime? to,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final result = await _repository.getIncidentLogs(
      warehouseId: warehouseId,
      from: from,
      to: to,
    );

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
      (logs) => state = state.copyWith(
        isLoading: false,
        logs: logs,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Provides [IncidentLogNotifier] wired to the notification repository.
final incidentLogProvider =
    StateNotifierProvider<IncidentLogNotifier, IncidentLogState>((ref) {
  return IncidentLogNotifier(
    repository: ref.watch(notificationRepositoryProvider),
  );
});
