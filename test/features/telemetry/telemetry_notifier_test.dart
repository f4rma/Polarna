// Unit tests for [TelemetryNotifier].
//
// Validates: Requirements 5.1–5.4, 6.1–6.5, 7.1–7.2
// Reference: .kiro/specs/coldshare-platform/requirements.md
//
// Covers:
//   - Stream emits record → state updates (latest, status=connected, breach)
//   - No data for 5+ min → status=disconnected
//   - setTimeRange() reloads history
//   - exportCsv() returns CSV string on success, null on failure
//   - Breach detection: temp > threshold → isBreach=true
//
// A hand-rolled fake repository is injected via provider override.
// No Firebase, no mockito, no build_runner.

import 'package:dartz/dartz.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polarna/core/errors/failures.dart';
import 'package:polarna/features/telemetry/data/providers/telemetry_data_providers.dart';
import 'package:polarna/features/telemetry/domain/entities/telemetry_entity.dart';
import 'package:polarna/features/telemetry/presentation/providers/telemetry_provider.dart';

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
    timestamp: timestamp ?? DateTime.now(),
    temperature: temperature,
    humidity: humidity,
  );
}

const _testParams = TelemetryProviderParams(
  warehouseId: 'wh-1',
  threshold: -2.0,
);

/// Builds a [ProviderContainer] with the telemetry repository overridden.
ProviderContainer _makeContainer(FakeTelemetryRepository repo) {
  final container = ProviderContainer(
    overrides: [
      telemetryRepositoryProvider.overrideWithValue(repo),
    ],
  );
  return container;
}

