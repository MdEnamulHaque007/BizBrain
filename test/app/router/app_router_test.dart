import 'package:bizbrain/app/router/route_paths.dart';
import 'package:bizbrain/app/screens/activity_logs_screen.dart';
import 'package:bizbrain/app/screens/settings_screen.dart';
import 'package:bizbrain/app/screens/startup_screen.dart';
import 'package:bizbrain/core/config/firebase_initialization.dart';
import 'package:bizbrain/features/ai_brain/presentation/screens/ai_brain_screen.dart';
import 'package:bizbrain/features/authentication/presentation/providers/auth_providers.dart';
import 'package:bizbrain/features/authentication/presentation/screens/forgot_password_screen.dart';
import 'package:bizbrain/features/authentication/presentation/screens/login_screen.dart';
import 'package:bizbrain/features/authentication/presentation/screens/register_screen.dart';
import 'package:bizbrain/features/business_rules/presentation/screens/business_rules_screen.dart';
import 'package:bizbrain/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:bizbrain/features/data_sources/presentation/screens/data_sources_screen.dart';
import 'package:bizbrain/features/insights/presentation/screens/insights_screen.dart';
import 'package:bizbrain/features/organizations/presentation/screens/organizations_screen.dart';
import 'package:bizbrain/features/reports/presentation/screens/reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/app_test_helpers.dart';

