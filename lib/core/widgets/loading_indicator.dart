import 'package:flutter/material.dart';

/// A reusable full-screen loading indicator.
///
/// Shows a centered [CircularProgressIndicator] with an optional [message].
class LoadingIndicator extends StatelessWidget {
  /// Optional message displayed below the spinner.
  final String? message;

  /// Size of the [CircularProgressIndicator]. Defaults to 48.
  final double size;

  const LoadingIndicator({
    super.key,
    this.message,
    this.size = 48.0,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 3.0,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// A compact inline loading indicator (small spinner).
class InlineLoadingIndicator extends StatelessWidget {
  final double size;
  final Color? color;

  const InlineLoadingIndicator({
    super.key,
    this.size = 20.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2.0,
        color: color ?? Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

/// A full-screen overlay loading indicator with a semi-transparent background.
class OverlayLoadingIndicator extends StatelessWidget {
  final String? message;

  const OverlayLoadingIndicator({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.4),
      child: LoadingIndicator(message: message),
    );
  }
}
