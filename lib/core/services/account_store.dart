import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/providers/auth_data_providers.dart';

/// A saved account entry for quick switching.
class SavedAccount {
  final String email;
  final String password;
  final String fullName;
  final String role;

  const SavedAccount({
    required this.email,
    required this.password,
    required this.fullName,
    required this.role,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
        'fullName': fullName,
        'role': role,
      };

  factory SavedAccount.fromJson(Map<String, dynamic> json) => SavedAccount(
        email: json['email'] as String,
        password: json['password'] as String,
        fullName: json['fullName'] as String,
        role: json['role'] as String,
      );
}

/// Service that persists account credentials in SharedPreferences
/// for quick account switching during demos.
class AccountStore {
  static const _key = 'saved_accounts';

  final SharedPreferences _prefs;

  AccountStore(this._prefs);

  /// Saves an account. If an account with the same email already exists,
  /// it will be updated with the new credentials.
  Future<void> saveAccount({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    final accounts = getSavedAccounts();
    final index = accounts.indexWhere((a) => a.email == email);
    final account = SavedAccount(
      email: email,
      password: password,
      fullName: fullName,
      role: role,
    );

    if (index >= 0) {
      accounts[index] = account;
    } else {
      accounts.add(account);
    }

    await _persist(accounts);
  }

  /// Returns all saved accounts.
  List<SavedAccount> getSavedAccounts() {
    final raw = _prefs.getStringList(_key);
    if (raw == null) return [];
    return raw
        .map((s) => SavedAccount.fromJson(
            json.decode(s) as Map<String, dynamic>))
        .toList();
  }

  /// Removes a saved account by email.
  Future<void> removeAccount(String email) async {
    final accounts = getSavedAccounts();
    accounts.removeWhere((a) => a.email == email);
    await _persist(accounts);
  }

  Future<void> _persist(List<SavedAccount> accounts) async {
    final encoded = accounts.map((a) => json.encode(a.toJson())).toList();
    await _prefs.setStringList(_key, encoded);
  }
}

/// Provider for [AccountStore], depends on SharedPreferences.
final accountStoreProvider = FutureProvider<AccountStore>((ref) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return AccountStore(prefs);
});
