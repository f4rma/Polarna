import 'package:shared_preferences/shared_preferences.dart';

/// Persists per-email account-lockout state across app restarts.
///
/// Keys are namespaced so account-lock state never collides with other
/// preferences:
///
///   - `auth_fail_count:{email}`  → `int`  consecutive failed attempts
///   - `auth_lock_until:{email}`  → `int`  millisecondsSinceEpoch (UTC)
///
/// Emails are normalised (trim + lowercase) before keying so that
/// `Alice@Mail.com` and `alice@mail.com` share the same bucket.
abstract class AuthLocalDataSource {
  Future<int> getFailedAttempts(String email);

  /// Increments the stored counter and returns the **new** value.
  Future<int> incrementFailedAttempts(String email);

  Future<void> resetFailedAttempts(String email);

  Future<DateTime?> getLockUntil(String email);

  Future<void> setLockUntil(String email, DateTime lockUntil);
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  static const String _attemptsPrefix = 'auth_fail_count:';
  static const String _lockUntilPrefix = 'auth_lock_until:';

  final SharedPreferences _prefs;

  const AuthLocalDataSourceImpl(this._prefs);

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _normalize(String email) => email.trim().toLowerCase();

  String _attemptsKey(String email) => '$_attemptsPrefix${_normalize(email)}';

  String _lockUntilKey(String email) => '$_lockUntilPrefix${_normalize(email)}';

  // ---------------------------------------------------------------------------
  // API
  // ---------------------------------------------------------------------------

  @override
  Future<int> getFailedAttempts(String email) async {
    return _prefs.getInt(_attemptsKey(email)) ?? 0;
  }

  @override
  Future<int> incrementFailedAttempts(String email) async {
    final newCount = (await getFailedAttempts(email)) + 1;
    await _prefs.setInt(_attemptsKey(email), newCount);
    return newCount;
  }

  @override
  Future<void> resetFailedAttempts(String email) async {
    await _prefs.remove(_attemptsKey(email));
    await _prefs.remove(_lockUntilKey(email));
  }

  @override
  Future<DateTime?> getLockUntil(String email) async {
    final millis = _prefs.getInt(_lockUntilKey(email));
    if (millis == null) return null;
    final lockUntil =
        DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    // Per spec: return null if the lock window has already elapsed.
    if (!DateTime.now().toUtc().isBefore(lockUntil)) {
      return null;
    }
    return lockUntil;
  }

  @override
  Future<void> setLockUntil(String email, DateTime lockUntil) async {
    await _prefs.setInt(
      _lockUntilKey(email),
      lockUntil.toUtc().millisecondsSinceEpoch,
    );
  }
}
