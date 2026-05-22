import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/network_info.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';
import '../repositories/auth_repository_impl.dart';

/// Riverpod wiring for the auth data layer.
///
/// Exposes the SDK singletons (Firebase Auth, Firestore, SharedPreferences)
/// and the data-source / repository instances that depend on them.
/// Presentation-level providers (e.g. `AuthNotifier`) will be added in
/// task 2.6 on top of [authRepositoryProvider].

/// Provides the singleton [FirebaseAuth] instance used by the auth data layer.
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

/// Provides the singleton [FirebaseFirestore] instance used by the auth data
/// layer (and, later, other features).
final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

/// Asynchronously resolves the [SharedPreferences] singleton.
///
/// `SharedPreferences.getInstance()` caches the instance after its first
/// call, so repeated awaits are cheap.
final sharedPreferencesProvider = FutureProvider<SharedPreferences>(
  (ref) => SharedPreferences.getInstance(),
);

/// Provides the [AuthRemoteDataSource] wired to Firebase Auth and Firestore.
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSourceImpl(
    firebaseAuth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
  );
});

/// Provides the [AuthLocalDataSource] backed by [SharedPreferences].
///
/// Exposed as a [FutureProvider] because [SharedPreferences] initialises
/// asynchronously.  Downstream providers resolve it via
/// `ref.watch(authLocalDataSourceProvider.future)`.
final authLocalDataSourceProvider = FutureProvider<AuthLocalDataSource>(
  (ref) async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    return AuthLocalDataSourceImpl(prefs);
  },
);

/// Provides the fully-wired [AuthRepository].
///
/// Async because it depends on [authLocalDataSourceProvider], which in turn
/// depends on the async [SharedPreferences] singleton.
final authRepositoryProvider = FutureProvider<AuthRepository>((ref) async {
  final remote = ref.watch(authRemoteDataSourceProvider);
  final local = await ref.watch(authLocalDataSourceProvider.future);
  final networkInfo = ref.watch(networkInfoProvider);
  return AuthRepositoryImpl(
    remote: remote,
    local: local,
    networkInfo: networkInfo,
  );
});
