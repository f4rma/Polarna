import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/csv_exporter.dart';
import '../repositories/telemetry_repository.dart';

/// Parameters for [ExportTelemetryCsvUseCase].
class ExportTelemetryCsvParams extends Equatable {
  final String warehouseId;
  final DateTime from;
  final DateTime to;

  const ExportTelemetryCsvParams({
    required this.warehouseId,
    required this.from,
    required this.to,
  });

  @override
  List<Object?> get props => [warehouseId, from, to];
}

/// Exports telemetry history as a CSV string.
///
/// 1. Fetches history from the repository.
/// 2. If the fetch fails → propagates the failure.
/// 3. Converts records to CSV via [CsvExporter.buildTelemetryCsv].
/// 4. If history is empty → returns a CSV with headers only.
///
/// Requirements: 6.4–6.5.
class ExportTelemetryCsvUseCase {
  final TelemetryRepository repository;

  const ExportTelemetryCsvUseCase(this.repository);

  Future<Either<Failure, String>> call(ExportTelemetryCsvParams params) async {
    final result = await repository.getHistory(
      warehouseId: params.warehouseId,
      from: params.from,
      to: params.to,
    );

    return result.map((records) {
      final maps = records.map((r) => {
        'timestamp': r.timestamp.toUtc().toIso8601String(),
        'temperature': r.temperature,
        'humidity': r.humidity,
        'warehouseId': r.warehouseId,
      }).toList();

      return CsvExporter.buildTelemetryCsv(maps);
    });
  }
}
