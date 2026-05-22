import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_form_primitives.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/auth_provider.dart';

/// Email verification pending — dark theme. Shown after registration
/// while the user verifies their email link.
class EmailVerificationPendingPage extends ConsumerStatefulWidget {
  const EmailVerificationPendingPage({super.key, required this.email});

  final String email;

  @override
  ConsumerState<EmailVerificationPendingPage> createState() =>
      _EmailVerificationPendingPageState();
}

class _EmailVerificationPendingPageState
    extends ConsumerState<EmailVerificationPendingPage> {
  static const int _cooldownSeconds = 60;
  Timer? _timer;
  int _remaining = _cooldownSeconds;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _remaining = _cooldownSeconds);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_remaining <= 1) {
          _remaining = 0;
          t.cancel();
        } else {
          _remaining--;
        }
      });
    });
  }

  Future<void> _resend() async {
    if (_resending || _remaining > 0) return;
    setState(() => _resending = true);
    final result =
        await ref.read(authProvider.notifier).resendEmailVerification();
    if (!mounted) return;
    setState(() => _resending = false);
    result.fold(
      (f) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(f.message))),
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email verifikasi telah dikirim ulang.')),
        );
        _startCooldown();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _darkPageTheme(),
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundDark,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _MailIcon(success: true),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Cek Email Anda',
                      style: AppTextStyles.heading1.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Kami telah mengirim link verifikasi ke',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyRegular.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      widget.email,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.huge),
                    AppPrimaryButton(
                      label: 'Kirim Ulang Email',
                      onPressed: _remaining == 0 ? _resend : null,
                      isLoading: _resending,
                    ),
                    if (_remaining > 0) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Kirim ulang dalam $_remaining detik',
                        style: AppTextStyles.bodyRegular.copyWith(
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    AppSecondaryButton(
                      label: 'Ganti Email',
                      onPressed: () => context.go(RouteConstants.register),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xl),
                      child: GestureDetector(
                        onTap: () => context.go(RouteConstants.login),
                        child: RichText(
                          text: TextSpan(
                            style: AppTextStyles.bodyRegular.copyWith(
                              color: AppColors.textSecondaryDark,
                            ),
                            children: [
                              const TextSpan(text: 'Sudah diverifikasi? '),
                              TextSpan(
                                text: 'Masuk',
                                style: AppTextStyles.bodyRegular.copyWith(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w700,
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
            ),
          ),
        ),
      ),
    );
  }
}

/// Email verification error — same layout, with red banner + clock badge.
class EmailVerificationErrorPage extends StatelessWidget {
  const EmailVerificationErrorPage({super.key, required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _darkPageTheme(),
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundDark,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.errorSoft,
                    borderRadius: BorderRadius.circular(AppRadius.input),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error,
                          size: 18, color: AppColors.error),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Tautan verifikasi telah kedaluwarsa',
                          style: AppTextStyles.bodyRegular.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const _MailIcon(success: false),
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            'Verifikasi Gagal',
                            style: AppTextStyles.heading1.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: AppTextStyles.bodyRegular.copyWith(
                                color: AppColors.textSecondaryDark,
                              ),
                              children: [
                                const TextSpan(
                                  text: 'Kami telah mengirim link verifikasi ke\n',
                                ),
                                TextSpan(
                                  text: email,
                                  style: AppTextStyles.bodyRegular.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const TextSpan(
                                  text:
                                      '\nnamun waktu berlaku tautan tersebut telah berakhir.',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.huge),
                          AppPrimaryButton(
                            label: 'Minta Tautan Baru',
                            icon: Icons.arrow_forward,
                            onPressed: () =>
                                Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) =>
                                    EmailVerificationPendingPage(email: email),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppSecondaryButton(
                            label: 'Ganti Email',
                            onPressed: () =>
                                Navigator.of(context).pushNamedAndRemoveUntil(
                              RouteConstants.register,
                              (_) => false,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => Navigator.of(context)
                                .pushNamedAndRemoveUntil(
                              RouteConstants.login,
                              (_) => false,
                            ),
                            child: RichText(
                              text: TextSpan(
                                style: AppTextStyles.bodyRegular.copyWith(
                                  color: AppColors.textSecondaryDark,
                                ),
                                children: [
                                  const TextSpan(text: 'Kembali ke halaman '),
                                  TextSpan(
                                    text: 'Masuk',
                                    style: AppTextStyles.bodyRegular.copyWith(
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MailIcon extends StatelessWidget {
  const _MailIcon({required this.success});

  final bool success;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.mail_outline,
            size: 48,
            color: AppColors.accent,
          ),
        ),
        Positioned(
          bottom: -6,
          right: -6,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: success ? AppColors.accent : AppColors.error,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.backgroundDark, width: 3),
            ),
            child: Icon(
              success ? Icons.check : Icons.access_time,
              size: 14,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

/// Forces a dark surface for these two pages even when the role-based
/// theme is light (signed-out user during registration).
ThemeData _darkPageTheme() {
  return ThemeData.dark(useMaterial3: true).copyWith(
    scaffoldBackgroundColor: AppColors.backgroundDark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: AppColors.primary,
      surface: AppColors.surfaceDark,
      onSurface: Colors.white,
    ),
  );
}
