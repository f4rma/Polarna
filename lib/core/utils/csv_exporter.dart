import 'package:csv/csv.dart';

/// Utility class for exporting data to CSV format.
///
/// Uses the `csv` package to produce RFC 4180-compliant CSV strings.
class CsvExporter {
  CsvExporter._();

  // ---------------------------------------------------------------------------
  // Generic CSV builder
  // ---------------------------------------------------------------------------

  /// Converts a list of rows (each row is a list of values) into a CSV string.
  ///
  /// [headers] is the first row (column names).
  /// [rows] are the data rows.
  static String buildCsv({
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) {
    final data = <List<dynamic>>[headers, ...rows];
    return const ListToCsvConverter().convert(data);
  }

  // ---------------------------------------------------------------------------
  // Transaction CSV (Requirement 8.6)
  // ---------------------------------------------------------------------------

  /// Builds a CSV string for transaction export.
  ///
  /// Columns: ID Transaksi, Nama UMKM, Volume (m³), Tanggal Mulai,
  ///          Tanggal Berakhir, Total Biaya (Rp), Status Pembayaran
  static String buildTransactionCsv(
      List<Map<String, dynamic>> transactions) {
    const headers = [
      'ID Transaksi',
      'Nama UMKM',
      'Volume (m³)',
      'Tanggal Mulai',
      'Tanggal Berakhir',
      'Total Biaya (Rp)',
      'Status Pembayaran',
    ];

    final rows = transactions.map((t) {
      return [
        t['id'] ?? '',
        t['umkmName'] ?? '',
        t['volumeM3'] ?? '',
        t['startDate'] ?? '',
        t['endDate'] ?? '',
        t['totalCost'] ?? '',
        t['paymentStatus'] ?? '',
      ];
    }).toList();

    return buildCsv(headers: headers, rows: rows);
  }

  // ---------------------------------------------------------------------------
  // Telemetry CSV (Requirement 6.4)
  // ---------------------------------------------------------------------------

  /// Builds a CSV string for telemetry history export.
  ///
  /// Columns: Timestamp, Suhu (°C), Kelembapan (%)
  static String buildTelemetryCsv(List<Map<String, dynamic>> records) {
    const headers = [
      'Timestamp',
      'Suhu (°C)',
      'Kelembapan (%)',
      'ID Gudang',
    ];

    final rows = records.map((r) {
      return [
        r['timestamp'] ?? '',
        r['temperature'] ?? '',
        r['humidity'] ?? '',
        r['warehouseId'] ?? '',
      ];
    }).toList();

    return buildCsv(headers: headers, rows: rows);
  }

  // ---------------------------------------------------------------------------
  // Filename helpers
  // ---------------------------------------------------------------------------

  /// Generates a timestamped filename for a CSV export.
  /// Example: "transaksi_2025-01-15.csv"
  static String generateFilename(String prefix) {
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return '${prefix}_$date.csv';
  }
}
