import 'package:bizbrain/core/errors/app_exception.dart';
import 'package:bizbrain/features/authentication/domain/entities/app_user.dart';
import 'package:bizbrain/features/authentication/domain/repositories/auth_repository.dart';

/// Placeholder repository used when the current build carries no Firebase
/// configuration.
///
/// It never reports a session as authenticated: every operation fails with a
/// [ConfigurationException] that points at the setup documentation. This keeps
/// the app honest - no mock users, no bypassed security checks.
class UnconfiguredAuthRepository implements AuthRepository {
  const UnconfiguredAuthRepository({required this.reason});

  final String reason;

  @override
  bool get isConfigured => false;

  @override
  String get unavailableReason => reason;

  @override
  Stream<AppUser?> authStateChanges() => const Stream<AppUser?>.empty();

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    throw ConfigurationException(reason);
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    throw ConfigurationException(reason);
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    throw ConfigurationException(reason);
  }

  @override
  Future<void> signOut() async {
    throw ConfigurationException(reason);
  }
}
