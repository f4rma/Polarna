import 'package:intl/intl.dart';

/// Date and time utility helpers for the ColdShare Platform.
class AppDateUtils {
  AppDateUtils._();

  // ---------------------------------------------------------------------------
  // Formatters
  // ---------------------------------------------------------------------------

  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy', 'id_ID');
  static final DateFormat _dateTimeFormat =
      DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
  static final DateFormat _timeFormat = DateFormat('HH:mm', 'id_ID');
  static final DateFormat _iso8601Format =
      DateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'");
  static final DateFormat _shortDateFormat = DateFormat('dd/MM/yyyy');

  // ---------------------------------------------------------------------------
  // Formatting
  // ---------------------------------------------------------------------------

  /// Formats a [DateTime] as a human-readable date string.
  /// Example: "15 Jan 2025"
  static String formatDate(DateTime date) => _dateFormat.format(date);

  /// Formats a [DateTime] as a human-readable date-time string.
  /// Example: "15 Jan 2025, 14:30"
  static String formatDateTime(DateTime dateTime) =>
      _dateTimeFormat.format(dateTime);

  /// Formats a [DateTime] as a time string.
  /// Example: "14:30"
  static String formatTime(DateTime dateTime) => _timeFormat.format(dateTime);

  /// Formats a [DateTime] as an ISO 8601 UTC string.
  /// Example: "2025-01-15T14:30:00Z"
  static String toIso8601(DateTime dateTime) {
    final utc = dateTime.toUtc();
    return _iso8601Format.format(utc);
  }

  /// Formats a [DateTime] as a short date string.
  /// Example: "15/01/2025"
  static String formatShortDate(DateTime date) =>
      _shortDateFormat.format(date);

  // ---------------------------------------------------------------------------
  // Parsing
  // ---------------------------------------------------------------------------

  /// Parses an ISO 8601 string to a [DateTime] in UTC.
  /// Returns `null` if parsing fails.
  static DateTime? parseIso8601(String value) {
    try {
      return DateTime.parse(value).toUtc();
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Calculations
  // ---------------------------------------------------------------------------

  /// Returns the end date given a [startDate] and [durationDays].
  static DateTime calculateEndDate(DateTime startDate, int durationDays) {
    return startDate.add(Duration(days: durationDays));
  }

  /// Returns the number of days between [start] and [end] (inclusive of start).
  static int daysBetween(DateTime start, DateTime end) {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return e.difference(s).inDays;
  }

  /// Returns `true` if [date] is strictly in the past (before today's date).
  static bool isInPast(DateTime date) {
    final today = DateTime.now();
    final d = DateTime(date.year, date.month, date.day);
    final t = DateTime(today.year, today.month, today.day);
    return d.isBefore(t);
  }

  /// Returns `true` if [date] is today or in the future.
  static bool isTodayOrFuture(DateTime date) => !isInPast(date);

  /// Returns a human-readable relative time string.
  /// Example: "2 menit lalu", "1 jam lalu", "kemarin"
  static String timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays == 1) return 'Kemarin';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return formatDate(dateTime);
  }

  /// Returns the start of the day (00:00:00) for the given [date].
  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Returns the end of the day (23:59:59) for the given [date].
  static DateTime endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59);

  /// Returns the first day of the month for the given [date].
  static DateTime startOfMonth(DateTime date) =>
      DateTime(date.year, date.month, 1);

  /// Returns the last day of the month for the given [date].
  static DateTime endOfMonth(DateTime date) =>
      DateTime(date.year, date.month + 1, 0, 23, 59, 59);

  // ---------------------------------------------------------------------------
  // Chart helpers
  // ---------------------------------------------------------------------------

  /// Returns a list of [DateTime] labels for the last [hours] hours,
  /// spaced 1 hour apart, ending at [now].
  static List<DateTime> hourlyLabels(int hours, {DateTime? now}) {
    final end = now ?? DateTime.now();
    return List.generate(
      hours,
      (i) => end.subtract(Duration(hours: hours - 1 - i)),
    );
  }
}
