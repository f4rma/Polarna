import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firebase_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/user_entity.dart';

/// Data-layer representation of a user, coupled to Firestore.
///
/// Extends [UserEntity] so it can be returned directly from the repository
/// without a manual `toEntity()` call — the domain layer still only depends
/// on the base entity interface.
class UserModel extends UserEntity {
  const UserModel({
    required super.uid,
    required super.email,
    required super.fullName,
    required super.phoneNumber,
    required super.role,
    required super.isEmailVerified,
    required super.isActive,
    required super.createdAt,
    super.fcmToken,
    super.lastLoginAt,
  });

  // ---------------------------------------------------------------------------
  // Factories
  // ---------------------------------------------------------------------------

  /// Builds a [UserModel] from a Firestore `users/{uid}` document.
  ///
  /// Throws [ServerException] when the document does not exist or when it is
  /// missing a required field (email / fullName / phoneNumber / role /
  /// createdAt).  Optional fields (`fcmToken`, `lastLoginAt`) are tolerated.
  factory UserModel.fromFirestore(DocumentSnapshot<Object?> doc) {
    final data = doc.data();
    if (data == null || data is! Map<String, dynamic>) {
      throw const ServerException('Profil pengguna tidak ditemukan');
    }
    try {
      return UserModel(
        uid: (data[FirebaseConstants.fieldUid] as String?) ?? doc.id,
        email: data[FirebaseConstants.fieldEmail] as String,
        fullName: data[FirebaseConstants.fieldFullName] as String,
        phoneNumber: data[FirebaseConstants.fieldPhoneNumber] as String,
        role: UserRole.fromString(data[FirebaseConstants.fieldRole] as String),
        isEmailVerified:
            (data[FirebaseConstants.fieldIsEmailVerified] as bool?) ?? false,
        isActive: (data[FirebaseConstants.fieldIsActive] as bool?) ?? true,
        fcmToken: data[FirebaseConstants.fieldFcmToken] as String?,
        createdAt:
            (data[FirebaseConstants.fieldCreatedAt] as Timestamp).toDate(),
        lastLoginAt:
            (data[FirebaseConstants.fieldLastLoginAt] as Timestamp?)?.toDate(),
      );
    } on TypeError catch (e) {
      throw ServerException('Skema dokumen pengguna tidak valid: $e');
    } on ArgumentError catch (e) {
      throw ServerException('Data pengguna tidak valid: ${e.message}');
    }
  }

  /// Copy-constructor from a plain domain [UserEntity].
  factory UserModel.fromEntity(UserEntity entity) {
    return UserModel(
      uid: entity.uid,
      email: entity.email,
      fullName: entity.fullName,
      phoneNumber: entity.phoneNumber,
      role: entity.role,
      isEmailVerified: entity.isEmailVerified,
      isActive: entity.isActive,
      fcmToken: entity.fcmToken,
      createdAt: entity.createdAt,
      lastLoginAt: entity.lastLoginAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  /// Serialises this model into a Firestore-ready map.
  ///
  /// Used for **initial document creation** only; partial updates should use
  /// a dedicated method with explicit field names so we never accidentally
  /// overwrite unrelated fields.
  Map<String, dynamic> toFirestore() {
    return {
      FirebaseConstants.fieldUid: uid,
      FirebaseConstants.fieldEmail: email,
      FirebaseConstants.fieldFullName: fullName,
      FirebaseConstants.fieldPhoneNumber: phoneNumber,
      FirebaseConstants.fieldRole: role.toStorageString(),
      FirebaseConstants.fieldIsEmailVerified: isEmailVerified,
      FirebaseConstants.fieldIsActive: isActive,
      FirebaseConstants.fieldFcmToken: fcmToken,
      FirebaseConstants.fieldCreatedAt: Timestamp.fromDate(createdAt),
      FirebaseConstants.fieldLastLoginAt:
          lastLoginAt == null ? null : Timestamp.fromDate(lastLoginAt!),
    };
  }

  /// Returns a copy with a subset of fields replaced.
  UserModel copyWith({
    bool? isEmailVerified,
    String? fcmToken,
    DateTime? lastLoginAt,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      fullName: fullName,
      phoneNumber: phoneNumber,
      role: role,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isActive: isActive,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}
