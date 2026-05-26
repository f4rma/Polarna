import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/csv_exporter.dart';
import '../repositories/dashboard_repository.dart';

/// Parameters for [ExportTransactionsCsvUseCase].
class ExportTransactionsCsvParams extends Equatable {
  final String mitraId;
  final DateTime? from;
  final DateTime? to;

  const ExportTransactionsCsvParams({
    required this.mitraId,
    this.from,
    this.to,
  });

  @override
  List<Object?> get props => [mitraId, from, to];
}

/// Exports Mitra transactions as a CSV string.
///
/// 1. Fetches transactions from [DashboardRepository.getAllTransactions].
/// 2. If the fetch fails → propagates the failure.
/// 3. Maps each [BookingEntity] to the required CSV columns.
/// 4. Produces CSV via [CsvExporter.buildTransactionCsv].
///
/// CSV columns (Requirement 8.6):
/// ID Transaksi, Nama UMKM, Volume (m³), Tanggal Mulai,
/// Tanggal Berakhir, Total Biaya (Rp), Status Pembayaran.
class ExportTransactionsCsvUseCase {
  final DashboardRepository repository;

  const ExportTransactionsCsvUseCase(this.repository);

  Future<Either<Failure, String>> call(
    ExportTransactionsCsvParams params,
  ) async {
    final result = await repository.getAllTransactions(
      mitraId: params.mitraId,
      from: params.from,
      to: params.to,
    );

    return result.map((bookings) {
      final dateFormat = DateFormat('yyyy-MM-dd');

      final records = bookings.map((b) => <String, dynamic>{
            'id': b.id,
            'umkmName': b.warehouseName,
            'volumeM3': b.volumeM3,
            'startDate': dateFormat.format(b.startDate),
            'endDate': dateFormat.format(b.endDate),
            'totalCost': b.totalCost,
            'paymentStatus': b.paymentStatus.toStorageString(),
          }).toList();

      return CsvExporter.buildTransactionCsv(records);
    });
  }
}
