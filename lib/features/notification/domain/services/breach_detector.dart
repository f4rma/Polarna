/// Classification result of a temperature breach check.
enum BreachStatus {
  /// Temperature exceeds the warehouse threshold.
  violation,

  /// Temperature is within acceptable range.
  normal,
}

/// Pure-function breach detector for temperature monitoring.
///
/// Compares the current temperature reading against the warehouse threshold
/// and returns the appropriate [BreachStatus].
///
/// Requirements: 7.1, 7.2
class BreachDetector {
  const BreachDetector._();

  /// Detects whether [currentTemp] violates the given [threshold].
  ///
  /// Returns [BreachStatus.violation] if `currentTemp > threshold`,
  /// otherwise returns [BreachStatus.normal].
  static BreachStatus detect({
    required double currentTemp,
    required double threshold,
  }) {
    if (currentTemp > threshold) {
      return BreachStatus.violation;
    }
    return BreachStatus.normal;
  }
}
