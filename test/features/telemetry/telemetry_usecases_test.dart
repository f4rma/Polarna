// Unit tests for telemetry use cases.
//
// Validates: Requirements 5.1–5.4, 6.1–6.5
// Reference: .kiro/specs/coldshare-platform/requirements.md
//
// Covers:
//   - GetRealtimeTelemetryUseCase: returns stream from repo
//   - GetTelemetryHistoryUseCase: delegates params, returns Right/Left
//   - ExportTelemetryCsvUseCase: fetches history → produces CSV string;
//     empty history → headers only; failure propagated
//
// A hand-rolled fake repository is injected directly.
// No Firebase, no mockito, no build_runner.

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polarna/core/errors/failures.dart';
import 'package:polarna/features/telemetry/domain/entities/telemetry_entity.dart';
import 'package:polarna/features/telemetry/domain/usecases/export_telemetry_csv_usecase.dart';
import 'package:polarna/features/telemetry/domain/usecases/get_realtime_telemetry_usecase.dart';
import 'package:polarna/features/telemetry/domain/usecases/get_telemetry_history_usecase.dart';

import 'fakes/fake_telemetry_repository.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

TelemetryRecord _makeRecord({
  String warehouseId = 'wh-1',
  DateTime? timestamp,
  double temperature = -5.0,
  double humidity = 60.0,
}) {
  return TelemetryRecord(
    warehouseId: warehouseId,
    timestamp: timestamp ?? DateTime.utc(2025, 1, 15, 10, 30),
    temperature: temperature,
    humidity: humidity,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  group('GetRealtimeTelemetryUseCase', () {
    late FakeTelemetryRepository fakeRepo;
    late GetRealtimeTelemetryUseCase useCase;

    setUp(() {
      fakeRepo = FakeTelemetryRepository();
      useCase = GetRealtimeTelemetryUseCase(fakeRepo);
    });

    tearDown(() => fakeRepo.dispose());

    test('returns stream from repository', () {
      final stream = useCase.call(
        const GetRealtimeTelemetryParams(warehouseId: 'wh-1'),
      );

      expect(stream, isA<Stream<TelemetryRecord>>());
      expect(fakeRepo.watchLatestTelemetryCalls, 1);
    });

    test('stream emits records added to controller', () async {
      final stream = useCase.call(
        const GetRealtimeTelemetryParams(warehouseId: 'wh-1'),
      );

      // Listen first, then emit, then verify
      final future = stream.first;
      final record = _makeRecord();
      fakeRepo.emitTelemetry(record);

      final emitted = await future;
      expect(emitted, record);
    });

    test('stream propagates errors', () async {
      final stream = useCase.call(
        const GetRealtimeTelemetryParams(warehouseId: 'wh-1'),
      );

      // Listen first, then emit error
      final future = stream.first;
      fakeRepo.emitError(Exception('connection lost'));

      expect(() => future, throwsA(isA<Exception>()));
    });
  });

  // -------------------------------------------------------------------------
  group('GetTelemetryHistoryUseCase', () {
    late FakeTelemetryRepository fakeRepo;
    late GetTelemetryHistoryUseCase useCase;

    setUp(() {
      fakeRepo = FakeTelemetryRepository();
      useCase = GetTelemetryHistoryUseCase(fakeRepo);
    });

    tearDown(() => fakeRepo.dispose());

    test('delegates params to repository and returns Right', () async {
      final records = [_makeRecord(), _makeRecord(temperature: -3.0)];
      fakeRepo.getHistoryResponses.add(Right(records));

      final from = DateTime.utc(2025, 1, 1);
      final to = DateTime.utc(2025, 1, 31);

      final result = await useCase.call(GetTelemetryHistoryParams(
        warehouseId: 'wh-1',
        from: from,
        to: to,
      ));

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (list) => expect(list.length, 2),
      );

      // Verify delegation
      expect(fakeRepo.getHistoryCalls.length, 1);
      expect(fakeRepo.getHistoryCalls.first.warehouseId, 'wh-1');
      expect(fakeRepo.getHistoryCalls.first.from, from);
      expect(fakeRepo.getHistoryCalls.first.to, to);
    });

    test('returns Left on failure', () async {
      fakeRepo.getHistoryResponses.add(const Left(ServerFailure()));

      final result = await useCase.call(GetTelemetryHistoryParams(
        warehouseId: 'wh-1',
        from: DateTime.utc(2025, 1, 1),
        to: DateTime.utc(2025, 1, 31),
      ));

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('Expected Left'),
      );
    });
  });

  // -------------------------------------------------------------------------
  group('ExportTelemetryCsvUseCase', () {
    late FakeTelemetryRepository fakeRepo;
    late ExportTelemetryCsvUseCase useCase;

    setUp(() {
      fakeRepo = FakeTelemetryRepository();
      useCase = ExportTelemetryCsvUseCase(fakeRepo);
    });

    tearDown(() => fakeRepo.dispose());

    test('fetches history and produces CSV string', () async {
      final records = [
        _makeRecord(
          warehouseId: 'wh-1',
          timestamp: DateTime.utc(2025, 1, 15, 10, 0),
          temperature: -5.0,
          humidity: 60.0,
        ),
        _makeRecord(
          warehouseId: 'wh-1',
          timestamp: DateTime.utc(2025, 1, 15, 11, 0),
          temperature: -4.5,
          humidity: 62.0,
        ),
      ];
      fakeRepo.getHistoryResponses.add(Right(records));

      final result = await useCase.call(ExportTelemetryCsvParams(
        warehouseId: 'wh-1',
        from: DateTime.utc(2025, 1, 15),
        to: DateTime.utc(2025, 1, 16),
      ));

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (csv) {
          // Should contain headers
          expect(csv, contains('Timestamp'));
          expect(csv, contains('Suhu'));
          expect(csv, contains('Kelembapan'));
          expect(csv, contains('ID Gudang'));
          // Should contain data
          expect(csv, contains('-5.0'));
          expect(csv, contains('60.0'));
          expect(csv, contains('-4.5'));
          expect(csv, contains('62.0'));
          expect(csv, contains('wh-1'));
        },
      );
    });

    test('empty history → returns CSV with headers only', () async {
      fakeRepo.getHistoryResponses.add(const Right([]));

      final result = await useCase.call(ExportTelemetryCsvParams(
        warehouseId: 'wh-1',
        from: DateTime.utc(2025, 1, 15),
        to: DateTime.utc(2025, 1, 16),
      ));

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (csv) {
          expect(csv, contains('Timestamp'));
          expect(csv, contains('Suhu'));
          expect(csv, contains('Kelembapan'));
          // No data rows — just the header line
          final lines = csv.trim().split('\n');
          expect(lines.length, 1);
        },
      );
    });

    test('failure from repository is propagated', () async {
      fakeRepo.getHistoryResponses.add(const Left(NoInternetFailure()));

      final result = await useCase.call(ExportTelemetryCsvParams(
        warehouseId: 'wh-1',
        from: DateTime.utc(2025, 1, 15),
        to: DateTime.utc(2025, 1, 16),
      ));

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<NoInternetFailure>()),
        (_) => fail('Expected Left'),
      );
    });
  });
}
