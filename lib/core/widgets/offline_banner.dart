import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/network_info.dart';
import '../theme/app_tokens.dart';

/// A banner widget that appears at the top of the screen when the device
/// has no internet connection.
///
/// Uses [isConnectedProvider] from [NetworkInfo] to reactively show/hide.
/// Satisfies Requirement 11.5: display "Tidak Ada Koneksi" indicator.
class OfflineBanner extends ConsumerWidget {
  /// The child widget to display below the banner.
  final Widget child;

  const OfflineBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityAsync = ref.watch(isConnectedProvider);

    return Column(
      children: [
        connectivityAsync.when(
          data: (isConnected) =>
              isConnected ? const SizedBox.shrink() : const _BannerContent(),
          loading: () => const SizedBox.shrink(),
          error: (err, stack) => const SizedBox.shrink(),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _BannerContent extends StatelessWidget {
  const _BannerContent();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        color: AppColors.error,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: SafeArea(
          bottom: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                color: Colors.white,
                size: 16,
                semanticLabel: 'Tidak ada koneksi',
              ),
              const SizedBox(width: 8),
              Text(
                'Tidak Ada Koneksi',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A standalone offline indicator widget (not a banner — just a small chip).
/// Useful for embedding inside pages rather than wrapping the whole scaffold.
class OfflineIndicatorChip extends ConsumerWidget {
  const OfflineIndicatorChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityAsync = ref.watch(isConnectedProvider);

    return connectivityAsync.when(
      data: (isConnected) {
        if (isConnected) return const SizedBox.shrink();
        return Chip(
          avatar: const Icon(Icons.wifi_off_rounded, size: 16),
          label: const Text('Tidak Ada Koneksi'),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          labelStyle: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
            fontSize: 12,
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }
}
