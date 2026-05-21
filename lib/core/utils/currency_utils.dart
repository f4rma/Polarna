import 'package:intl/intl.dart';

/// Currency formatting utilities for Indonesian Rupiah (IDR).
class CurrencyUtils {
  CurrencyUtils._();

  static final NumberFormat _rupiahFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final NumberFormat _rupiahCompactFormat = NumberFormat.compactCurrency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 1,
  );

  static final NumberFormat _numberFormat = NumberFormat('#,###', 'id_ID');

  // ---------------------------------------------------------------------------
  // Formatting
  // ---------------------------------------------------------------------------

  /// Formats a numeric value as Indonesian Rupiah.
  /// Example: 1500000 → "Rp 1.500.000"
  static String formatRupiah(double amount) {
    return _rupiahFormat.format(amount);
  }

  /// Formats a numeric value as compact Indonesian Rupiah.
  /// Example: 1500000 → "Rp 1,5 jt"
  static String formatRupiahCompact(double amount) {
    return _rupiahCompactFormat.format(amount);
  }

  /// Formats a number with thousand separators (no currency symbol).
  /// Example: 1500000 → "1.500.000"
  static String formatNumber(double value) {
    return _numberFormat.format(value);
  }

  /// Formats a price per m³ per day.
  /// Example: "Rp 5.000 / m³ / hari"
  static String formatPricePerM3PerDay(double price) {
    return '${formatRupiah(price)} / m³ / hari';
  }

  // ---------------------------------------------------------------------------
  // Calculation
  // ---------------------------------------------------------------------------

  /// Calculates the total booking cost.
  /// Formula: total = volumeM3 × pricePerM3PerDay × durationDays
  static double calculateBookingCost({
    required double volumeM3,
    required double pricePerM3PerDay,
    required int durationDays,
  }) {
    return volumeM3 * pricePerM3PerDay * durationDays;
  }

  /// Formats the total booking cost as a Rupiah string.
  static String formatBookingCost({
    required double volumeM3,
    required double pricePerM3PerDay,
    required int durationDays,
  }) {
    final total = calculateBookingCost(
      volumeM3: volumeM3,
      pricePerM3PerDay: pricePerM3PerDay,
      durationDays: durationDays,
    );
    return formatRupiah(total);
  }

  // ---------------------------------------------------------------------------
  // Parsing
  // ---------------------------------------------------------------------------

  /// Parses a Rupiah-formatted string back to a [double].
  /// Returns `null` if parsing fails.
  static double? parseRupiah(String value) {
    try {
      // Remove "Rp ", dots (thousand separators), and trim
      final cleaned = value
          .replaceAll('Rp', '')
          .replaceAll('.', '')
          .replaceAll(',', '.')
          .trim();
      return double.parse(cleaned);
    } catch (_) {
      return null;
    }
  }
}
