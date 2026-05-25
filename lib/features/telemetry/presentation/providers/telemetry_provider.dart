import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../notification/domain/services/breach_detector.dart';
import '../../data/providers/telemetry_data_providers.dart';
import '../../domain/entities/telemetry_entity.dart';
import '../../domain/usecases/export_telemetry_csv_usecase.dart';

// ---------------------------------------------------------------------------
// Sensor status enum
// ---------------------------------------------------------------------------

/// Represents the connectivity status of the IoT sensor.
enum SensorStatus {
  /// Sensor is connected and sending data normally.
  connected,

  /// Sensor has not sent data for > 5 minutes.
  disconnected,

  /// Sensor is not responding (no data received at all).
  noResponse,
}

// ---------------------------------------------------------------------------
// Time range for history chart
// ---------------------------------------------------------------------------

/// Selectable time ranges for the telemetry chart.
enum TelemetryTimeRange {
  sixHours,
  twentyFourHours,
  sevenDays,
}

// ---------------------------------------------------------------------------
// Telemetry state
// ---------------------------------------------------------------------------

/// Immutable state for the telemetry monitoring page.
class TelemetryState {
  final TelemetryRecord? latest;
  final List<TelemetryRecord> history;
  final SensorStatus status;
  final bool isBreach;
  final String? lastUpdateText;
  final TelemetryTimeRange timeRange;
  final double? threshold;
  final bool isLoadingHistory;

  const TelemetryState({
    this.latest,
    this.history = const [],
    this.status = SensorStatus.noResponse,
    this.isBreach = false,
    this.lastUpdateText,
    this.timeRange = TelemetryTimeRange.sixHours,
    this.threshold,
    this.isLoadingHistory = false,
  });

  TelemetryState copyWith({
    TelemetryRecord? latest,
    List<TelemetryRecord>? history,
    SensorStatus? status,
    bool? isBreach,
    String? lastUpdateText,
    TelemetryTimeRange? timeRange,
    double? threshold,
    bool? isLoadingHistory,
  }) {
    return TelemetryState(
      latest: latest ?? this.latest,
      history: history ?? this.history,
      status: status ?? this.status,
      isBreach: isBreach ?? this.isBreach,
      lastUpdateText: lastUpdateText ?? this.lastUpdateText,
      timeRange: timeRange ?? this.timeRange,
      threshold: threshold ?? this.threshold,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
    );
  }
}

// ---------------------------------------------------------------------------
// Telemetry notifier
// ---------------------------------------------------------------------------

/// Manages real-time telemetry state for a single warehouse.
///
/// Subscribes to the Firestore stream via [TelemetryRepository] and
/// auto-detects sensor status based on data freshness.
class TelemetryNotifier extends StateNotifier<TelemetryState> {
  final Ref _ref;
  final String warehouseId;
  final double threshold;

  StreamSubscription<TelemetryRecord>? _streamSub;
  Timer? _freshnessTimer;

  /// Duration after which sensor is considered disconnected.
  static const _disconnectTimeout = Duration(minutes: 5);

  TelemetryNotifier({
    required Ref ref,
    required this.warehouseId,
    required this.threshold,
  })  : _ref = ref,
        super(TelemetryState(threshold: threshold)) {
    _subscribe();
    _loadHistory();
  }

  void _subscribe() {
    final repo = _ref.read(telemetryRepositoryProvider);
    _streamSub = repo.watchLatestTelemetry(warehouseId).listen(
      _onData,
      onError: (Object error) {
        // Log untuk debugging
        // ignore: avoid_print
        print('Telemetry stream error: $error');
        state = state.copyWith(
          status: SensorStatus.disconnected,
          lastUpdateText: 'Koneksi terputus: ${error.toString()}',
        );
      },
    );
  }

  void _onData(TelemetryRecord record) {
    final breachResult = BreachDetector.detect(
      currentTemp: record.temperature,
      threshold: threshold,
    );

    final elapsed = DateTime.now().difference(record.timestamp);
    final updateText = _formatElapsed(elapsed);

    state = state.copyWith(
      latest: record,
      status: SensorStatus.connected,
      isBreach: breachResult == BreachStatus.violation,
      lastUpdateText: updateText,
    );

    // Reset freshness timer on each new reading.
    _freshnessTimer?.cancel();
    _freshnessTimer = Timer(_disconnectTimeout, () {
      state = state.copyWith(
        status: SensorStatus.disconnected,
        lastUpdateText: 'Sensor tidak merespons',
      );
    });
  }

  /// Loads history based on the current time range selection.
  Future<void> _loadHistory() async {
    state = state.copyWith(isLoadingHistory: true);

    final now = DateTime.now();
    final from = _rangeStart(state.timeRange, now);

    final repo = _ref.read(telemetryRepositoryProvider);
    final result = await repo.getHistory(
      warehouseId: warehouseId,
      from: from,
      to: now,
    );

    result.fold(
      (_) => state = state.copyWith(history: [], isLoadingHistory: false),
      (records) => state = state.copyWith(
        history: records,
        isLoadingHistory: false,
      ),
    );
  }

  /// Changes the selected time range and reloads history.
  void setTimeRange(TelemetryTimeRange range) {
    state = state.copyWith(timeRange: range);
    _loadHistory();
  }

  /// Exports telemetry history as CSV string.
  Future<String?> exportCsv() async {
    final now = DateTime.now();
    final from = _rangeStart(state.timeRange, now);

    final useCase = ExportTelemetryCsvUseCase(
      _ref.read(telemetryRepositoryProvider),
    );

    final result = await useCase.call(ExportTelemetryCsvParams(
      warehouseId: warehouseId,
      from: from,
      to: now,
    ));

    return result.fold((_) => null, (csv) => csv);
  }

  DateTime _rangeStart(TelemetryTimeRange range, DateTime now) {
    switch (range) {
      case TelemetryTimeRange.sixHours:
        return now.subtract(const Duration(hours: 6));
      case TelemetryTimeRange.twentyFourHours:
        return now.subtract(const Duration(hours: 24));
      case TelemetryTimeRange.sevenDays:
        return now.subtract(const Duration(days: 7));
    }
  }

  String _formatElapsed(Duration elapsed) {
    if (elapsed.inSeconds < 60) {
      return 'Diperbarui ${elapsed.inSeconds} detik lalu';
    } else if (elapsed.inMinutes < 60) {
      return 'Diperbarui ${elapsed.inMinutes} menit lalu';
    } else {
      return 'Diperbarui ${elapsed.inHours} jam lalu';
    }
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _freshnessTimer?.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Provider family — one notifier per warehouse
// ---------------------------------------------------------------------------

/// Parameters for creating a [TelemetryNotifier].
class TelemetryProviderParams {
  final String warehouseId;
  final double threshold;

  const TelemetryProviderParams({
    required this.warehouseId,
    required this.threshold,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TelemetryProviderParams &&
          other.warehouseId == warehouseId &&
          other.threshold == threshold;

  @override
  int get hashCode => Object.hash(warehouseId, threshold);
}

/// Provides a [TelemetryNotifier] scoped to a specific warehouse.
final telemetryNotifierProvider = StateNotifierProvider.family<
    TelemetryNotifier, TelemetryState, TelemetryProviderParams>(
  (ref, params) => TelemetryNotifier(
    ref: ref,
    warehouseId: params.warehouseId,
    threshold: params.threshold,
  ),
);
