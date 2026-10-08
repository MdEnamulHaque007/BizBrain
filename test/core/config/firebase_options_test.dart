import 'package:bizbrain/app/bootstrap/app_bootstrap.dart';
import 'package:bizbrain/core/config/firebase_initialization.dart';
import 'package:bizbrain/core/config/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Configuration parsing and initialization behaviour.
///
/// Two run modes are supported and must both stay green:
///
/// * `flutter test` - no `FIREBASE_*` defines: the build is unconfigured, the
///   SDK must never start, and the configured tests are skipped.
/// * `flutter test --dart-define-from-file=config/firebase.development.json`
///   - the supplied Web configuration is compiled in: parsing must yield the
///   exact values and the bootstrap must hand them to the SDK starter.
void main() {
  final bool configured = AppFirebaseOptions.isConfigured;
  final Object skipUnconfigured = configured
      ? 'requires a build without FIREBASE_* defines'
      : false;
  final Object skipConfigured = configured
      ? false
      : 'run with --dart-define-from-file=config/firebase.development.json';

  group('AppFirebaseOptions', () {
    test('declares exactly the five required keys', () {
      expect(AppFirebaseOptions.requiredKeys, <String>[
        'FIREBASE_API_KEY',
        'FIREBASE_AUTH_DOMAIN',
        'FIREBASE_PROJECT_ID',
        'FIREBASE_MESSAGING_SENDER_ID',
        'FIREBASE_APP_ID',
      ]);
    });

    test(
      'configuration state, resolution and missing keys stay consistent',
      () {
        expect(
          AppFirebaseOptions.isConfigured,
          AppFirebaseOptions.missingKeys.isEmpty,
        );
        expect(
          AppFirebaseOptions.resolve() == null,
          isNot(AppFirebaseOptions.isConfigured),
          reason:
              'resolve() must return null exactly when the build is '
              'unconfigured - never fallback options for a different project',
        );
      },
    );

    test(
      'unconfigured build: lists every required key and never starts the SDK',
      () async {
        expect(AppFirebaseOptions.missingKeys, AppFirebaseOptions.requiredKeys);
        expect(AppFirebaseOptions.resolve(), isNull);

        final result = await AppBootstrap.initialize(
          startFirebase: (_) async => fail('Firebase must not be started'),
        );
        expect(result.status, FirebaseInitStatus.notConfigured);
        expect(result.isReady, isFalse);
      },
      skip: skipUnconfigured,
    );

    test(
      'supplied Web configuration parses to the exact values',
      () {
        final FirebaseOptions options = AppFirebaseOptions.resolve()!;

        expect(options.apiKey, 'AIzaSyDSe6HNPLCoG4CoHhU4RiUjjwWUHZKB44o');
        expect(options.authDomain, 'bizbrain-e3a61.firebaseapp.com');
        expect(options.projectId, 'bizbrain-e3a61');
        expect(options.storageBucket, 'bizbrain-e3a61.firebasestorage.app');
        expect(options.messagingSenderId, '862761802417');
        expect(options.appId, '1:862761802417:web:b3e2e9732cf45afd666090');
        expect(options.measurementId, isNull, reason: 'not supplied for web');
        expect(AppFirebaseOptions.missingKeys, isEmpty);
      },
      skip: skipConfigured,
    );

    test('parsed options all belong to one project number', () {
      final FirebaseOptions options = AppFirebaseOptions.resolve()!;

      // Guards against a config file that silently mixes values from two
      // different Firebase projects: the app id and the sender id embed the
      // same project number, and the domain/bucket embed the same project id.
      final List<String> appIdParts = options.appId.split(':');
      expect(appIdParts, hasLength(4));
      expect(appIdParts[0], '1');
      expect(appIdParts[1], options.messagingSenderId);
      expect(
        appIdParts[2],
        'web',
        reason: 'web app id only, never Android/iOS',
      );
      expect(options.authDomain, startsWith('${options.projectId}.'));
      expect(options.storageBucket, startsWith('${options.projectId}.'));
    }, skip: skipConfigured);

    test(
      'bootstrap hands the exact resolved options to the SDK starter',
      () async {
        // `AppBootstrap._startFirebase` forwards its argument unchanged to
        // `Firebase.initializeApp(options: …)`, so capturing the starter
        // argument proves which options the SDK would receive - without ever
        // contacting a Firebase project.
        final List<FirebaseOptions> started = <FirebaseOptions>[];

        final FirebaseInitialization result = await AppBootstrap.initialize(
          startFirebase: (FirebaseOptions options) async =>
              started.add(options),
        );

        expect(result.status, FirebaseInitStatus.configured);
        expect(result.isReady, isTrue);
        expect(result.missingKeys, isEmpty);
        expect(started, hasLength(1));

        final FirebaseOptions resolved = AppFirebaseOptions.resolve()!;
        final FirebaseOptions startedOptions = started.single;
        expect(startedOptions.apiKey, resolved.apiKey);
        expect(startedOptions.authDomain, resolved.authDomain);
        expect(startedOptions.projectId, 'bizbrain-e3a61');
        expect(startedOptions.storageBucket, resolved.storageBucket);
        expect(startedOptions.messagingSenderId, resolved.messagingSenderId);
        expect(startedOptions.appId, resolved.appId);
        expect(startedOptions.measurementId, resolved.measurementId);
      },
      skip: skipConfigured,
    );
  });
}