void main() {
  Future<PumpedApp> authedApp(WidgetTester tester) => pumpApp(
    tester,
    auth: FakeAuthRepository(isConfigured: true, initialUser: testUser),
    organizations: const FakeOrganizationRepository(),
  );

  Future<PumpedApp> signedOutApp(WidgetTester tester) => pumpApp(
    tester,
    auth: FakeAuthRepository(isConfigured: true, initialUser: null),
    organizations: const FakeOrganizationRepository(),
  );

  Future<PumpedApp> loadingApp(WidgetTester tester) => pumpApp(
    tester,
    auth: FakeAuthRepository(isConfigured: true, emitInitial: false),
    organizations: const FakeOrganizationRepository(),
  );

  group('unauthenticated routing', () {
    testWidgets(
      'protected routes redirect to sign-in keeping the destination',
      (tester) async {
        final app = await signedOutApp(tester);

        app.router.go(RoutePaths.organizations);
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(DashboardScreen), findsNothing);
        expect(app.router.state.uri.path, RoutePaths.login);
        expect(
          app.router.state.uri.queryParameters[RoutePaths.redirectQueryParam],
          RoutePaths.organizations,
        );
      },
    );

    testWidgets('the dashboard redirects to a bare sign-in screen', (
      tester,
    ) async {
      final app = await signedOutApp(tester);

      app.router.go(RoutePaths.dashboard);
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(app.router.state.uri.path, RoutePaths.login);
      expect(
        app.router.state.uri.queryParameters.containsKey(
          RoutePaths.redirectQueryParam,
        ),
        isFalse,
      );
    });

    testWidgets('public authentication screens stay reachable', (tester) async {
      final app = await signedOutApp(tester);

      final screens = <String, Type>{
        RoutePaths.login: LoginScreen,
        RoutePaths.register: RegisterScreen,
        RoutePaths.forgotPassword: ForgotPasswordScreen,
      };
      for (final entry in screens.entries) {
        app.router.go(entry.key);
        await tester.pumpAndSettle();

        expect(
          find.byType(entry.value),
          findsOneWidget,
          reason: '${entry.key} must render ${entry.value}',
        );
        expect(app.router.state.uri.path, entry.key);
      }
    });

    testWidgets('the app starts on sign-in when no session exists', (
      tester,
    ) async {
      final app = await signedOutApp(tester);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(app.router.state.uri.path, RoutePaths.login);
    });
  });

  group('authenticated routing', () {
    testWidgets('every protected route renders (rule 3)', (tester) async {
      final app = await authedApp(tester);

      final screens = <String, Type>{
        RoutePaths.dashboard: DashboardScreen,
        RoutePaths.organizations: OrganizationsScreen,
        RoutePaths.dataSources: DataSourcesScreen,
        RoutePaths.aiBrain: AiBrainScreen,
        RoutePaths.businessRules: BusinessRulesScreen,
        RoutePaths.insights: InsightsScreen,
        RoutePaths.reports: ReportsScreen,
        RoutePaths.activityLogs: ActivityLogsScreen,
        RoutePaths.settings: SettingsScreen,
      };
      for (final entry in screens.entries) {
        app.router.go(entry.key);
        await tester.pumpAndSettle();

        expect(
          find.byType(entry.value),
          findsOneWidget,
          reason: '${entry.key} must render ${entry.value}',
        );
        expect(app.router.state.uri.path, entry.key);
      }
    });

    testWidgets('signed-in users start on the dashboard', (tester) async {
      final app = await authedApp(tester);
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(app.router.state.uri.path, RoutePaths.dashboard);
    });

    testWidgets(
      'signed-in users on the auth screens land on the validated destination',
      (tester) async {
        final app = await authedApp(tester);

        app.router.go(
          '${RoutePaths.login}'
          '?${RoutePaths.redirectQueryParam}='
          '${Uri.encodeComponent(RoutePaths.reports)}',
        );
        await tester.pumpAndSettle();

        expect(find.byType(ReportsScreen), findsOneWidget);
        expect(app.router.state.uri.path, RoutePaths.reports);

        app.router.go('${RoutePaths.login}?redirect=not-a-route');
        await tester.pumpAndSettle();

        expect(find.byType(DashboardScreen), findsOneWidget);
        expect(app.router.state.uri.path, RoutePaths.dashboard);
      },
    );
  });

  group('session resolution', () {
    testWidgets('a resolving session is parked on the start screen', (
      tester,
    ) async {
      final app = await loadingApp(tester);

      expect(find.byType(StartupScreen), findsOneWidget);
      expect(app.router.state.uri.path, RoutePaths.startup);

      app.router.go(RoutePaths.reports);
      await tester.pumpAndSettle();

      expect(find.byType(StartupScreen), findsOneWidget);
      expect(
        app.router.state.uri.queryParameters[RoutePaths.redirectQueryParam],
        RoutePaths.reports,
      );
    });

    testWidgets('an arriving session moves the router to the destination', (
      tester,
    ) async {
      final auth = FakeAuthRepository(isConfigured: true, initialUser: null);
      final app = await pumpApp(
        tester,
        auth: auth,
        organizations: const FakeOrganizationRepository(),
      );

      app.router.go(RoutePaths.reports);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);

      auth.emit(testUser);
      await tester.pumpAndSettle();

      expect(find.byType(ReportsScreen), findsOneWidget);
      expect(app.router.state.uri.path, RoutePaths.reports);
    });
  });

  group('unavailable firebase (rule 6)', () {
    testWidgets('a missing configuration never reaches protected routes', (
      tester,
    ) async {
      final app = await pumpApp(
        tester,
        firebase: const FirebaseInitialization.notConfigured(
          reason: 'Firebase configuration is missing for this build.',
          missingKeys: <String>['FIREBASE_API_KEY', 'FIREBASE_APP_ID'],
        ),
      );

      app.router.go(RoutePaths.organizations);
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Firebase is not configured'), findsOneWidget);
      expect(find.byType(DashboardScreen), findsNothing);
      expect(app.router.state.uri.path, RoutePaths.login);
    });

    testWidgets('a failed configuration resolves to sign-in too', (
      tester,
    ) async {
      final app = await pumpApp(
        tester,
        firebase: const FirebaseInitialization.failed(
          reason: 'Firebase failed to start. [core/not-initialized]',
        ),
      );

      app.router.go(RoutePaths.dataSources);
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(DataSourcesScreen), findsNothing);
    });
  });

  group('sign-in and sign-out flows', () {
    testWidgets('signing in resumes the protected destination', (tester) async {
      final app = await signedOutApp(tester);

      app.router.go(RoutePaths.organizations);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'owner@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.byType(OrganizationsScreen), findsOneWidget);
      expect(app.router.state.uri.path, RoutePaths.organizations);
    });

    testWidgets('signing out returns to the sign-in screen', (tester) async {
      final app = await authedApp(tester);
      expect(find.byType(DashboardScreen), findsOneWidget);

      await app.container.read(authControllerProvider.notifier).signOut();
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(app.router.state.uri.path, RoutePaths.login);
    });
  });

  group('route table integrity', () {
    testWidgets('knownPaths matches the registered routes (no drift)', (
      tester,
    ) async {
      final app = await authedApp(tester);

      // Collect paths from every route at any depth (the shell nests its
      // pages inside a ShellRoute, public pages sit at the top level).
      Set<String> collectPaths(Iterable<RouteBase> routes) {
        final paths = <String>{};
        for (final route in routes) {
          if (route is GoRoute) paths.add(route.path);
          paths.addAll(collectPaths(route.routes));
        }
        return paths;
      }

      final configuration = app.router.configuration;
      expect(collectPaths(configuration.routes), RoutePaths.knownPaths);

      final topLevel = configuration.routes
          .whereType<GoRoute>()
          .map((route) => route.path)
          .toSet();
      expect(topLevel, RoutePaths.publicPaths);

      expect(
        configuration.routes.whereType<ShellRoute>().length,
        1,
        reason: 'one shell wraps all protected pages',
      );
    });

    testWidgets('unknown locations fold back into the app', (tester) async {
      final app = await authedApp(tester);

      app.router.go('/does-not-exist');
      await tester.pumpAndSettle();

      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(app.router.state.uri.path, RoutePaths.dashboard);
    });
  });
}
