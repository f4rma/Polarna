// Polarna design-system primitives.
//
// Lightweight, theme-aware widgets composed from `app_tokens.dart` /
// `app_typography.dart`. All widgets have `const` constructors and pull
// theme-dependent colours from `Theme.of(context)` so a single primitive
// renders correctly in either light (UMKM) or dark (Mitra) themes.

import 'package:flutter/material.dart';

import 'app_tokens.dart';
import 'app_typography.dart';

// ---------------------------------------------------------------------------
// AppCard — rounded surface with soft elevation.
// ---------------------------------------------------------------------------

/// Material-3 style card surface with rounded corners and a subtle shadow.
/// Tap-able when [onTap] is provided.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.color,
    this.borderRadius = AppRadius.card,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final double borderRadius;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(borderRadius);

    final decoration = BoxDecoration(
      color: color ?? scheme.surface,
      borderRadius: radius,
      border: border,
      boxShadow: AppElevation.card,
    );

    final content = Padding(padding: padding, child: child);

    if (onTap == null) {
      return DecoratedBox(decoration: decoration, child: content);
    }
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: content,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AppPillContainer — generic pill-shaped wrapper.
// ---------------------------------------------------------------------------

class AppPillContainer extends StatelessWidget {
  const AppPillContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.xs,
    ),
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// AppStatusBadge — small pill badge with bg + foreground colour.
// ---------------------------------------------------------------------------

