import 'package:bizbrain/app/bootstrap/app_bootstrap.dart';
import 'package:bizbrain/core/config/firebase_initialization.dart';
import 'package:bizbrain/core/config/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Test double only: these values never leave the test and no Firebase
  /// service is contacted, because [startFirebase] is always replaced.
  const options = FirebaseOptions(
    apiKey: 'test-api-key',
    authDomain: 'test.invalid',
    projectId: 'test-project',
    messagingSenderId: '000000000000',
    appId: '1:000000000000:web:0000000000000000000000',
  );

  group('AppBootstrap', () {
    test(
      'reports configured when options are present and the SDK starts',
      () async {
        final started = <String>[];

        final result = await AppBootstrap.initialize(
          resolveOptions: () => options,
          readMissingKeys: () => const <String>[],
          startFirebase: (resolved) async => started.add(resolved.projectId),
        );

        expect(result.status, FirebaseInitStatus.configured);
        expect(result.isReady, isTrue);
        expect(result.missingKeys, isEmpty);
        expect(started, ['test-project']);
      },
    );

    test('reports notConfigured and never starts the SDK', () async {
      var started = false;

      final result = await AppBootstrap.initialize(
        resolveOptions: () => null,
        readMissingKeys: () => const <String>[
          'FIREBASE_API_KEY',
          'FIREBASE_APP_ID',
        ],
        startFirebase: (_) async => started = true,
      );

      expect(result.status, FirebaseInitStatus.notConfigured);
      expect(result.isReady, isFalse);
      expect(result.missingKeys, ['FIREBASE_API_KEY', 'FIREBASE_APP_ID']);
      expect(result.reason, isNotNull);
      expect(started, isFalse);
    });

    test('reports failed when the SDK throws and keeps the reason', () async {
      final result = await AppBootstrap.initialize(
        resolveOptions: () => options,
        readMissingKeys: () => const <String>[],
        startFirebase: (_) async => throw StateError('sdk refused to start'),
      );

      expect(result.status, FirebaseInitStatus.failed);
      expect(result.isReady, isFalse);
      expect(result.reason, contains('sdk refused to start'));
    });

    test('never throws, even when the resolver itself fails', () async {
      final result = await AppBootstrap.initialize(
        resolveOptions: () => throw const FormatException('broken config'),
      );

      expect(result.status, FirebaseInitStatus.failed);
      expect(result.isReady, isFalse);
    });

    test('runs against the real build definition', () async {
      // Unit tests normally run without any FIREBASE_* dart-define, so the
      // real resolver yields nothing and the Firebase SDK is never touched.
      // When the suite is run with --dart-define-from-file the same call
      // must resolve the configured project instead.
      if (AppFirebaseOptions.isConfigured) {
        final started = <FirebaseOptions>[];
        final result = await AppBootstrap.initialize(
          startFirebase: (options) async => started.add(options),
        );

        expect(result.status, FirebaseInitStatus.configured);
        expect(result.missingKeys, isEmpty);
        expect(started, hasLength(1));
        expect(started.single.projectId, 'bizbrain-e3a61');
      } else {
        expect(AppFirebaseOptions.isConfigured, isFalse);

        final result = await AppBootstrap.initialize(
          startFirebase: (_) async => fail('Firebase must not be started'),
        );

        expect(result.status, FirebaseInitStatus.notConfigured);
        expect(result.missingKeys, isNotEmpty);
        expect(result.isReady, isFalse);
      }
    });
  });

  group('AppBootstrap.describeFailure', () {
    test('collapses whitespace', () {
      expect(
        AppBootstrap.describeFailure(StateError('line\n  break')),
        contains('line break'),
      );
    });

    test('truncates long messages', () {
      final description = AppBootstrap.describeFailure('x' * 500);
      expect(description.length, lessThan(500));
      expect(description, endsWith('…'));
    });
  });
}
