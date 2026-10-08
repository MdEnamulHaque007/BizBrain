import 'package:bizbrain/features/authentication/domain/entities/app_user.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

/// Serializable representation of [AppUser].
class AppUserModel extends AppUser {
  const AppUserModel({
    required super.uid,
    required super.email,
    super.displayName,
    super.emailVerified,
  });

  factory AppUserModel.fromFirebaseUser(fb.User user) => AppUserModel(
    uid: user.uid,
    email: user.email ?? '',
    displayName: user.displayName,
    emailVerified: user.emailVerified,
  );

  /// Builds a user from a decoded JSON / Firestore map.
  ///
  /// Throws [FormatException] when the payload is structurally invalid, so
  /// corrupted data fails loudly instead of producing a half-working session.
  factory AppUserModel.fromMap(Map<String, dynamic> map) {
    final uid = map['uid'];
    final email = map['email'];
    if (uid is! String || uid.isEmpty) {
      throw const FormatException('AppUser payload is missing "uid".');
    }
    if (email is! String || email.isEmpty) {
      throw const FormatException('AppUser payload is missing "email".');
    }
    return AppUserModel(
      uid: uid,
      email: email,
      displayName: map['displayName'] is String
          ? map['displayName'] as String
          : null,
      emailVerified: map['emailVerified'] is bool
          ? map['emailVerified'] as bool
          : false,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'uid': uid,
    'email': email,
    'displayName': displayName,
    'emailVerified': emailVerified,
  };
}
