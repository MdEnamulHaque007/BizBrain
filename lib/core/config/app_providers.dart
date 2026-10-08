import 'package:bizbrain/core/config/app_config.dart';
import 'package:bizbrain/core/config/firebase_initialization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Application-wide configuration. Resolved once per build.
final Provider<AppConfig> appConfigProvider = Provider<AppConfig>((Ref ref) {
  return AppConfig.fromEnvironment();
});

/// Result of the Firebase bootstrap performed in `main()`.
///
/// The default value is deliberately the *safest* state: if the bootstrap
/// layer ever fails to supply its override, the app behaves as an
/// unconfigured build instead of assuming Firebase is available.
final Provider<FirebaseInitialization> firebaseInitializationProvider =
    Provider<FirebaseInitialization>((Ref ref) {
      return const FirebaseInitialization.notConfigured(
        reason:
            'Firebase initialization was not supplied by the bootstrap layer.',
      );
    });
