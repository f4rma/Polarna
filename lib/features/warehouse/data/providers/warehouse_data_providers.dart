import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_info.dart';
import '../../../auth/data/providers/auth_data_providers.dart';
import '../../domain/repositories/warehouse_repository.dart';
import '../datasources/warehouse_remote_datasource.dart';
import '../repositories/warehouse_repository_impl.dart';

/// Riverpod wiring for the warehouse data layer.
///
/// Reuses [firestoreProvider] from the auth feature so every feature shares
/// the same [FirebaseFirestore] singleton.  Presentation-level providers
/// (e.g. `WarehouseNotifier`) will be added in task 5.6 on top of
/// [warehouseRepositoryProvider].

/// Provides the [WarehouseRemoteDataSource] wired to Cloud Firestore.
final warehouseRemoteDataSourceProvider =
    Provider<WarehouseRemoteDataSource>((ref) {
  return WarehouseRemoteDataSourceImpl(
    firestore: ref.watch(firestoreProvider),
  );
});

/// Provides the fully-wired [WarehouseRepository].
final warehouseRepositoryProvider = Provider<WarehouseRepository>((ref) {
  return WarehouseRepositoryImpl(
    remote: ref.watch(warehouseRemoteDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
});
