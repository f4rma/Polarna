import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_form_primitives.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';

/// Location-permission onboarding shown after registration / first launch
/// for UMKM users so the warehouse search can be centred on their location.
class LocationPermissionPage extends StatelessWidget {
  const LocationPermissionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  const _PageIndicator(currentIndex: 0, total: 3),
                  const Spacer(),
                  const _LocationIllustration(),
                  const SizedBox(height: AppSpacing.xxxl),
                  Text(
                    'Temukan Gudang Terdekat',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.heading1.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Izinkan akses lokasi untuk menemukan cold storage terbaik di sekitar Anda',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyRegular.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const Spacer(),
                  AppPrimaryButton(
                    label: 'Izinkan Akses Lokasi',
                    icon: Icons.location_on_outlined,
                    onPressed: () {
                      // TODO: wire up `geolocator.requestPermission()`
                      context.go(RouteConstants.umkmHome);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: () => context.go(RouteConstants.umkmHome),
                    child: Text(
                      'Nanti Saja',
                      style: AppTextStyles.bodyRegular.copyWith(
                        color: AppColors.textSecondaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.currentIndex, required this.total});

  final int currentIndex;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++) ...[
          Container(
            width: i == currentIndex ? 32 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == currentIndex
                  ? AppColors.accent
                  : AppColors.borderLight,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          ),
          if (i < total - 1) const SizedBox(width: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _LocationIllustration extends StatelessWidget {
  const _LocationIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.location_on,
          size: 80,
          color: AppColors.accent,
        ),
      ),
    );
  }
}
