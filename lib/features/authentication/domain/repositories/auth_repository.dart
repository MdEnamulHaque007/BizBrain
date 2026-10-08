import 'package:bizbrain/features/authentication/domain/entities/app_user.dart';

/// Contract for authentication operations.
///
/// The only production implementation is backed by Firebase Auth
/// (`FirebaseAuthRepository`). When the build carries no Firebase
/// configuration the app uses `UnconfiguredAuthRepository`, which refuses
/// every operation instead of faking a session - authentication is never
/// bypassed client-side.
abstract interface class AuthRepository {
  /// Whether a real authentication backend is available for this build.
  bool get isConfigured;

  /// Explanation shown to the user when [isConfigured] is `false`.
  String get unavailableReason;

  /// Emits the current user on sign-in / sign-out, `null` when signed out.
  Stream<AppUser?> authStateChanges();

  Future<AppUser> signIn({required String email, required String password});

  Future<AppUser> signUp({
    required String email,
    required String password,
    String? displayName,
  });

  /// Sends a password reset email; completes normally when the email was sent.
  Future<void> sendPasswordReset({required String email});

  Future<void> signOut();
}
