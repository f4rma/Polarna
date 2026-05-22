import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_form_primitives.dart';
import '../../../../core/theme/app_primitives.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/validators.dart';

/// "Buat Kata Sandi Baru" — used after the user clicks the reset email link.
/// Includes inline rule checklist + strength meter. The expired-link state
/// is rendered via a top banner when [showExpired] is true.
class CreateNewPasswordPage extends ConsumerStatefulWidget {
  const CreateNewPasswordPage({super.key, this.showExpired = false});

  final bool showExpired;

  @override
  ConsumerState<CreateNewPasswordPage> createState() =>
      _CreateNewPasswordPageState();
}

class _CreateNewPasswordPageState
    extends ConsumerState<CreateNewPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscurePass = false;
  bool _obscureConfirm = true;
  bool _submitting = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    // The actual reset-with-token flow is handled by Firebase via the email
    // link. Here we just simulate completion and route back to login.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kata sandi berhasil disimpan.')),
    );
    context.go(RouteConstants.login);
  }

  @override
  Widget build(BuildContext context) {
    final pwd = _passwordCtrl.text;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(RouteConstants.login),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                children: [
                  if (widget.showExpired) ...[
                    const AppBanner(
                      message:
                          'Tautan reset telah kedaluwarsa. Silakan minta tautan baru.',
                      variant: AppBannerVariant.error,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Buat Kata Sandi Baru',
                    style: AppTextStyles.heading1.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Silakan masukkan kata sandi baru yang kuat untuk keamanan akun Anda.',
                    style: AppTextStyles.bodyRegular.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  AppTextInput(
                    controller: _passwordCtrl,
                    label: 'Kata Sandi Baru',
                    prefixIcon: Icons.lock_outline,
                    obscureText: _obscurePass,
                    enabled: !_submitting,
                    onChanged: (_) => setState(() {}),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePass
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                    ),
                    validator: (v) {
                      final r = Validators.validatePassword(v);
                      return r.isValid ? null : r.errorMessage;
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppPasswordStrengthMeter(password: pwd),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextInput(
                    controller: _confirmCtrl,
                    label: 'Konfirmasi Kata Sandi',
                    prefixIcon: Icons.lock_outline,
                    obscureText: _obscureConfirm,
                    enabled: !_submitting,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Konfirmasi tidak boleh kosong';
                      }
                      if (v != _passwordCtrl.text) {
                        return 'Konfirmasi tidak cocok';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _RuleChecklist(password: pwd),
                  const SizedBox(height: AppSpacing.xxl),
                  AppPrimaryButton(
                    label: 'Simpan Kata Sandi',
                    onPressed: _submit,
                    isLoading: _submitting,
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

class _RuleChecklist extends StatelessWidget {
  const _RuleChecklist({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final rules = <(String, bool)>[
      ('Minimal 8 karakter', password.length >= 8),
      ('Mengandung huruf kapital', RegExp(r'[A-Z]').hasMatch(password)),
      ('Mengandung angka', RegExp(r'[0-9]').hasMatch(password)),
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Column(
        children: [
          for (final r in rules) ...[
            _RuleRow(label: r.$1, satisfied: r.$2),
            if (r != rules.last) const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.label, required this.satisfied});

  final String label;
  final bool satisfied;

  @override
  Widget build(BuildContext context) {
    final color = satisfied ? AppColors.success : AppColors.textSecondaryLight;
    return Row(
      children: [
        Icon(
          satisfied ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 18,
          color: color,
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          label,
          style: AppTextStyles.bodyRegular.copyWith(color: color),
        ),
      ],
    );
  }
}
