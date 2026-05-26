import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_info.dart';
import '../../../auth/data/providers/auth_data_providers.dart';
import '../../domain/repositories/admin_repository.dart';
import '../datasources/admin_remote_datasource.dart';
import '../repositories/admin_repository_impl.dart';

/// Riverpod wiring for the admin data layer.
///
/// Reuses [firestoreProvider] from the auth feature so every feature shares
/// the same [FirebaseFirestore] singleton.

/// Provides the [AdminRemoteDataSource] wired to Cloud Firestore.
final adminRemoteDataSourceProvider =
    Provider<AdminRemoteDataSource>((ref) {
  return AdminRemoteDataSourceImpl(
    firestore: ref.watch(firestoreProvider),
  );
});

/// Provides the fully-wired [AdminRepository].
final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepositoryImpl(
    remote: ref.watch(adminRemoteDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
});
