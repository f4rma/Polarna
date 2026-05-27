// Integration tests for the telemetry monitoring flow.
//
// Validates: Requirements 5.1–5.8, 7.1–7.8
// Reference: .kiro/specs/coldshare-platform/requirements.md
//
// Tests the full multi-step telemetry flows at the provider/notifier level:
//   - Stream emits normal reading → state connected, no breach
//   - Stream emits breach reading (temp > threshold) → isBreach=true
//   - Stream stops for 5+ min → status=disconnected
//   - Export CSV from history → produces valid CSV string
//
// Uses FakeTelemetryRepository with ProviderContainer overrides.
// No Firebase, no mockito, no build_runner.

import 'package:dartz/dartz.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polarna/core/errors/failures.dart';
import 'package:polarna/features/telemetry/data/providers/telemetry_data_providers.dart';
import 'package:polarna/features/telemetry/domain/entities/telemetry_entity.dart';
import 'package:polarna/features/telemetry/presentation/providers/telemetry_provider.dart';

import '../features/telemetry/fakes/fake_telemetry_repository.dart';

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

ProviderContainer _makeContainer(FakeTelemetryRepository repo) {
  final container = ProviderContainer(
    overrides: [
      telemetryRepositoryProvider.overrideWithValue(repo),
    ],
  );
  return container;
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

// ---------------------------------------------------------------------------
// Integration Tests
// ---------------------------------------------------------------------------

void main() {
  group('Telemetry Flow Integration — Normal reading stream', () {
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

    test(
        'stream emits normal reading → status=connected, isBreach=false, '
        'latest updated', () async {
      container = _makeContainer(fakeRepo);
      container.read(telemetryNotifierProvider(_testParams));
      await _flush();

      // Emit a normal reading (temp -5.0 < threshold -2.0)
      final record = _makeRecord(temperature: -5.0, humidity: 65.0);
      fakeRepo.emitTelemetry(record);
      await _flush();

      final state = container.read(telemetryNotifierProvider(_testParams));
      expect(state.status, SensorStatus.connected);
      expect(state.isBreach, isFalse);
      expect(state.latest, record);
      expect(state.latest!.temperature, -5.0);
      expect(state.latest!.humidity, 65.0);
      expect(state.lastUpdateText, isNotNull);
    });

    test(
        'multiple readings update state sequentially', () async {
      container = _makeContainer(fakeRepo);
      container.read(telemetryNotifierProvider(_testParams));
      await _flush();

      // First reading
      final record1 = _makeRecord(temperature: -5.0);
      fakeRepo.emitTelemetry(record1);
      await _flush();
      expect(
        container.read(telemetryNotifierProvider(_testParams)).latest,
        record1,
      );

      // Second reading replaces the first
      final record2 = _makeRecord(temperature: -3.0);
      fakeRepo.emitTelemetry(record2);
      await _flush();

      final state = container.read(telemetryNotifierProvider(_testParams));
      expect(state.latest, record2);
      expect(state.status, SensorStatus.connected);
      expect(state.isBreach, isFalse); // -3.0 < -2.0 threshold? No! -3 < -2
    });
  });

  group('Telemetry Flow Integration — Breach detection', () {
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

    test(
        'stream emits reading with temp > threshold → isBreach=true', () async {
      container = _makeContainer(fakeRepo);
      container.read(telemetryNotifierProvider(_testParams));
      await _flush();

      // threshold is -2.0, temp 0.0 > -2.0 → breach
      final breachRecord = _makeRecord(temperature: 0.0);
      fakeRepo.emitTelemetry(breachRecord);
      await _flush();

      final state = container.read(telemetryNotifierProvider(_testParams));
      expect(state.isBreach, isTrue);
      expect(state.status, SensorStatus.connected);
    });

    test(
        'breach → normal reading → isBreach returns to false', () async {
      container = _makeContainer(fakeRepo);
      container.read(telemetryNotifierProvider(_testParams));
      await _flush();

      // Breach reading
      fakeRepo.emitTelemetry(_makeRecord(temperature: 5.0));
      await _flush();
      expect(
        container.read(telemetryNotifierProvider(_testParams)).isBreach,
        isTrue,
      );

      // Normal reading restores
      fakeRepo.emitTelemetry(_makeRecord(temperature: -5.0));
      await _flush();
      expect(
        container.read(telemetryNotifierProvider(_testParams)).isBreach,
        isFalse,
      );
    });

    test(
        'temp exactly at threshold → isBreach=false (only > triggers)',
        () async {
      container = _makeContainer(fakeRepo);
      container.read(telemetryNotifierProvider(_testParams));
      await _flush();

      // threshold is -2.0, temp == -2.0 → NOT a breach
      fakeRepo.emitTelemetry(_makeRecord(temperature: -2.0));
      await _flush();

      final state = container.read(telemetryNotifierProvider(_testParams));
      expect(state.isBreach, isFalse);
    });
  });

  group('Telemetry Flow Integration — Disconnection detection', () {
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

    test(
        'no data for 5+ min after last reading → status=disconnected',
        () {
      fakeAsync((async) {
        container = _makeContainer(fakeRepo);
        container.read(telemetryNotifierProvider(_testParams));
        async.flushMicrotasks();

        // Emit one record to set status=connected
        fakeRepo.emitTelemetry(_makeRecord());
        async.flushMicrotasks();

        expect(
          container.read(telemetryNotifierProvider(_testParams)).status,
          SensorStatus.connected,
        );

        // Advance time past the 5-minute disconnect timeout
        async.elapse(const Duration(minutes: 6));

        expect(
          container.read(telemetryNotifierProvider(_testParams)).status,
          SensorStatus.disconnected,
        );
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
      expect(state.lastUpdateText, contains('terputus'));
    });

    test(
        'reconnection after disconnect → status returns to connected',
        () {
      fakeAsync((async) {
        container = _makeContainer(fakeRepo);
        container.read(telemetryNotifierProvider(_testParams));
        async.flushMicrotasks();

        // Connect
        fakeRepo.emitTelemetry(_makeRecord());
        async.flushMicrotasks();
        expect(
          container.read(telemetryNotifierProvider(_testParams)).status,
          SensorStatus.connected,
        );

        // Disconnect (timeout)
        async.elapse(const Duration(minutes: 6));
        expect(
          container.read(telemetryNotifierProvider(_testParams)).status,
          SensorStatus.disconnected,
        );

        // Reconnect (new data arrives)
        fakeRepo.emitTelemetry(_makeRecord(temperature: -4.0));
        async.flushMicrotasks();
        expect(
          container.read(telemetryNotifierProvider(_testParams)).status,
          SensorStatus.connected,
        );
      });
    });
  });

  group('Telemetry Flow Integration — CSV export', () {
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

    test('exportCsv with history → produces valid CSV with headers and data',
        () async {
      container = _makeContainer(fakeRepo);
      container.read(telemetryNotifierProvider(_testParams));
      await _flush();

      // Queue history response for the export
      final records = [
        _makeRecord(
          timestamp: DateTime.utc(2025, 1, 15, 10, 0),
          temperature: -5.0,
          humidity: 60.0,
        ),
        _makeRecord(
          timestamp: DateTime.utc(2025, 1, 15, 10, 5),
          temperature: -4.5,
          humidity: 62.0,
        ),
      ];
      fakeRepo.getHistoryResponses.add(Right(records));

      final csv = await container
          .read(telemetryNotifierProvider(_testParams).notifier)
          .exportCsv();

      expect(csv, isNotNull);
      // Verify CSV structure
      final lines = csv!.split('\n');
      // Header line
      expect(lines[0], contains('Timestamp'));
      expect(lines[0], contains('Suhu'));
      expect(lines[0], contains('Kelembapan'));
      expect(lines[0], contains('ID Gudang'));
      // Data lines
      expect(csv, contains('-5.0'));
      expect(csv, contains('60.0'));
      expect(csv, contains('-4.5'));
      expect(csv, contains('62.0'));
      expect(csv, contains('wh-1'));
    });

    test('exportCsv with empty history → CSV with headers only', () async {
      container = _makeContainer(fakeRepo);
      container.read(telemetryNotifierProvider(_testParams));
      await _flush();

      // Queue empty history response
      fakeRepo.getHistoryResponses.add(const Right([]));

      final csv = await container
          .read(telemetryNotifierProvider(_testParams).notifier)
          .exportCsv();

      expect(csv, isNotNull);
      expect(csv!, contains('Timestamp'));
      // Should only have the header line (no data rows)
      final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();
      expect(lines.length, 1); // Only header
    });

    test('exportCsv on failure → returns null', () async {
      container = _makeContainer(fakeRepo);
      container.read(telemetryNotifierProvider(_testParams));
      await _flush();

      fakeRepo.getHistoryResponses.add(const Left(ServerFailure()));

      final csv = await container
          .read(telemetryNotifierProvider(_testParams).notifier)
          .exportCsv();

      expect(csv, isNull);
    });
  });
}
