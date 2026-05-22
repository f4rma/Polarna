import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_form_primitives.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/auth_provider.dart';

/// "Email Terkirim!" success screen reached from forgot-password / register.
/// Shows a 60-second cooldown on the resend button.
class EmailSentPage extends ConsumerStatefulWidget {
  const EmailSentPage({super.key, required this.email});

  final String email;

  @override
  ConsumerState<EmailSentPage> createState() => _EmailSentPageState();
}

class _EmailSentPageState extends ConsumerState<EmailSentPage> {
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
    final result = await ref
        .read(authProvider.notifier)
        .resetPassword(email: widget.email);
    if (!mounted) return;
    setState(() => _resending = false);
    final messenger = ScaffoldMessenger.of(context);
    result.fold(
      (f) => messenger.showSnackBar(SnackBar(content: Text(f.message))),
      (_) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Tautan reset telah dikirim ulang.')),
        );
        _startCooldown();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _remaining == 0 && !_resending;
    final resendLabel = _remaining > 0
        ? 'Kirim Ulang ($_remaining)'
        : (_resending ? 'Mengirim…' : 'Kirim Ulang');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
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
                  const _SuccessCheck(),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Email Terkirim!',
                    style: AppTextStyles.heading1.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: AppTextStyles.bodyRegular.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                      children: [
                        const TextSpan(text: 'Tautan reset telah dikirim ke '),
                        TextSpan(
                          text: widget.email,
                          style: AppTextStyles.bodyRegular.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(
                          text: '. Cek folder spam jika tidak ditemukan.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  AppPrimaryButton(
                    label: 'Buka Aplikasi Email',
                    icon: Icons.mail_outline,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Buka aplikasi email perangkat Anda secara manual.',
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppSecondaryButton(
                    label: resendLabel,
                    onPressed: canResend ? _resend : null,
                    isLoading: _resending,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.go(RouteConstants.login),
                    child: Text(
                      'Kembali ke Login',
                      style: AppTextStyles.bodyRegular.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
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

class _SuccessCheck extends StatelessWidget {
  const _SuccessCheck();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: AppColors.successSoft,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.successSoft, width: 12),
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.success,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 40, color: Colors.white),
      ),
    );
  }
}
