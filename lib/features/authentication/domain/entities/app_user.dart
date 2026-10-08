/// Authenticated user as seen by the application.
///
/// This is intentionally a small, provider-agnostic value object: nothing
/// from `firebase_auth` may leak into the domain or presentation layers.
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.emailVerified = false,
  });

  /// Stable identifier used as the Firestore `userId` / document id.
  final String uid;

  /// Primary email address (lower-cased by the provider).
  final String email;

  final String? displayName;

  final bool emailVerified;

  /// Best available short name for greetings; never empty.
  String get friendlyName {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final at = email.indexOf('@');
    return at > 0 ? email.substring(0, at) : email;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppUser && other.uid == uid && other.email == email);

  @override
  int get hashCode => Object.hash(uid, email);

  @override
  String toString() => 'AppUser(uid: $uid, verified: $emailVerified)';
}
