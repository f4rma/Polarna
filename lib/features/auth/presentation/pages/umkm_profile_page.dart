import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_animations.dart';
import '../../../../core/theme/app_primitives.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/account_switcher_widget.dart';
import '../../domain/entities/user_entity.dart';
import '../providers/auth_provider.dart';

/// Profile page for UMKM users.
///
/// Displays avatar, name, role badge, and menu items with a sign-out button.
/// Requirements: 1.4, 1.8
class UmkmProfilePage extends ConsumerWidget {
  const UmkmProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.valueOrNull;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // Avatar + name section
            _ProfileHeader(user: user).fadeScaleIn(),
            const SizedBox(height: AppSpacing.xxl),

            // Menu items
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _MenuItem(
                    icon: Icons.history,
                    label: 'Riwayat Transaksi',
                    onTap: () => context.push(RouteConstants.umkmBookings),
                  ),
                  const Divider(height: 1),
                  _MenuItem(
                    icon: Icons.notifications_outlined,
                    label: 'Notifikasi',
                    onTap: () => context.push(RouteConstants.umkmNotifications),
                  ),
                  const Divider(height: 1),
                  _MenuItem(
                    icon: Icons.help_outline,
                    label: 'Bantuan',
                    onTap: () => context.push(RouteConstants.umkmHelp),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // Switch account section
            const AccountSwitcherWidget(),
            const SizedBox(height: AppSpacing.md),

            // Sign out button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _signOut(context, ref),
                icon: const Icon(Icons.logout),
                label: const Text('Keluar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.error,
                  side: BorderSide(color: scheme.error),
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(authProvider.notifier).signOut();
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final UserEntity? user;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = user?.fullName ?? '-';
    final email = user?.email ?? '-';

    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: scheme.primaryContainer,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: AppTextStyles.heading1.copyWith(
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(name, style: AppTextStyles.heading2),
        const SizedBox(height: AppSpacing.xs),
        Text(email, style: AppTextStyles.bodyRegular.copyWith(
          color: scheme.onSurfaceVariant,
        )),
        const SizedBox(height: AppSpacing.sm),
        AppStatusBadge(
          label: 'UMKM',
          color: AppColors.primary,
          bgColor: AppColors.infoSoft,
          outlined: true,
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label, style: AppTextStyles.bodyRegular),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
