import 'package:flutter/material.dart';

import '../../../../core/theme/app_animations.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';

/// Initial splash with loading bar — first surface the user sees while the
/// router/auth bootstrap resolves. Pure visual; navigation is owned by the
/// router redirect.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              const _SplashLogo().fadeScaleIn(),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'Polarna',
                style: AppTextStyles.heading1.copyWith(
                  color: Colors.white,
                  fontSize: 32,
                ),
              ).fadeSlideIn(delay: 150.msDelay),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'COLD CHAIN PILIHANMU',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.accent,
                  letterSpacing: 1.5,
                ),
              ).fadeSlideIn(delay: 250.msDelay),
              const Spacer(),
              const _LoadingBar(),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'MEMUAT SISTEM…',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textSecondaryDark,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.warehouse_rounded,
            size: 48,
            color: AppColors.primary,
          ),
          Positioned(
            top: 22,
            right: 22,
            child: Icon(
              Icons.ac_unit_rounded,
              size: 16,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingBar extends StatefulWidget {
  const _LoadingBar();

  @override
  State<_LoadingBar> createState() => _LoadingBarState();
}

class _LoadingBarState extends State<_LoadingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: LinearProgressIndicator(
            value: _ctrl.value,
            minHeight: 4,
            backgroundColor: AppColors.surfaceDark.withValues(alpha: 0.4),
            valueColor: const AlwaysStoppedAnimation(AppColors.accent),
          ),
        );
      },
    );
  }
}