class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({
    super.key,
    required this.label,
    required this.color,
    required this.bgColor,
    this.leadingIcon,
    this.dot = false,
  });

  final String label;
  final Color color;
  final Color bgColor;
  final IconData? leadingIcon;

  /// When `true`, renders a small filled dot instead of [leadingIcon].
  final bool dot;

  // --- Named factories — match the Figma component vocabulary -----------

  factory AppStatusBadge.frozen() {
    return const AppStatusBadge(
      label: 'FROZEN',
      color: AppColors.primary,
      bgColor: Color(0xFFDCE5F0),
      leadingIcon: Icons.ac_unit,
    );
  }

  factory AppStatusBadge.chilled() {
    return const AppStatusBadge(
      label: 'CHILLED',
      color: AppColors.accent,
      bgColor: Color(0xFFCFF4FA),
      leadingIcon: Icons.water_drop_outlined,
    );
  }

  factory AppStatusBadge.active() {
    return const AppStatusBadge(
      label: 'AKTIF',
      color: AppColors.success,
      bgColor: AppColors.successSoft,
    );
  }

  factory AppStatusBadge.completed() {
    return const AppStatusBadge(
      label: 'SELESAI',
      color: AppColors.neutralStrong,
      bgColor: AppColors.neutralSoft,
    );
  }

  factory AppStatusBadge.cancelled() {
    return const AppStatusBadge(
      label: 'DIBATALKAN',
      color: AppColors.error,
      bgColor: AppColors.errorSoft,
    );
  }

  factory AppStatusBadge.paid() {
    return const AppStatusBadge(
      label: 'TERBAYAR',
      color: AppColors.success,
      bgColor: AppColors.successSoft,
    );
  }

  factory AppStatusBadge.unpaid() {
    return const AppStatusBadge(
      label: 'BELUM BAYAR',
      color: AppColors.warning,
      bgColor: AppColors.warningSoft,
    );
  }

  factory AppStatusBadge.connected() {
    return const AppStatusBadge(
      label: 'Terhubung',
      color: AppColors.success,
      bgColor: AppColors.successSoft,
      dot: true,
    );
  }

  factory AppStatusBadge.offline() {
    return const AppStatusBadge(
      label: 'Offline',
      color: AppColors.error,
      bgColor: AppColors.errorSoft,
      dot: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    if (dot) {
      children
        ..add(Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ))
        ..add(const SizedBox(width: AppSpacing.xs));
    } else if (leadingIcon != null) {
      children
        ..add(Icon(leadingIcon, size: 12, color: color))
        ..add(const SizedBox(width: AppSpacing.xs));
    }
    children.add(
      Text(
        label,
        style: AppTextStyles.labelMedium.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

// ---------------------------------------------------------------------------
// AppFilterChip — toggleable pill chip with smooth selected state.
// ---------------------------------------------------------------------------

class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leadingIcon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = selected ? scheme.primary : scheme.surface;
    final fg = selected ? scheme.onPrimary : scheme.onSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 16, color: fg),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(
              label,
              style: AppTextStyles.bodyRegular.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AppRoundIconAvatar — circular icon container.
// ---------------------------------------------------------------------------

class AppRoundIconAvatar extends StatelessWidget {
  const AppRoundIconAvatar({
    super.key,
    required this.icon,
    this.size = 40,
    this.backgroundColor,
    this.iconColor,
  });

  final IconData icon;
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? scheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: size * 0.5,
        color: iconColor ?? scheme.onPrimaryContainer,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AppBanner — top-of-page status banner.
// ---------------------------------------------------------------------------

enum AppBannerVariant { error, success, warning, info }

class AppBanner extends StatelessWidget {
  const AppBanner({
    super.key,
    required this.message,
    this.variant = AppBannerVariant.error,
    this.icon,
    this.onDismiss,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final AppBannerVariant variant;
  final IconData? icon;
  final VoidCallback? onDismiss;
  final String? actionLabel;
  final VoidCallback? onAction;

  ({Color bg, Color fg, IconData defaultIcon}) _palette() {
    switch (variant) {
      case AppBannerVariant.error:
        return (
          bg: AppColors.errorSoft,
          fg: AppColors.error,
          defaultIcon: Icons.error_outline,
        );
      case AppBannerVariant.success:
        return (
          bg: AppColors.successSoft,
          fg: AppColors.success,
          defaultIcon: Icons.check_circle_outline,
        );
      case AppBannerVariant.warning:
        return (
          bg: AppColors.warningSoft,
          fg: AppColors.warning,
          defaultIcon: Icons.warning_amber_rounded,
        );
      case AppBannerVariant.info:
        return (
          bg: AppColors.infoSoft,
          fg: AppColors.info,
          defaultIcon: Icons.info_outline,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _palette();
    final children = <Widget>[
      Icon(icon ?? p.defaultIcon, size: 18, color: p.fg),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: Text(
          message,
          style: AppTextStyles.bodyRegular.copyWith(color: p.fg),
        ),
      ),
    ];
    if (actionLabel != null && onAction != null) {
      children.add(
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            foregroundColor: p.fg,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            minimumSize: const Size(0, 0),
            visualDensity: VisualDensity.compact,
          ),
          child: Text(actionLabel!),
        ),
      );
    }
    if (onDismiss != null) {
      children.add(
        IconButton(
          onPressed: onDismiss,
          icon: Icon(Icons.close, size: 18, color: p.fg),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

// ---------------------------------------------------------------------------
// AppSegmentedToggle<T> — generic pill-style segmented control.
// ---------------------------------------------------------------------------

class AppSegmentedToggle<T> extends StatelessWidget {
  const AppSegmentedToggle({
    super.key,
    required this.values,
    required this.selected,
    required this.onChanged,
    required this.labels,
    this.icons,
  });

  final List<T> values;
  final T selected;
  final ValueChanged<T> onChanged;
  final Map<T, String> labels;
  final Map<T, IconData>? icons;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Row(
        children: [
          for (final v in values)
            Expanded(child: _segment(context, v)),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, T value) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = value == selected;
    final fg = isSelected ? scheme.onPrimary : scheme.onSurface;
    final icon = icons?[value];

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.small),
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        height: 40,
        decoration: BoxDecoration(
          color: isSelected ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(
              labels[value] ?? value.toString(),
              style: AppTextStyles.bodyRegular.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AppPasswordStrengthMeter — 4-bar visual strength indicator.
// ---------------------------------------------------------------------------

class AppPasswordStrengthMeter extends StatelessWidget {
  const AppPasswordStrengthMeter({super.key, required this.password});

  final String password;

  /// Computes strength on a 0..4 scale.
  static int score(String s) {
    if (s.isEmpty) return 0;
    var score = 0;
    if (s.length >= 8) score++;
    if (s.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(s)) score++;
    if (RegExp(r'[0-9]').hasMatch(s)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\/]').hasMatch(s)) score++;
    return score > 4 ? 4 : score;
  }

  static const List<String> _labels = ['Lemah', 'Lemah', 'Sedang', 'Baik', 'Kuat'];
  static const List<Color> _colors = [
    AppColors.error,
    AppColors.error,
    AppColors.warning,
    AppColors.accent,
    AppColors.success,
  ];

  @override
  Widget build(BuildContext context) {
    final s = score(password);
    final color = _colors[s];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i < s
                        ? color
                        : Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
              if (i < 3) const SizedBox(width: 4),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Kekuatan sandi: ${_labels[s]}',
          style: AppTextStyles.caption.copyWith(color: color),
        ),
      ],
    );
  }
}
