import 'dart:async';

import 'package:bizbrain/core/errors/app_exception.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Centralised translation from raw errors to messages that are safe and
/// useful to display. Presentation code must never show raw exception text,
/// stack traces, or provider payloads to the user.
abstract final class ErrorMapper {
  static String messageFor(Object error) {
    if (error is AppException) return error.message;
    if (error is FirebaseAuthException) return _fromAuthCode(error.code);
    if (error is FirebaseException) return _fromFirestoreCode(error.code);
    if (error is FormatException) {
      return 'Received data was in an unexpected format. Please try again.';
    }
    if (error is TimeoutException) {
      return 'The request took too long. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  /// Whether the error represents a Firestore permission denial. Used to show
  /// the "unauthorized" state instead of a generic error.
  static bool isPermissionDenied(Object error) {
    if (error is PermissionDeniedException) return true;
    if (error is FirebaseException) return error.code == 'permission-denied';
    return false;
  }

  /// Whether the error means the user must authenticate again.
  static bool isUnauthenticated(Object error) {
    if (error is AuthException) {
      return error.code == 'requires-recent-login' ||
          error.code == 'user-token-expired';
    }
    if (error is FirebaseException) return error.code == 'unauthenticated';
    return false;
  }

  static String _fromAuthCode(String code) {
    switch (code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'The email or password you entered is incorrect.';
      case 'invalid-email':
        return 'That email address does not look valid.';
      case 'email-already-in-use':
        return 'An account already exists for that email address.';
      case 'weak-password':
        return 'Please choose a stronger password.';
      case 'user-disabled':
        return 'This account has been disabled. Contact your administrator.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Unable to reach the server. Check your connection and try again.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled for this Firebase project. '
            'See docs/firebase-setup.md.';
      case 'requires-recent-login':
        return 'For security, please sign in again before repeating this action.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  static String _fromFirestoreCode(String code) {
    switch (code) {
      case 'permission-denied':
        return 'You do not have permission to access this data.';
      case 'unauthenticated':
        return 'Your session has expired. Please sign in again.';
      case 'unavailable':
        return 'The service is currently unavailable. Please try again later.';
      case 'failed-precondition':
        return 'A required configuration is missing. See docs/firebase-setup.md.';
      case 'not-found':
        return 'The requested item no longer exists.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
