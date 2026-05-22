import 'package:equatable/equatable.dart';

/// Roles supported by the ColdShare platform.
///
/// - [umkm]  — tenant (Usaha Mikro, Kecil, Menengah) that rents cold storage.
/// - [mitra] — warehouse owner that rents out cold storage capacity.
/// - [admin] — platform administrator.
enum UserRole {
  umkm,
  mitra,
  admin;

  /// Canonical storage representation (used by Firestore).
  String toStorageString() => name;

  /// Parses a stored string (case-insensitive, trimmed) into a [UserRole].
  ///
  /// Throws [ArgumentError] on unknown values so callers are forced to
  /// handle data-corruption explicitly.
  static UserRole fromString(String value) {
    switch (value.trim().toLowerCase()) {
      case 'umkm':
        return UserRole.umkm;
      case 'mitra':
        return UserRole.mitra;
      case 'admin':
        return UserRole.admin;
      default:
        throw ArgumentError.value(value, 'value', 'Unknown UserRole');
    }
  }
}

/// Immutable identity + profile object returned by the auth layer.
///
/// Mirrors the `users/{userId}` Firestore document schema defined in
/// `design.md §Data Models`. The router and guards under
/// `lib/core/router/app_router.dart` only depend on [uid] and [role], so the
/// extra profile fields are additive and safe for existing consumers.
class UserEntity extends Equatable {
  final String uid;
  final String email;
  final String fullName;
  final String phoneNumber;
  final UserRole role;
  final bool isEmailVerified;
  final bool isActive;
  final String? fcmToken;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  const UserEntity({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.phoneNumber,
    required this.role,
    required this.isEmailVerified,
    required this.isActive,
    required this.createdAt,
    this.fcmToken,
    this.lastLoginAt,
  });

  @override
  List<Object?> get props => [
        uid,
        email,
        fullName,
        phoneNumber,
        role,
        isEmailVerified,
        isActive,
        fcmToken,
        createdAt,
        lastLoginAt,
      ];
}
