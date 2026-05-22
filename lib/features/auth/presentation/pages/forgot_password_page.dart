import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_form_primitives.dart';
import '../../../../core/theme/app_primitives.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/validators.dart';
import '../providers/auth_provider.dart';
import 'email_sent_page.dart';

/// "Lupa kata sandi" page — sends a reset link, then routes to
/// [EmailSentPage] on success.
class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() =>
      _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();

  bool _submitting = false;
  Failure? _failure;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _failure = null;
    });

    final email = _emailCtrl.text.trim();
    final result =
        await ref.read(authProvider.notifier).resetPassword(email: email);

    if (!mounted) return;
    setState(() => _submitting = false);

    result.fold(
      (f) => setState(() => _failure = f),
      (_) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => EmailSentPage(email: email)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteConstants.login),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            const _DecorativeCircles(),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    children: [
                      if (_failure != null) ...[
                        AppBanner(
                          message: _failure!.message,
                          variant: AppBannerVariant.error,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      const SizedBox(height: AppSpacing.huge),
                      const _LockIcon(),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Lupa Kata Sandi?',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.heading1.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Masukkan email Anda dan kami akan mengirim tautan reset',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyRegular.copyWith(
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxxl),
                      AppTextInput(
                        controller: _emailCtrl,
                        label: 'Email',
                        hint: 'Masukkan email terdaftar',
                        prefixIcon: Icons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.email],
                        enabled: !_submitting,
                        onFieldSubmitted: (_) => _submit(),
                        validator: (v) {
                          final r = Validators.validateEmail(v);
                          return r.isValid ? null : r.errorMessage;
                        },
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AppPrimaryButton(
                        label: 'Kirim Tautan Reset',
                        icon: Icons.send_rounded,
                        onPressed: _submit,
                        isLoading: _submitting,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Center(
                        child: TextButton(
                          onPressed: _submitting
                              ? null
                              : () => context.go(RouteConstants.login),
                          child: Text(
                            'Kembali ke Login',
                            style: AppTextStyles.bodyRegular.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockIcon extends StatelessWidget {
  const _LockIcon();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.borderLight.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline,
              size: 56,
              color: AppColors.primary,
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text(
                '?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft decorative blobs in the background (matches Figma).
class _DecorativeCircles extends StatelessWidget {
  const _DecorativeCircles();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -60,
          right: -40,
          child: _circle(120, AppColors.borderLight.withValues(alpha: 0.4)),
        ),
        Positioned(
          bottom: -80,
          left: -60,
          child: _circle(160, AppColors.borderLight.withValues(alpha: 0.4)),
        ),
      ],
    );
  }

  Widget _circle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
