import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/account_store.dart';
import '../theme/app_primitives.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

/// Displays a list of previously logged-in accounts for quick switching.
///
/// Filters out the currently logged-in user and shows the remaining saved
/// accounts. Tapping an account signs out the current user and signs in
/// with the saved credentials.
class AccountSwitcherWidget extends ConsumerStatefulWidget {
  const AccountSwitcherWidget({super.key});

  @override
  ConsumerState<AccountSwitcherWidget> createState() =>
      _AccountSwitcherWidgetState();
}

class _AccountSwitcherWidgetState
    extends ConsumerState<AccountSwitcherWidget> {
  bool _isSwitching = false;

  @override
  Widget build(BuildContext context) {
    final storeAsync = ref.watch(accountStoreProvider);
    final currentUser = ref.watch(authProvider).valueOrNull;
    final currentEmail = currentUser?.email;

    return storeAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
      data: (store) {
        final accounts = store
            .getSavedAccounts()
            .where((a) => a.email != currentEmail)
            .toList();

        if (accounts.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.xs,
                bottom: AppSpacing.sm,
              ),
              child: Text(
                'Pindah Akun',
                style: AppTextStyles.heading3,
              ),
            ),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (int i = 0; i < accounts.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _AccountTile(
                      account: accounts[i],
                      isSwitching: _isSwitching,
                      onTap: () => _switchAccount(accounts[i]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _switchAccount(SavedAccount account) async {
    if (_isSwitching) return;
    setState(() => _isSwitching = true);

    try {
      final notifier = ref.read(authProvider.notifier);
      await notifier.signOut();
      await notifier.signIn(email: account.email, password: account.password);
    } finally {
      if (mounted) setState(() => _isSwitching = false);
    }
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.isSwitching,
    required this.onTap,
  });

  final SavedAccount account;
  final bool isSwitching;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final badge = _roleBadge(account.role);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        child: Text(
          account.fullName.isNotEmpty
              ? account.fullName[0].toUpperCase()
              : '?',
          style: AppTextStyles.heading3.copyWith(
            color: scheme.onPrimaryContainer,
          ),
        ),
      ),
      title: Text(account.fullName, style: AppTextStyles.bodyRegular),
      subtitle: Row(
        children: [
          Flexible(
            child: Text(
              account.email,
              style: AppTextStyles.caption.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppStatusBadge(
            label: badge.label,
            color: badge.color,
            bgColor: badge.bgColor,
            outlined: true,
          ),
        ],
      ),
      trailing: isSwitching
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right, size: 20),
      onTap: isSwitching ? null : onTap,
    );
  }

  /// Maps a stored role string to its display badge.
  ({String label, Color color, Color bgColor}) _roleBadge(String role) {
    switch (role) {
      case 'umkm':
        return (
          label: 'UMKM',
          color: const Color(0xFF5B8FB9),
          bgColor: const Color(0xFFDCE5F0),
        );
      case 'admin':
        return (
          label: 'ADMIN',
          color: const Color.fromARGB(255, 166, 201, 39),
          bgColor: AppColors.infoSoft,
        );
      case 'mitra':
      default:
        return (
          label: 'MITRA',
          color: AppColors.accent,
          bgColor: const Color(0xFFCFF4FA),
        );
    }
  }
}
