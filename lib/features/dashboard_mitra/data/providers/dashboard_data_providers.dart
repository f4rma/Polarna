import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_info.dart';
import '../../../auth/data/providers/auth_data_providers.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_remote_datasource.dart';
import '../repositories/dashboard_repository_impl.dart';

/// Riverpod wiring for the dashboard_mitra data layer.
///
/// Reuses [firestoreProvider] from the auth feature so every feature shares
/// the same [FirebaseFirestore] singleton.

/// Provides the [DashboardRemoteDataSource] wired to Cloud Firestore.
final dashboardRemoteDataSourceProvider =
    Provider<DashboardRemoteDataSource>((ref) {
  return DashboardRemoteDataSourceImpl(
    firestore: ref.watch(firestoreProvider),
  );
});

/// Provides the fully-wired [DashboardRepository].
final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepositoryImpl(
    remote: ref.watch(dashboardRemoteDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
});
