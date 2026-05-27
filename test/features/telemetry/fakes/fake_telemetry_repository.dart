// Hand-rolled fake for [TelemetryRepository] used by TelemetryNotifier and
// use-case unit tests.
//
// No mockito / build_runner — plain Dart only. Responses are enqueued by the
// test; each call pops the next queued response. If a queue is empty when a
// method is called, a [StateError] is thrown so tests fail loudly.

import 'dart:async';
import 'dart:collection';

import 'package:dartz/dartz.dart';
import 'package:polarna/core/errors/failures.dart';
import 'package:polarna/features/telemetry/domain/entities/telemetry_entity.dart';
import 'package:polarna/features/telemetry/domain/repositories/telemetry_repository.dart';

/// Captured arguments of a single `getHistory` call.
class GetHistoryCall {
  final String warehouseId;
  final DateTime from;
  final DateTime to;
  const GetHistoryCall(this.warehouseId, this.from, this.to);
}

/// Captured arguments of a single `getLatest` call.
class GetLatestCall {
  final String warehouseId;
  const GetLatestCall(this.warehouseId);
}

class FakeTelemetryRepository implements TelemetryRepository {
  // ---------------------------------------------------------------------------
  // Response queues — tests enqueue responses in the order they expect them.
  // ---------------------------------------------------------------------------

  final Queue<Either<Failure, List<TelemetryRecord>>> getHistoryResponses =
      Queue();
  final Queue<Either<Failure, TelemetryRecord?>> getLatestResponses = Queue();

  // ---------------------------------------------------------------------------
  // Invocation log — tests assert on call counts and arguments.
  // ---------------------------------------------------------------------------

  final List<GetHistoryCall> getHistoryCalls = [];
  final List<GetLatestCall> getLatestCalls = [];
  int watchLatestTelemetryCalls = 0;

  // ---------------------------------------------------------------------------
  // Stream controller for watchLatestTelemetry.
  // ---------------------------------------------------------------------------

  final StreamController<TelemetryRecord> telemetryStreamController =
      StreamController<TelemetryRecord>.broadcast();

  /// Convenience — emit a telemetry record on the stream.
  void emitTelemetry(TelemetryRecord record) =>
      telemetryStreamController.add(record);

  /// Convenience — emit an error on the stream.
  void emitError(Object error) => telemetryStreamController.addError(error);

  Future<void> dispose() => telemetryStreamController.close();

  // ---------------------------------------------------------------------------
  // Repository API.
  // ---------------------------------------------------------------------------

  @override
  Stream<TelemetryRecord> watchLatestTelemetry(String warehouseId) {
    watchLatestTelemetryCalls++;
    return telemetryStreamController.stream;
  }

  @override
  Future<Either<Failure, List<TelemetryRecord>>> getHistory({
    required String warehouseId,
    required DateTime from,
    required DateTime to,
  }) async {
    getHistoryCalls.add(GetHistoryCall(warehouseId, from, to));
    if (getHistoryResponses.isEmpty) {
      throw StateError('No getHistoryResponses queued');
    }
    return getHistoryResponses.removeFirst();
  }

  @override
  Future<Either<Failure, TelemetryRecord?>> getLatest(
    String warehouseId,
  ) async {
    getLatestCalls.add(GetLatestCall(warehouseId));
    if (getLatestResponses.isEmpty) {
      throw StateError('No getLatestResponses queued');
    }
    return getLatestResponses.removeFirst();
  }
}