/// Flush async microtasks so stream events and futures resolve.
Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  group('TelemetryNotifier — stream updates', () {
    late FakeTelemetryRepository fakeRepo;
    late ProviderContainer container;

    setUp(() {
      fakeRepo = FakeTelemetryRepository();
      // Queue an empty history response for the initial _loadHistory call.
      fakeRepo.getHistoryResponses.add(const Right([]));
    });

    tearDown(() {
      container.dispose();
      fakeRepo.dispose();
    });

    test('stream emits record → state.latest updates, status=connected',
        () async {
      container = _makeContainer(fakeRepo);
      container.read(telemetryNotifierProvider(_testParams));
      await _flush();

      final record = _makeRecord(temperature: -5.0);
      fakeRepo.emitTelemetry(record);
      await _flush();

      final state = container.read(telemetryNotifierProvider(_testParams));
      expect(state.latest, record);
      expect(state.status, SensorStatus.connected);
    });

    test('stream emits record with temp > threshold → isBreach=true',
        () async {
      container = _makeContainer(fakeRepo);
      container.read(telemetryNotifierProvider(_testParams));
      await _flush();

      // threshold is -2.0, so temp of 0.0 exceeds it
      final record = _makeRecord(temperature: 0.0);
      fakeRepo.emitTelemetry(record);
      await _flush();

      final state = container.read(telemetryNotifierProvider(_testParams));
      expect(state.isBreach, isTrue);
    });

    test('stream emits record with temp ≤ threshold → isBreach=false',
        () async {
      container = _makeContainer(fakeRepo);
      container.read(telemetryNotifierProvider(_testParams));
      await _flush();

      // threshold is -2.0, so temp of -3.0 is within range
      final record = _makeRecord(temperature: -3.0);
      fakeRepo.emitTelemetry(record);
      await _flush();

      final state = container.read(telemetryNotifierProvider(_testParams));
      expect(state.isBreach, isFalse);
    });

    test('stream emits record with temp exactly at threshold → isBreach=false',
        () async {
      container = _makeContainer(fakeRepo);
      container.read(telemetryNotifierProvider(_testParams));
      await _flush();

      // threshold is -2.0, temp == -2.0 → NOT a breach (only > is violation)
      final record = _makeRecord(temperature: -2.0);
      fakeRepo.emitTelemetry(record);
      await _flush();

      final state = container.read(telemetryNotifierProvider(_testParams));
      expect(state.isBreach, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  group('TelemetryNotifier — disconnection detection', () {
    late FakeTelemetryRepository fakeRepo;
    late ProviderContainer container;

    setUp(() {
      fakeRepo = FakeTelemetryRepository();
      fakeRepo.getHistoryResponses.add(const Right([]));
    });

    tearDown(() {
      container.dispose();
      fakeRepo.dispose();
    });

    test('no data for 5+ min → status=disconnected (via timer)', () {
      fakeAsync((async) {
        container = _makeContainer(fakeRepo);
        container.read(telemetryNotifierProvider(_testParams));
        async.flushMicrotasks();

        // Emit one record to set status=connected
        final record = _makeRecord();
        fakeRepo.emitTelemetry(record);
        async.flushMicrotasks();

        var state = container.read(telemetryNotifierProvider(_testParams));
        expect(state.status, SensorStatus.connected);

        // Advance time past the 5-minute disconnect timeout
        async.elapse(const Duration(minutes: 6));

        state = container.read(telemetryNotifierProvider(_testParams));
        expect(state.status, SensorStatus.disconnected);
      });
    });

    test('stream error → status=disconnected', () async {
      container = _makeContainer(fakeRepo);
      container.read(telemetryNotifierProvider(_testParams));
      await _flush();

      fakeRepo.emitError(Exception('connection lost'));
      await _flush();

      final state = container.read(telemetryNotifierProvider(_testParams));
      expect(state.status, SensorStatus.disconnected);
    });
  });

  // -------------------------------------------------------------------------
  group('TelemetryNotifier — setTimeRange', () {
    late FakeTelemetryRepository fakeRepo;
    late ProviderContainer container;

    setUp(() {
      fakeRepo = FakeTelemetryRepository();
      // Initial _loadHistory call
      fakeRepo.getHistoryResponses.add(const Right([]));
    });

    tearDown(() {
      container.dispose();
      fakeRepo.dispose();
    });

    test('setTimeRange() updates state.timeRange and reloads history',
        () async {
      container = _makeContainer(fakeRepo);
      container.read(telemetryNotifierProvider(_testParams));
      await _flush();

      // Queue response for the reload triggered by setTimeRange
      final records = [_makeRecord(), _makeRecord(temperature: -4.0)];
      fakeRepo.getHistoryResponses.add(Right(records));

      container
          .read(telemetryNotifierProvider(_testParams).notifier)
          .setTimeRange(TelemetryTimeRange.sevenDays);
      await _flush();

      final state = container.read(telemetryNotifierProvider(_testParams));
      expect(state.timeRange, TelemetryTimeRange.sevenDays);
      expect(state.history.length, 2);
      // Two getHistory calls: initial + setTimeRange reload
      expect(fakeRepo.getHistoryCalls.length, 2);
    });
  });

  // -------------------------------------------------------------------------
  group('TelemetryNotifier — exportCsv', () {
    late FakeTelemetryRepository fakeRepo;
    late ProviderContainer container;

    setUp(() {
      fakeRepo = FakeTelemetryRepository();
      // Initial _loadHistory call
      fakeRepo.getHistoryResponses.add(const Right([]));
    });

    tearDown(() {
      container.dispose();
      fakeRepo.dispose();
    });

    test('exportCsv() returns CSV string on success', () async {
      container = _makeContainer(fakeRepo);
      container.read(telemetryNotifierProvider(_testParams));
      await _flush();

      // Queue response for the export call
      final records = [
        _makeRecord(
          timestamp: DateTime.utc(2025, 1, 15, 10, 0),
          temperature: -5.0,
          humidity: 60.0,
        ),
      ];
      fakeRepo.getHistoryResponses.add(Right(records));

      final csv = await container
          .read(telemetryNotifierProvider(_testParams).notifier)
          .exportCsv();

      expect(csv, isNotNull);
      expect(csv!, contains('Timestamp'));
      expect(csv, contains('Suhu'));
      expect(csv, contains('-5.0'));
      expect(csv, contains('60.0'));
    });

    test('exportCsv() returns null on failure', () async {
      container = _makeContainer(fakeRepo);
      container.read(telemetryNotifierProvider(_testParams));
      await _flush();

      // Queue failure response for the export call
      fakeRepo.getHistoryResponses.add(const Left(ServerFailure()));

      final csv = await container
          .read(telemetryNotifierProvider(_testParams).notifier)
          .exportCsv();

      expect(csv, isNull);
    });
  });

  // -------------------------------------------------------------------------
  group('TelemetryNotifier — initial state', () {
    late FakeTelemetryRepository fakeRepo;
    late ProviderContainer container;

    setUp(() {
      fakeRepo = FakeTelemetryRepository();
      fakeRepo.getHistoryResponses.add(const Right([]));
    });

    tearDown(() {
      container.dispose();
      fakeRepo.dispose();
    });

    test('initial state has noResponse status and threshold set', () async {
      container = _makeContainer(fakeRepo);
      final state = container.read(telemetryNotifierProvider(_testParams));

      expect(state.status, SensorStatus.noResponse);
      expect(state.threshold, -2.0);
      expect(state.latest, isNull);
      expect(state.isBreach, isFalse);
    });

    test('initial _loadHistory populates history on success', () async {
      fakeRepo.getHistoryResponses.clear();
      final records = [_makeRecord(), _makeRecord(temperature: -4.0)];
      fakeRepo.getHistoryResponses.add(Right(records));

      container = _makeContainer(fakeRepo);
      container.read(telemetryNotifierProvider(_testParams));
      await _flush();

      final state = container.read(telemetryNotifierProvider(_testParams));
      expect(state.history.length, 2);
      expect(state.isLoadingHistory, isFalse);
    });
  });
}
