// Unit tests for NotificationRepositoryImpl using fake datasource and
// fake network info — no mockito needed.

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polarna/core/errors/exceptions.dart';
import 'package:polarna/core/errors/failures.dart';
import 'package:polarna/core/network/network_info.dart';
import 'package:polarna/features/notification/data/datasources/notification_datasource.dart';
import 'package:polarna/features/notification/data/models/incident_log_model.dart';
import 'package:polarna/features/notification/data/repositories/notification_repository_impl.dart';
import 'package:polarna/features/notification/domain/entities/incident_log_entity.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// Fake [NetworkInfo] that always reports connected (configurable).
class FakeNetworkInfo implements NetworkInfo {
  bool connected;
  FakeNetworkInfo({this.connected = true});

  @override
  Future<bool> get isConnected async => connected;

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(connected);
}

/// Fake [NotificationDataSource] with configurable responses.
class FakeNotificationDataSource implements NotificationDataSource {
  List<IncidentLogModel>? incidentLogsResult;
  IncidentLogModel? createResult;
  bool resolveSuccess = true;
  AppException? exceptionToThrow;

  @override
  Future<List<IncidentLogModel>> getIncidentLogs({
    String? warehouseId,
    DateTime? from,
    DateTime? to,
  }) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return incidentLogsResult ?? [];
  }

  @override
  Future<IncidentLogModel> createIncidentLog(IncidentLogEntity log) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
    return createResult!;
  }

  @override
  Future<void> resolveIncident(String logId, DateTime resolvedAt) async {
    if (exceptionToThrow != null) throw exceptionToThrow!;
  }
}

// ---------------------------------------------------------------------------
// Test Data
// ---------------------------------------------------------------------------

final _testTimestamp = DateTime(2024, 6, 15, 10, 30);

IncidentLogModel _createTestModel({String id = 'log-1'}) {
  return IncidentLogModel(
    id: id,
    warehouseId: 'wh-1',
    warehouseName: 'Gudang Utama',
    temperature: -15.0,
    threshold: -18.0,
    severity: 'warning',
    eventType: 'violation',
    affectedUmkmIds: const ['umkm-1', 'umkm-2'],
    notificationsSent: const ['notif-1'],
    notificationsFailed: const [],
    timestamp: _testTimestamp,
    resolvedAt: null,
  );
}

IncidentLogEntity _createTestEntity({String id = 'log-new'}) {
  return IncidentLogEntity(
    id: id,
    warehouseId: 'wh-1',
    warehouseName: 'Gudang Utama',
    temperature: -15.0,
    threshold: -18.0,
    severity: 'warning',
    eventType: 'violation',
    affectedUmkmIds: const ['umkm-1', 'umkm-2'],
    notificationsSent: const ['notif-1'],
    notificationsFailed: const [],
    timestamp: _testTimestamp,
    resolvedAt: null,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late FakeNotificationDataSource fakeDataSource;
  late FakeNetworkInfo fakeNetworkInfo;
  late NotificationRepositoryImpl repository;

  setUp(() {
    fakeDataSource = FakeNotificationDataSource();
    fakeNetworkInfo = FakeNetworkInfo(connected: true);
    repository = NotificationRepositoryImpl(
      dataSource: fakeDataSource,
      networkInfo: fakeNetworkInfo,
    );
  });

  // ===========================================================================
  // getIncidentLogs
  // ===========================================================================
  group('getIncidentLogs', () {
    test('success → Right(list of entities)', () async {
      final model = _createTestModel();
      fakeDataSource.incidentLogsResult = [model];

      final result = await repository.getIncidentLogs();

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (list) {
          expect(list, hasLength(1));
          expect(list.first.id, equals('log-1'));
          expect(list.first.warehouseId, equals('wh-1'));
          expect(list.first.temperature, equals(-15.0));
        },
      );
    });

    test('failure (ServerException) → Left(ServerFailure)', () async {
      fakeDataSource.exceptionToThrow =
          const ServerException('Firestore error');

      final result = await repository.getIncidentLogs();

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
          expect(failure.message, contains('Firestore error'));
        },
        (_) => fail('Expected Left'),
      );
    });

    test('no internet → Left(NoInternetFailure)', () async {
      fakeNetworkInfo.connected = false;

      final result = await repository.getIncidentLogs();

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<NoInternetFailure>()),
        (_) => fail('Expected Left'),
      );
    });
  });

  // ===========================================================================
  // createIncidentLog
  // ===========================================================================
  group('createIncidentLog', () {
    test('success → Right(entity)', () async {
      final model = _createTestModel(id: 'log-created');
      fakeDataSource.createResult = model;

      final entity = _createTestEntity();
      final result = await repository.createIncidentLog(entity);

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (created) {
          expect(created.id, equals('log-created'));
          expect(created.warehouseId, equals('wh-1'));
        },
      );
    });

    test('failure → Left(ServerFailure)', () async {
      fakeDataSource.exceptionToThrow =
          const ServerException('Write failed');

      final entity = _createTestEntity();
      final result = await repository.createIncidentLog(entity);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('Expected Left'),
      );
    });
  });

  // ===========================================================================
  // resolveIncident
  // ===========================================================================
  group('resolveIncident', () {
    test('success → Right(unit)', () async {
      final result = await repository.resolveIncident('log-1');

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (value) => expect(value, equals(unit)),
      );
    });

    test('failure → Left(ServerFailure)', () async {
      fakeDataSource.exceptionToThrow =
          const ServerException('Resolve failed');

      final result = await repository.resolveIncident('log-1');

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('Expected Left'),
      );
    });
  });
}
