import 'package:equatable/equatable.dart';

import '../entities/telemetry_entity.dart';
import '../repositories/telemetry_repository.dart';

/// Parameters for [GetRealtimeTelemetryUseCase].
class GetRealtimeTelemetryParams extends Equatable {
  final String warehouseId;

  const GetRealtimeTelemetryParams({required this.warehouseId});

  @override
  List<Object?> get props => [warehouseId];
}

/// Subscribes to real-time telemetry updates for a warehouse.
///
/// Returns a raw [Stream] — errors propagate as stream errors rather than
/// being wrapped in Either, since streams have their own error channel.
///
/// Requirements: 5.1–5.4.
class GetRealtimeTelemetryUseCase {
  final TelemetryRepository repository;

  const GetRealtimeTelemetryUseCase(this.repository);

  Stream<TelemetryRecord> call(GetRealtimeTelemetryParams params) {
    return repository.watchLatestTelemetry(params.warehouseId);
  }
}
