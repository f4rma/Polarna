import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/constants/firebase_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/user_entity.dart';
import '../models/user_model.dart';

/// Remote auth operations backed by Firebase Auth + Cloud Firestore.
///
/// All methods throw [AppException] subclasses on failure; the repository
/// layer is responsible for converting those into [Failure] objects.
abstract class AuthRemoteDataSource {
  /// Emits the current authenticated [UserEntity] (or `null` when signed out)
  /// whenever the Firebase Auth state changes.  Each emission triggers a
  /// Firestore read to hydrate the full profile.
  Stream<UserEntity?> authStateChanges();

  Future<UserModel> signIn({
    required String email,
    required String password,
  });

  Future<UserModel> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required UserRole role,
  });

  Future<void> signOut();

  Future<void> resetPassword({required String email});

  Future<UserModel?> getCurrentUser();

  Future<void> sendEmailVerification();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  const AuthRemoteDataSourceImpl({
    required FirebaseAuth firebaseAuth,
    required FirebaseFirestore firestore,
  })  : _firebaseAuth = firebaseAuth,
        _firestore = firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(FirebaseConstants.usersCollection);

  // ---------------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------------

  @override
  Stream<UserEntity?> authStateChanges() {
    return _firebaseAuth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      return _fetchUserDoc(user.uid, isEmailVerified: user.emailVerified);
    });
  }

  // ---------------------------------------------------------------------------
  // Sign in
  // ---------------------------------------------------------------------------

  @override
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    final UserCredential credential;
    try {
      credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    }

    final user = credential.user;
    if (user == null) {
      throw const ServerException('Firebase Auth returned a null user');
    }
    if (!user.emailVerified) {
      throw const EmailNotVerifiedException();
    }

    final model = await _fetchUserDoc(user.uid, isEmailVerified: true);
    await _touchLastLogin(user.uid);
    return model.copyWith(lastLoginAt: DateTime.now().toUtc());
  }

  // ---------------------------------------------------------------------------
  // Sign up
  // ---------------------------------------------------------------------------

  @override
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required UserRole role,
  }) async {
    final UserCredential credential;
    try {
      credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    }

    final user = credential.user;
    if (user == null) {
      throw const ServerException('Firebase Auth returned a null user');
    }

    final now = DateTime.now().toUtc();
    final model = UserModel(
      uid: user.uid,
      email: email,
      fullName: fullName,
      phoneNumber: phoneNumber,
      role: role,
      isEmailVerified: false,
      isActive: true,
      createdAt: now,
    );

    try {
      await _users.doc(user.uid).set(model.toFirestore());
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } on FirebaseException catch (e) {
      throw ServerException('Firestore error: ${e.message ?? e.code}');
    }
    return model;
  }

  // ---------------------------------------------------------------------------
  // Sign out / reset / current / verification
  // ---------------------------------------------------------------------------

  @override
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    }
  }

  @override
  Future<void> resetPassword({required String email}) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    return _fetchUserDoc(user.uid, isEmailVerified: user.emailVerified);
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const ServerException('Tidak ada pengguna aktif');
    }
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Reads the `users/{uid}` document and hydrates it as a [UserModel].
  ///
  /// Falls back to the Firebase Auth [User.emailVerified] flag when provided,
  /// because Firestore's stored value lags behind the Auth truth source.
  Future<UserModel> _fetchUserDoc(
    String uid, {
    bool? isEmailVerified,
  }) async {
    final DocumentSnapshot<Map<String, dynamic>> snap;
    try {
      snap = await _users.doc(uid).get();
    } on FirebaseException catch (e) {
      throw ServerException('Firestore error: ${e.message ?? e.code}');
    }

    if (!snap.exists) {
      throw const ServerException('Profil pengguna tidak ditemukan');
    }

    final model = UserModel.fromFirestore(snap);
    if (isEmailVerified != null &&
        isEmailVerified != model.isEmailVerified) {
      // Sync verification status ke Firestore
      await _users.doc(uid).update({
        FirebaseConstants.fieldIsEmailVerified: isEmailVerified,
      });
      return model.copyWith(isEmailVerified: isEmailVerified);
    }
    return model;
  }

  Future<void> _touchLastLogin(String uid) async {
    try {
      await _users.doc(uid).update({
        FirebaseConstants.fieldLastLoginAt: FieldValue.serverTimestamp(),
      });
    } on FirebaseException {
      // Best-effort; do not surface lastLoginAt write errors to the caller.
    }
  }

  /// Maps a [FirebaseAuthException] to an [AppException] subclass.
  AppException _mapFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return const EmailAlreadyInUseException();
      case 'invalid-email':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-credential':
        return const InvalidCredentialsException();
      case 'weak-password':
        // Weak passwords should have been caught by client-side validation;
        // treat as a server-reported issue when they slip through.
        return ServerException('Kata sandi terlalu lemah: ${e.message ?? ''}');
      case 'user-disabled':
        // Neutral response: do not leak account state (Req 1.5 — error
        // messages for invalid credentials must be identical).
        return const InvalidCredentialsException();
      case 'too-many-requests':
        return const AccountLockedException();
      case 'expired-action-code':
        return const ResetLinkExpiredException();
      case 'invalid-action-code':
        return const ResetLinkExpiredException();
      case 'network-request-failed':
        return const NoInternetException();
      default:
        return ServerException(
          'FirebaseAuthException(${e.code}): ${e.message ?? 'unknown error'}',
        );
    }
  }
}
