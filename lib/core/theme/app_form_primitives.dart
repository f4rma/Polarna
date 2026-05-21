// Form-related design-system primitives — buttons, inputs, labels.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_tokens.dart';
import 'app_typography.dart';

// ---------------------------------------------------------------------------
// AppPrimaryButton — full-width primary CTA with optional loading state.
// ---------------------------------------------------------------------------

enum AppButtonVariant {
  /// Theme primary background — used by UMKM (navy) and as default.
  solid,

  /// Bright cyan with glow shadow — used by Mitra dark-theme CTAs.
  accent,
}

class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.variant = AppButtonVariant.solid,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final AppButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isAccent = variant == AppButtonVariant.accent;

    final bg = isAccent ? AppColors.accent : scheme.primary;
    final fg = isAccent ? AppColors.primary : scheme.onPrimary;

    final button = FilledButton(
      onPressed: isLoading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: bg.withValues(alpha: 0.5),
        disabledForegroundColor: fg,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
        textStyle: AppTextStyles.bodyLarge.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      child: isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(fg),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label),
                if (icon != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Icon(icon, size: 18),
                ],
              ],
            ),
    );

    if (!isAccent) return button;

    // Wrap accent variant with the cyan glow.
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.input),
        boxShadow: AppElevation.accentGlow,
      ),
      child: button,
    );
  }
}

// ---------------------------------------------------------------------------
// AppSecondaryButton — outlined secondary button.
// ---------------------------------------------------------------------------

class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        minimumSize: const Size.fromHeight(50),
        side: BorderSide(color: scheme.primary, width: 1.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
        textStyle: AppTextStyles.bodyLarge.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      child: isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(scheme.primary),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Text(label),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// AppTextInput — labelled text field with explicit error slot.
//
// Renders the label as a `Text` *above* the field (Figma style) instead of
// using Material's floating label.
// ---------------------------------------------------------------------------

class AppTextInput extends StatelessWidget {
  const AppTextInput({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.enabled = true,
    this.onFieldSubmitted,
    this.errorText,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.maxLength,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool enabled;
  final ValueChanged<String>? onFieldSubmitted;

  /// Forces an external error message; takes precedence over [validator].
  final String? errorText;

  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final int? maxLength;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!.toUpperCase(),
            style: AppTextStyles.labelMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
        ],
        TextFormField(
          controller: controller,
          enabled: enabled,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          autofillHints: autofillHints,
          maxLength: maxLength,
          onFieldSubmitted: onFieldSubmitted,
          onChanged: onChanged,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 18),
            suffixIcon: suffixIcon,
            errorText: errorText,
            counterText: '',
          ),
        ),
      ],
    );
  }
}
