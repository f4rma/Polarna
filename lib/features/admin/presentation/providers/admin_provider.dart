import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/entities/user_entity.dart';
import '../../data/providers/admin_data_providers.dart';
import '../../domain/entities/platform_summary.dart';
import '../../domain/repositories/admin_repository.dart';
import '../../domain/usecases/get_platform_summary_usecase.dart';
import '../../domain/usecases/manage_users_usecase.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Immutable state for the admin feature.
class AdminState extends Equatable {
  final PlatformSummary? summary;
  final List<UserEntity> users;
  final bool isLoading;
  final String? errorMessage;

  const AdminState({
    this.summary,
    this.users = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  AdminState copyWith({
    PlatformSummary? summary,
    List<UserEntity>? users,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AdminState(
      summary: summary ?? this.summary,
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [summary, users, isLoading, errorMessage];
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Manages admin dashboard state: platform summary and user management.
class AdminNotifier extends StateNotifier<AdminState> {
  final GetPlatformSummaryUseCase _getPlatformSummary;
  final ActivateUserUseCase _activateUser;
  final DeactivateUserUseCase _deactivateUser;
  final AdminRepository _repository;

  AdminNotifier({
    required GetPlatformSummaryUseCase getPlatformSummary,
    required ActivateUserUseCase activateUser,
    required DeactivateUserUseCase deactivateUser,
    required AdminRepository repository,
  })  : _getPlatformSummary = getPlatformSummary,
        _activateUser = activateUser,
        _deactivateUser = deactivateUser,
        _repository = repository,
        super(const AdminState());

  /// Loads platform-wide summary metrics.
  Future<void> loadSummary() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await _getPlatformSummary.call();
    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
      (summary) => state = state.copyWith(
        isLoading: false,
        summary: summary,
      ),
    );
  }

  /// Loads all registered users.
  Future<void> loadUsers() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await _repository.getAllUsers();
    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
      (users) => state = state.copyWith(
        isLoading: false,
        users: users,
      ),
    );
  }

  /// Activates a user account by [userId].
  Future<void> activateUser(String userId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await _activateUser.call(
      ManageUserParams(userId: userId),
    );
    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
      (_) async {
        await loadUsers();
      },
    );
  }

  /// Deactivates a user account by [userId].
  Future<void> deactivateUser(String userId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await _deactivateUser.call(
      ManageUserParams(userId: userId),
    );
    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
      (_) async {
        await loadUsers();
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Provides the [AdminNotifier] wired to all admin use cases.
final adminNotifierProvider =
    StateNotifierProvider<AdminNotifier, AdminState>((ref) {
  final repository = ref.watch(adminRepositoryProvider);
  return AdminNotifier(
    getPlatformSummary: GetPlatformSummaryUseCase(repository),
    activateUser: ActivateUserUseCase(repository),
    deactivateUser: DeactivateUserUseCase(repository),
    repository: repository,
  );
});
