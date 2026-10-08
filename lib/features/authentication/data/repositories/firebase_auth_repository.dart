import 'package:bizbrain/core/errors/app_exception.dart';
import 'package:bizbrain/core/errors/error_mapper.dart';
import 'package:bizbrain/core/logging/app_logger.dart';
import 'package:bizbrain/core/security/input_normalizer.dart';
import 'package:bizbrain/features/authentication/data/models/app_user_model.dart';
import 'package:bizbrain/features/authentication/domain/entities/app_user.dart';
import 'package:bizbrain/features/authentication/domain/repositories/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Firebase Auth backed implementation of [AuthRepository].
///
/// Provider error codes are mapped to user-facing messages here so the
/// presentation layer never deals with Firebase specifics.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  final FirebaseAuth _auth;

  @override
  bool get isConfigured => true;

  @override
  String get unavailableReason => '';

  @override
  Stream<AppUser?> authStateChanges() {
    return _auth.authStateChanges().map(
      (user) => user == null ? null : AppUserModel.fromFirebaseUser(user),
    );
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: InputNormalizer.email(email),
        password: password,
      );
      return _requireUser(credential.user, operation: 'sign-in');
    } on FirebaseAuthException catch (error) {
      AppLogger.warning('Sign-in rejected', error: error.code);
      throw AuthException(ErrorMapper.messageFor(error), code: error.code);
    } on AppException {
      rethrow;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Unexpected sign-in failure',
        error: error,
        stackTrace: stackTrace,
      );
      throw AuthException(ErrorMapper.messageFor(error));
    }
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: InputNormalizer.email(email),
        password: password,
      );
      final user = _requireUser(credential.user, operation: 'registration');

      final trimmedName = InputNormalizer.displayName(displayName ?? '');
      if (trimmedName.isNotEmpty) {
        try {
          await credential.user!.updateDisplayName(trimmedName);
        } catch (error, stackTrace) {
          // The account exists; a failed profile update must not block sign-up.
          AppLogger.warning(
            'Could not store display name',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
      return user;
    } on FirebaseAuthException catch (error) {
      AppLogger.warning('Registration rejected', error: error.code);
      throw AuthException(ErrorMapper.messageFor(error), code: error.code);
    } on AppException {
      rethrow;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Unexpected registration failure',
        error: error,
        stackTrace: stackTrace,
      );
      throw AuthException(ErrorMapper.messageFor(error));
    }
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: InputNormalizer.email(email));
    } on FirebaseAuthException catch (error) {
      AppLogger.warning('Password reset rejected', error: error.code);
      throw AuthException(ErrorMapper.messageFor(error), code: error.code);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Unexpected password reset failure',
        error: error,
        stackTrace: stackTrace,
      );
      throw AuthException(ErrorMapper.messageFor(error));
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (error, stackTrace) {
      AppLogger.error('Sign-out failed', error: error, stackTrace: stackTrace);
      throw AuthException(ErrorMapper.messageFor(error));
    }
  }

  AppUser _requireUser(User? user, {required String operation}) {
    if (user == null) {
      AppLogger.error('Firebase returned no user after $operation');
      throw const AuthException(
        'The account could not be loaded. Please try again.',
      );
    }
    return AppUserModel.fromFirebaseUser(user);
  }
}
