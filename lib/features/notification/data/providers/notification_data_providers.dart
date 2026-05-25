import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_info.dart';
import '../../../auth/data/providers/auth_data_providers.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/notification_datasource.dart';
import '../repositories/notification_repository_impl.dart';

/// Riverpod wiring for the notification data layer.
///
/// Reuses [firestoreProvider] from the auth feature so every feature shares
/// the same [FirebaseFirestore] singleton.

/// Provides the [NotificationDataSource] wired to Cloud Firestore.
final notificationDataSourceProvider = Provider<NotificationDataSource>((ref) {
  return NotificationDataSourceImpl(
    firestore: ref.watch(firestoreProvider),
  );
});

/// Provides the fully-wired [NotificationRepository].
final notificationRepositoryProvider =
    Provider<NotificationRepository>((ref) {
  return NotificationRepositoryImpl(
    dataSource: ref.watch(notificationDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
});
