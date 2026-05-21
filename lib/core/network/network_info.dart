import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Abstract interface for checking network connectivity.
abstract class NetworkInfo {
  /// Returns `true` if the device currently has an active internet connection.
  Future<bool> get isConnected;

  /// Stream that emits connectivity changes.
  Stream<bool> get onConnectivityChanged;
}

/// Implementation of [NetworkInfo] using the `connectivity_plus` package.
class NetworkInfoImpl implements NetworkInfo {
  final Connectivity _connectivity;

  const NetworkInfoImpl(this._connectivity);

  @override
  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    return _isConnectedFromResults(results);
  }

  @override
  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged
        .map((results) => _isConnectedFromResults(results));
  }

  bool _isConnectedFromResults(List<ConnectivityResult> results) {
    return results.isNotEmpty &&
        results.any((r) =>
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.wifi ||
            r == ConnectivityResult.ethernet ||
            r == ConnectivityResult.vpn);
  }
}

// ---------------------------------------------------------------------------
// Riverpod Providers
// ---------------------------------------------------------------------------

/// Provider for the [Connectivity] instance.
final connectivityProvider = Provider<Connectivity>((ref) {
  return Connectivity();
});

/// Provider for [NetworkInfo].
final networkInfoProvider = Provider<NetworkInfo>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return NetworkInfoImpl(connectivity);
});

/// StreamProvider that emits the current connectivity status as a boolean.
/// `true` = connected, `false` = disconnected.
final isConnectedProvider = StreamProvider<bool>((ref) {
  final networkInfo = ref.watch(networkInfoProvider);
  return networkInfo.onConnectivityChanged;
});
