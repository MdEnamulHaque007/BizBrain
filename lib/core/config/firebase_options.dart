import 'package:firebase_core/firebase_core.dart';

/// Resolves the Firebase client configuration for the current build.
///
/// Values are provided as `--dart-define` entries (typically via
/// `--dart-define-from-file=config/firebase.<environment>.json`, see
/// `config/*.template.json` and `docs/firebase-setup.md`).
///
/// Firebase *client* configuration (apiKey, appId, projectId, ...) is a public
/// identifier of a Firebase project, not a secret: it is shipped inside every
/// compiled client and is protected by Firebase Security Rules and App Check,
/// never by secrecy. No service-account keys or server credentials belong
/// here.
class AppFirebaseOptions {
  const AppFirebaseOptions._();

  static const String _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String _authDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
  );
  static const String _projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const String _storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );
  static const String _messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const String _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const String _measurementId = String.fromEnvironment(
    'FIREBASE_MEASUREMENT_ID',
  );

  /// Names of every define that must be present for Firebase to start.
  static const List<String> requiredKeys = <String>[
    'FIREBASE_API_KEY',
    'FIREBASE_AUTH_DOMAIN',
    'FIREBASE_PROJECT_ID',
    'FIREBASE_MESSAGING_SENDER_ID',
    'FIREBASE_APP_ID',
  ];

  /// Returns the required define names that are missing or empty in this build.
  static List<String> get missingKeys {
    final values = <String, String>{
      'FIREBASE_API_KEY': _apiKey,
      'FIREBASE_AUTH_DOMAIN': _authDomain,
      'FIREBASE_PROJECT_ID': _projectId,
      'FIREBASE_MESSAGING_SENDER_ID': _messagingSenderId,
      'FIREBASE_APP_ID': _appId,
    };
    return requiredKeys
        .where((key) => values[key]!.trim().isEmpty)
        .toList(growable: false);
  }

  static bool get isConfigured => missingKeys.isEmpty;

  /// Returns usable options, or `null` when the build carries no Firebase
  /// configuration. Callers must handle `null` gracefully instead of
  /// inventing placeholder values.
  static FirebaseOptions? resolve() {
    if (!isConfigured) return null;
    return FirebaseOptions(
      apiKey: _apiKey,
      authDomain: _authDomain,
      projectId: _projectId,
      storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
      messagingSenderId: _messagingSenderId,
      appId: _appId,
      measurementId: _measurementId.isEmpty ? null : _measurementId,
    );
  }
}
