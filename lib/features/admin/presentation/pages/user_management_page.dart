import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_primitives.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../providers/admin_provider.dart';

/// User management page for the Admin role.
///
/// Displays a list of all registered users with name, email, role badge,
/// registration date, and active/deactivated status toggle.
class UserManagementPage extends ConsumerStatefulWidget {
  const UserManagementPage({super.key});

  @override
  ConsumerState<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends ConsumerState<UserManagementPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(adminNotifierProvider.notifier).loadUsers(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminNotifierProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Manajemen Pengguna',
          style: AppTextStyles.heading2.copyWith(color: scheme.onSurface),
        ),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(adminNotifierProvider.notifier).loadUsers(),
        child: _buildBody(context, state, scheme),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AdminState state,
    ColorScheme scheme,
  ) {
    if (state.isLoading && state.users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null && state.users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: AppBanner(
            message: state.errorMessage!,
            variant: AppBannerVariant.error,
          ),
        ),
      );
    }

    if (state.users.isEmpty) {
      return Center(
        child: Text(
          'Belum ada pengguna terdaftar.',
          style: AppTextStyles.bodyRegular.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: state.users.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final user = state.users[index];
        return _UserCard(
          user: user,
          isLoading: state.isLoading,
          onToggleActive: () => _toggleUserStatus(user),
        );
      },
    );
  }

  void _toggleUserStatus(UserEntity user) {
    final notifier = ref.read(adminNotifierProvider.notifier);
    if (user.isActive) {
      notifier.deactivateUser(user.uid);
    } else {
      notifier.activateUser(user.uid);
    }
  }
}

// ---------------------------------------------------------------------------
// User card widget
// ---------------------------------------------------------------------------

class _UserCard extends StatelessWidget {
  final UserEntity user;
  final bool isLoading;
  final VoidCallback onToggleActive;

  const _UserCard({
    required this.user,
    required this.isLoading,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('dd MMM yyyy', 'id_ID');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: name + role badge
          Row(
            children: [
              Expanded(
                child: Text(
                  user.fullName,
                  style: AppTextStyles.heading3.copyWith(
                    color: scheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _RoleBadge(role: user.role),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Email
          Text(
            user.email,
            style: AppTextStyles.bodyRegular.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Date registered
          Text(
            'Terdaftar: ${dateFormat.format(user.createdAt)}',
            style: AppTextStyles.caption.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Status row with toggle — hide for admin accounts
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppStatusBadge(
                label: user.isActive ? 'Aktif' : 'Dinonaktifkan',
                color: user.isActive ? AppColors.success : AppColors.error,
                bgColor: user.isActive
                    ? AppColors.successSoft
                    : AppColors.errorSoft,
                dot: true,
              ),
              if (user.role != UserRole.admin)
                Switch.adaptive(
                  value: user.isActive,
                  onChanged: isLoading ? null : (_) => onToggleActive(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Role badge widget
// ---------------------------------------------------------------------------

class _RoleBadge extends StatelessWidget {
  final UserRole role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final (String label, Color color, Color bgColor) = switch (role) {
      UserRole.admin => ('Admin', AppColors.info, AppColors.infoSoft),
      UserRole.mitra => ('Mitra', AppColors.accent, const Color(0xFFCFF4FA)),
      UserRole.umkm => (
          'UMKM',
          const Color(0xFF5B8FB9), // lighter navy for visibility on dark bg
          const Color(0xFFDCE5F0),
        ),
    };

    return AppStatusBadge(
      label: label,
      color: color,
      bgColor: bgColor,
    );
  }
}
