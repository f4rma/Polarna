import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_animations.dart';
import '../../../../core/theme/app_form_primitives.dart';
import '../../../../core/theme/app_primitives.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/validators.dart';
import '../providers/auth_provider.dart';

/// Login page — light theme, navy primary CTA, optional Google sign-in
/// (placeholder for now). Surfaces failures with a top-of-page banner that
/// includes a "kirim ulang verifikasi" action when applicable.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscure = true;
  bool _submitting = false;
  bool _resending = false;
  Failure? _failure;
  String? _bannerOverride;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _failure = null;
      _bannerOverride = null;
    });

    final result = await ref.read(authProvider.notifier).signIn(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _failure = result.fold((f) => f, (_) => null);
    });
  }

  Future<void> _resendVerification() async {
    if (_resending) return;
    setState(() => _resending = true);
    final result =
        await ref.read(authProvider.notifier).resendEmailVerification();
    if (!mounted) return;
    setState(() {
      _resending = false;
      result.fold(
        (f) => _failure = f,
        (_) {
          _failure = null;
          _bannerOverride = 'Email verifikasi telah dikirim ulang.';
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                children: [
                  if (_bannerOverride != null) ...[
                    AppBanner(
                      message: _bannerOverride!,
                      variant: AppBannerVariant.success,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ] else if (_failure != null) ...[
                    _buildFailureBanner(_failure!),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  const _Logo().fadeScaleIn(),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Selamat Datang',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.heading1.copyWith(
                      color: AppColors.primary,
                    ),
                  ).fadeSlideIn(delay: 100.msDelay),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Masuk untuk mengelola logistik cold chain Anda',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyRegular.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                  ).fadeSlideIn(delay: 180.msDelay),
                  const SizedBox(height: AppSpacing.xxl),
                  AppTextInput(
                    controller: _emailCtrl,
                    label: 'Alamat Email',
                    hint: 'user@email.com',
                    prefixIcon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    enabled: !_submitting,
                    validator: (v) {
                      final r = Validators.validateEmail(v);
                      return r.isValid ? null : r.errorMessage;
                    },
                  ).fadeSlideIn(delay: 260.msDelay),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextInput(
                    controller: _passwordCtrl,
                    label: 'Kata Sandi',
                    hint: '••••••••',
                    prefixIcon: Icons.lock_outline,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    enabled: !_submitting,
                    onFieldSubmitted: (_) => _submit(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Kata sandi tidak boleh kosong';
                      }
                      return null;
                    },
                  ).fadeSlideIn(delay: 320.msDelay),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _submitting
                          ? null
                          : () => context.push(RouteConstants.forgotPassword),
                      child: Text(
                        'Lupa Kata Sandi?',
                        style: AppTextStyles.bodyRegular.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppPrimaryButton(
                    label: 'Masuk',
                    onPressed: _submit,
                    isLoading: _submitting,
                  ).fadeSlideIn(delay: 380.msDelay),
                  const SizedBox(height: AppSpacing.xl),
                  const _Divider(),
                  const SizedBox(height: AppSpacing.xl),
                  AppSecondaryButton(
                    label: 'Lanjutkan dengan Google',
                    icon: Icons.g_mobiledata,
                    onPressed: _submitting ? null : () {
                      // TODO: wire up Google sign-in (out of scope)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Google sign-in belum tersedia.'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Belum punya akun? ',
                        style: AppTextStyles.bodyRegular.copyWith(
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                      GestureDetector(
                        onTap: _submitting
                            ? null
                            : () => context.push(RouteConstants.register),
                        child: Text(
                          'Daftar',
                          style: AppTextStyles.bodyRegular.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFailureBanner(Failure f) {
    if (f is EmailNotVerifiedFailure) {
      return AppBanner(
        message: f.message,
        variant: AppBannerVariant.warning,
        actionLabel: _resending ? 'Mengirim…' : 'Kirim ulang',
        onAction: _resending ? null : _resendVerification,
      );
    }
    return AppBanner(
      message: f.message,
      variant: AppBannerVariant.error,
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        'assets/icon/app_icon.png',
        width: 64,
        height: 64,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'atau',
            style: AppTextStyles.bodyRegular.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
