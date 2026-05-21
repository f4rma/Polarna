import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lightweight in-memory cache with TTL (time-to-live) support.
///
/// Stores data as `Map<String, dynamic>` entries with timestamps.
/// Entries expire after [maxAge] (default: 1 hour).
/// Data survives only during the active session — no persistence.
///
/// Satisfies Requirement 11.5: retain last-loaded data in memory
/// during the active session (max 1 hour).
class MemoryCache {
  /// Maximum age before an entry is considered expired.
  final Duration maxAge;

  final Map<String, _CacheEntry<dynamic>> _store = {};

  MemoryCache({this.maxAge = const Duration(hours: 1)});

  /// Returns the cached value for [key], or `null` if not found or expired.
  T? get<T>(String key) {
    final entry = _store[key];
    if (entry == null) return null;
    if (isExpired(key)) {
      _store.remove(key);
      return null;
    }
    return entry.value as T;
  }

  /// Stores [value] under [key] with the current timestamp.
  void set<T>(String key, T value) {
    _store[key] = _CacheEntry<T>(value: value, storedAt: DateTime.now());
  }

  /// Returns `true` if the entry for [key] is older than [maxAge].
  bool isExpired(String key) {
    final entry = _store[key];
    if (entry == null) return true;
    return DateTime.now().difference(entry.storedAt) > maxAge;
  }

  /// Clears all cached entries.
  void clear() {
    _store.clear();
  }

  /// Returns `true` if [key] exists and is not expired.
  bool has(String key) {
    if (!_store.containsKey(key)) return false;
    if (isExpired(key)) {
      _store.remove(key);
      return false;
    }
    return true;
  }
}

class _CacheEntry<T> {
  final T value;
  final DateTime storedAt;

  const _CacheEntry({required this.value, required this.storedAt});
}

// ---------------------------------------------------------------------------
// Riverpod Provider
// ---------------------------------------------------------------------------

/// Global in-memory cache provider.
///
/// Singleton for the app session — cleared only on app restart or
/// explicit [MemoryCache.clear] call.
final memoryCacheProvider = Provider<MemoryCache>((ref) {
  return MemoryCache();
});
