import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_info.dart';
import '../../../auth/data/providers/auth_data_providers.dart';
import '../../domain/repositories/telemetry_repository.dart';
import '../datasources/telemetry_remote_datasource.dart';
import '../repositories/telemetry_repository_impl.dart';

/// Riverpod wiring for the telemetry data layer.
///
/// Reuses [firestoreProvider] from the auth feature so every feature shares
/// the same [FirebaseFirestore] singleton.

/// Provides the [TelemetryRemoteDataSource] wired to Cloud Firestore.
final telemetryRemoteDataSourceProvider =
    Provider<TelemetryRemoteDataSource>((ref) {
  return TelemetryRemoteDataSourceImpl(
    firestore: ref.watch(firestoreProvider),
  );
});

/// Provides the fully-wired [TelemetryRepository].
final telemetryRepositoryProvider = Provider<TelemetryRepository>((ref) {
  return TelemetryRepositoryImpl(
    remote: ref.watch(telemetryRemoteDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
});
