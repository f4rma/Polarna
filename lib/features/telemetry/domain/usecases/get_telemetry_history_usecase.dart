import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/telemetry_entity.dart';
import '../repositories/telemetry_repository.dart';

/// Parameters for [GetTelemetryHistoryUseCase].
class GetTelemetryHistoryParams extends Equatable {
  final String warehouseId;
  final DateTime from;
  final DateTime to;

  const GetTelemetryHistoryParams({
    required this.warehouseId,
    required this.from,
    required this.to,
  });

  @override
  List<Object?> get props => [warehouseId, from, to];
}

/// Fetches historical telemetry data for a warehouse within a date range.
///
/// Delegates entirely to [TelemetryRepository.getHistory].
///
/// Requirements: 6.1–6.3.
class GetTelemetryHistoryUseCase {
  final TelemetryRepository repository;

  const GetTelemetryHistoryUseCase(this.repository);

  Future<Either<Failure, List<TelemetryRecord>>> call(
    GetTelemetryHistoryParams params,
  ) {
    return repository.getHistory(
      warehouseId: params.warehouseId,
      from: params.from,
      to: params.to,
    );
  }
}
