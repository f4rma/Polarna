import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_form_primitives.dart';
import '../../../../core/theme/app_primitives.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/entities/user_entity.dart';
import '../providers/auth_provider.dart';

/// Registration page — UMKM/Mitra segmented selector, password strength
/// meter, T&C checkbox. On success, signs the user out (Req 1.10) and shows
/// a confirmation dialog before routing to the verification-pending page.
class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  UserRole _role = UserRole.umkm;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = false;
  bool _submitting = false;
  Failure? _failure;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_agreedToTerms) {
      setState(() => _failure = const _TermsRequiredFailure());
      return;
    }

    setState(() {
      _submitting = true;
      _failure = null;
    });

    final phone = '+62${_phoneCtrl.text.trim()}';
    final result = await ref.read(authProvider.notifier).signUp(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          fullName: _nameCtrl.text.trim(),
          phoneNumber: phone,
          role: _role,
        );

    if (!mounted) return;
    result.fold(
      (f) => setState(() {
        _submitting = false;
        _failure = f;
      }),
      (_) async {
        setState(() => _submitting = false);
        await _showSuccessDialog();
        if (!mounted) return;
        context.go(RouteConstants.login);
      },
    );
  }

  Future<void> _showSuccessDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.mark_email_read_outlined,
          size: 48,
          color: AppColors.accent,
        ),
        title: const Text('Akun berhasil dibuat'),
        content: const Text(
          'Silakan cek email Anda untuk melakukan verifikasi sebelum masuk.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Ke halaman masuk'),
          ),
        ],
      ),
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: const Icon(
                Icons.warehouse_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Polarna',
              style: AppTextStyles.heading3.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        centerTitle: true,
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
                  if (_failure != null) ...[
                    AppBanner(
                      message: _failure!.message,
                      variant: AppBannerVariant.error,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  Text(
                    'Buat Akun Baru',
                    style: AppTextStyles.heading1.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Gabung sekarang untuk mulai mengelola logistik',
                    style: AppTextStyles.bodyRegular.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppSegmentedToggle<UserRole>(
                    values: const [UserRole.umkm, UserRole.mitra],
                    selected: _role,
                    onChanged: _submitting
                        ? (_) {}
                        : (r) => setState(() => _role = r),
                    labels: const {
                      UserRole.umkm: 'UMKM',
                      UserRole.mitra: 'Mitra',
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  RichText(
                    text: TextSpan(
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                      children: const [
                        TextSpan(text: '* Pilih '),
                        TextSpan(
                          text: 'UMKM',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        TextSpan(text: ' untuk pengiriman, '),
                        TextSpan(
                          text: 'Mitra',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        TextSpan(text: ' untuk penyedia gudang/armada.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppTextInput(
                    controller: _nameCtrl,
                    label: 'Nama Lengkap',
                    hint: 'Masukkan nama lengkap',
                    prefixIcon: Icons.person_outline,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.name],
                    enabled: !_submitting,
                    validator: (v) {
                      final r = Validators.validateFullName(v);
                      return r.isValid ? null : r.errorMessage;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextInput(
                    controller: _emailCtrl,
                    label: 'Alamat Email',
                    hint: 'contoh@polarna.com',
                    prefixIcon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    enabled: !_submitting,
                    validator: (v) {
                      final r = Validators.validateEmail(v);
                      return r.isValid ? null : r.errorMessage;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _PhoneField(
                    controller: _phoneCtrl,
                    enabled: !_submitting,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextInput(
                    controller: _passwordCtrl,
                    label: 'Kata Sandi',
                    hint: 'Min. 8 karakter, huruf kapital + angka',
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
                  AppPasswordStrengthMeter(password: _passwordCtrl.text),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextInput(
                    controller: _confirmCtrl,
                    label: 'Konfirmasi Kata Sandi',
                    hint: 'Ulangi kata sandi',
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
                        return 'Konfirmasi kata sandi tidak boleh kosong';
                      }
                      if (v != _passwordCtrl.text) {
                        return 'Konfirmasi kata sandi tidak cocok';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _TermsCheckbox(
                    value: _agreedToTerms,
                    onChanged: _submitting
                        ? null
                        : (v) => setState(() => _agreedToTerms = v ?? false),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppPrimaryButton(
                    label: 'Daftar',
                    onPressed: _submit,
                    isLoading: _submitting,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Sudah punya akun? ',
                        style: AppTextStyles.bodyRegular.copyWith(
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                      GestureDetector(
                        onTap: _submitting
                            ? null
                            : () => context.go(RouteConstants.login),
                        child: Text(
                          'Masuk',
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
}

/// Indonesia-prefixed phone input (`+62 | 8XX...`).
class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NOMOR TELEPON',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textPrimaryLight,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs + 2),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(AppRadius.input),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md + 4,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: AppColors.borderLight),
                  ),
                ),
                child: Text(
                  '+62',
                  style: AppTextStyles.bodyRegular.copyWith(
                    color: AppColors.textPrimaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  enabled: enabled,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(13),
                  ],
                  decoration: const InputDecoration(
                    hintText: '812 3456 7890',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md + 4,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Nomor telepon tidak boleh kosong';
                    }
                    if (v.length < 8) {
                      return 'Nomor telepon terlalu pendek';
                    }
                    if (!v.startsWith(RegExp(r'[1-9]'))) {
                      return 'Nomor telepon harus diawali angka 1-9';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        Expanded(
          child: GestureDetector(
            onTap: onChanged == null ? null : () => onChanged!(!value),
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: RichText(
                text: TextSpan(
                  style: AppTextStyles.bodyRegular.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                  children: const [
                    TextSpan(text: 'Saya setuju dengan '),
                    TextSpan(
                      text: 'Syarat & Ketentuan',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    TextSpan(text: ' serta '),
                    TextSpan(
                      text: 'Kebijakan Privasi',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    TextSpan(text: ' Polarna.'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TermsRequiredFailure extends Failure {
  const _TermsRequiredFailure()
      : super('Silakan setujui Syarat & Ketentuan terlebih dahulu.');
}
