// Centralized, lightweight entrance-animation presets for Polarna.
//
// Built on top of `flutter_animate`. Every preset is intentionally subtle:
// short durations and small offsets so motion feels smooth on low-end devices
// and never blocks interaction. All effects are opacity/transform based, so
// they never change layout or cause overflow — they cannot "break" a screen.
//
// Usage:
//   MyWidget().fadeSlideIn()                 // default appear
//   MyWidget().fadeSlideIn(delay: 80.msDelay) // staggered appear
//   logo.fadeScaleIn()                       // for logos / icons
//   AppAnim.staggerDelay(index)              // compute list stagger delay

import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Animation tuning constants — kept in one place so motion stays consistent.
class AppAnim {
  AppAnim._();

  /// Standard entrance duration. Short = snappy.
  static const Duration enter = Duration(milliseconds: 350);

  /// Vertical travel for a fade+slide entrance (logical pixels).
  static const double slideOffset = 18;

  /// Per-item delay used when staggering a list/grid.
  static const Duration step = Duration(milliseconds: 60);

  /// Maximum stagger steps before delay is capped — keeps long lists from
  /// feeling sluggish at the bottom.
  static const int maxStaggerItems = 8;

  /// Computes the entrance delay for the [index]-th item in a list/grid.
  static Duration staggerDelay(int index, {Duration base = Duration.zero}) {
    final clamped = index > maxStaggerItems ? maxStaggerItems : index;
    return base + step * clamped;
  }
}

/// Convenient `Duration` builder so call-sites read nicely: `delay: 120.msDelay`.
extension AppAnimDelay on int {
  Duration get msDelay => Duration(milliseconds: this);
}

/// Lightweight entrance-animation presets attachable to any widget.
extension AppEntranceAnimations on Widget {
  /// Fade in while sliding up slightly. The default "appear" across the app.
  Widget fadeSlideIn({Duration delay = Duration.zero, double? offset}) {
    return animate()
        .fadeIn(
          duration: AppAnim.enter,
          delay: delay,
          curve: Curves.easeOut,
        )
        .moveY(
          begin: offset ?? AppAnim.slideOffset,
          end: 0,
          duration: AppAnim.enter,
          delay: delay,
          curve: Curves.easeOutCubic,
        );
  }

  /// Fade in with a gentle scale-up. Best for logos, hero icons, empty-state art.
  Widget fadeScaleIn({Duration delay = Duration.zero}) {
    return animate()
        .fadeIn(
          duration: AppAnim.enter,
          delay: delay,
          curve: Curves.easeOut,
        )
        .scaleXY(
          begin: 0.92,
          end: 1,
          duration: AppAnim.enter,
          delay: delay,
          curve: Curves.easeOutBack,
        );
  }

  /// Plain fade in — no movement. Use where layout must stay perfectly still.
  Widget fadeIn({Duration delay = Duration.zero}) {
    return animate().fadeIn(
      duration: AppAnim.enter,
      delay: delay,
      curve: Curves.easeOut,
    );
  }
}
