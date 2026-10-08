import 'package:bizbrain/app/app.dart';
import 'package:bizbrain/app/router/route_paths.dart';
import 'package:bizbrain/app/screens/startup_screen.dart';
import 'package:bizbrain/core/config/firebase_initialization.dart';
import 'package:bizbrain/features/authentication/presentation/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_test_helpers.dart';

void main() {
  group('BizBrainApp startup', () {
    testWidgets('starts on sign-in when Firebase is not configured', (
      tester,
    ) async {
      final app = await pumpApp(
        tester,
        firebase: const FirebaseInitialization.notConfigured(
          reason: 'Firebase configuration is missing for this build.',
          missingKeys: <String>[
            'FIREBASE_API_KEY',
            'FIREBASE_AUTH_DOMAIN',
            'FIREBASE_PROJECT_ID',
            'FIREBASE_MESSAGING_SENDER_ID',
            'FIREBASE_APP_ID',
          ],
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('BizBrain AI'), findsOneWidget);
      expect(find.text('Firebase is not configured'), findsOneWidget);
      expect(
        find.text('Firebase configuration is missing for this build.'),
        findsWidgets, // shown by both the config notice and the banner
      );
      expect(app.router.state.uri.path, RoutePaths.login);
    });

    testWidgets('the start screen reports the configured state', (
      tester,
    ) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(isConfigured: true, emitInitial: false),
        organizations: const FakeOrganizationRepository(),
      );

      expect(find.byType(StartupScreen), findsOneWidget);
      expect(find.text('Firebase configured'), findsOneWidget);
      expect(find.text('Firebase is configured.'), findsOneWidget);
      expect(find.text('Missing definitions'), findsNothing);
      expect(
        find.textContaining('Authentication and data services are available'),
        findsOneWidget,
      );
    });

    testWidgets('the start screen reports the failed state with its reason', (
      tester,
    ) async {
      final app = await pumpApp(
        tester,
        firebase: const FirebaseInitialization.failed(
          reason: 'Firebase failed to start. [core/not-initialized]',
        ),
      );

      app.router.go(RoutePaths.startup);
      await tester.pumpAndSettle();

      expect(find.byType(StartupScreen), findsOneWidget);
      expect(find.text('Firebase failed to start'), findsOneWidget);
      expect(
        find.text('Firebase failed to start. [core/not-initialized]'),
        findsOneWidget,
      );
      expect(
        find.textContaining('unavailable until the initialization problem'),
        findsOneWidget,
      );
    });

    testWidgets('uses Material 3 light and dark themes', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: BizBrainApp()));
      await tester.pumpAndSettle();

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.theme?.useMaterial3, isTrue);
      expect(app.darkTheme?.useMaterial3, isTrue);
      expect(app.darkTheme?.brightness, Brightness.dark);
      expect(app.themeMode, ThemeMode.system);
      expect(app.title, 'BizBrain AI');
    });
  });
}
