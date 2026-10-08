import 'package:bizbrain/app/router/route_paths.dart';
import 'package:bizbrain/app/screens/activity_logs_screen.dart';
import 'package:bizbrain/app/screens/settings_screen.dart';
import 'package:bizbrain/app/shell/app_shell.dart';
import 'package:bizbrain/app/shell/navigation_items.dart';
import 'package:bizbrain/core/widgets/feature_placeholder_view.dart';
import 'package:bizbrain/features/authentication/presentation/screens/login_screen.dart';
import 'package:bizbrain/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:bizbrain/features/data_sources/presentation/screens/data_sources_screen.dart';
import 'package:bizbrain/features/insights/presentation/screens/insights_screen.dart';
import 'package:bizbrain/features/organizations/presentation/screens/organizations_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_test_helpers.dart';

void main() {
  /// Pumps the app at a logical [width]x[height]: 400 = compact (drawer),
  /// 800 = medium (icon rail), 1200 = extended rail.
  Future<PumpedApp> authedApp(
    WidgetTester tester, {
    double width = 800,
    double height = 600,
    FakeAuthRepository? auth,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    return pumpApp(
      tester,
      auth:
          auth ?? FakeAuthRepository(isConfigured: true, initialUser: testUser),
      organizations: const FakeOrganizationRepository(),
    );
  }

  Finder railLabel(String label) => find.descendant(
    of: find.byType(NavigationRail),
    matching: find.text(label),
  );

  group('compact layout (drawer)', () {
    testWidgets('shows the drawer behind a menu button', (tester) async {
      final app = await authedApp(tester, width: 400, height: 800);

      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byIcon(Icons.menu), findsOneWidget);
      expect(find.byTooltip('Open navigation'), findsOneWidget);

      // The drawer child only mounts while the drawer is open, so assert the
      // configured drawer on the scaffold itself.
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.drawer, isA<NavigationDrawer>());

      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(app.router.state.uri.path, RoutePaths.dashboard);
    });

    testWidgets('menu opens the drawer and destinations navigate', (
      tester,
    ) async {
      final app = await authedApp(tester, width: 400, height: 800);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold));
      expect(scaffold.isDrawerOpen, isTrue);

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationDrawer),
          matching: find.text('Organizations'),
        ),
      );
      await tester.pumpAndSettle();

      expect(app.router.state.uri.path, RoutePaths.organizations);
      expect(find.byType(OrganizationsScreen), findsOneWidget);
      expect(scaffold.isDrawerOpen, isFalse);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('drawer lists every destination', (tester) async {
      await authedApp(tester, width: 400, height: 800);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      final drawer = tester.widget<NavigationDrawer>(
        find.byType(NavigationDrawer),
      );
      expect(
        drawer.children.length,
        NavigationItems.destinations.length,
        reason: 'one drawer destination per navigation item',
      );
      expect(drawer.selectedIndex, 0);
    });
  });

  group('medium layout (icon rail)', () {
    testWidgets('shows an icon-only rail without a drawer', (tester) async {
      final app = await authedApp(tester);

      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationDrawer), findsNothing);
      expect(find.byIcon(Icons.menu), findsNothing);

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isFalse);
      expect(rail.selectedIndex, 0);
      expect(
        rail.destinations.length,
        NavigationItems.destinations.length,
        reason: 'one rail destination per navigation item',
      );
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(app.router.state.uri.path, RoutePaths.dashboard);
    });

    testWidgets('tapping a rail destination navigates', (tester) async {
      final app = await authedApp(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.byIcon(Icons.domain_outlined),
        ),
      );
      await tester.pumpAndSettle();

      expect(app.router.state.uri.path, RoutePaths.organizations);
      expect(find.byType(OrganizationsScreen), findsOneWidget);
      expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        NavigationItems.indexOf(RoutePaths.organizations),
      );
    });
  });

  group('expanded layout (extended rail)', () {
    testWidgets('shows an extended rail with visible labels', (tester) async {
      await authedApp(tester, width: 1200, height: 800);

      expect(find.byType(NavigationDrawer), findsNothing);
      expect(find.byIcon(Icons.menu), findsNothing);

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.extended, isTrue);
      expect(rail.destinations.length, NavigationItems.destinations.length);

      for (final destination in NavigationItems.destinations) {
        expect(
          railLabel(destination.label),
          findsOneWidget,
          reason: '${destination.label} must be visible when extended',
        );
      }
    });
  });

  group('navigation', () {
    testWidgets('title and active destination follow the route', (
      tester,
    ) async {
      final app = await authedApp(tester, width: 1200, height: 800);

      expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        0,
      );

      app.router.go(RoutePaths.insights);
      await tester.pumpAndSettle();

      expect(find.byType(InsightsScreen), findsOneWidget);
      expect(app.router.state.uri.path, RoutePaths.insights);
      expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        NavigationItems.indexOf(RoutePaths.insights),
      );
      expect(find.text('Insights'), findsWidgets);
    });

    testWidgets('deep links resolve inside the shell keeping the query', (
      tester,
    ) async {
      final app = await authedApp(tester, width: 1200, height: 800);

      app.router.go('${RoutePaths.dataSources}?from=link');
      await tester.pumpAndSettle();

      expect(find.byType(DataSourcesScreen), findsOneWidget);
      expect(app.router.state.uri.path, RoutePaths.dataSources);
      expect(app.router.state.uri.queryParameters['from'], 'link');
      expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        NavigationItems.indexOf(RoutePaths.dataSources),
      );
    });

    testWidgets('the placeholder features render inside the shell', (
      tester,
    ) async {
      final app = await authedApp(tester, width: 1200, height: 800);

      app.router.go(RoutePaths.activityLogs);
      await tester.pumpAndSettle();
      expect(find.byType(ActivityLogsScreen), findsOneWidget);
      expect(find.byType(FeaturePlaceholderView), findsOneWidget);

      app.router.go(RoutePaths.settings);
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.byType(FeaturePlaceholderView), findsOneWidget);
      expect(app.router.state.uri.path, RoutePaths.settings);
    });

    testWidgets('the navigation model matches the registered shell routes', (
      tester,
    ) async {
      await authedApp(tester);

      expect(NavigationItems.destinations.length, 9);
      expect(
        NavigationItems.destinations.map((d) => d.path).toSet(),
        RoutePaths.knownPaths.difference(RoutePaths.publicPaths),
      );
      expect(NavigationItems.indexOf('/'), 0);
      expect(NavigationItems.labelOf(RoutePaths.settings), 'Settings');
      expect(NavigationItems.labelOf(RoutePaths.login), isNull);
    });
  });

  group('account and log-out', () {
    testWidgets('extended rail shows the account and logs out', (tester) async {
      final app = await authedApp(tester, width: 1200, height: 800);

      expect(find.byTooltip('Owner · owner@example.com'), findsOneWidget);

      await tester.tap(find.byTooltip('Log out'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(DashboardScreen), findsNothing);
      expect(find.byType(AppShell), findsNothing);
      expect(app.router.state.uri.path, RoutePaths.login);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('logout from the drawer returns to sign-in', (tester) async {
      final app = await authedApp(tester, width: 400, height: 800);

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationDrawer),
          matching: find.text('Log out'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
      expect(app.router.state.uri.path, RoutePaths.login);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a failed logout keeps the session and reports it', (
      tester,
    ) async {
      final auth = FakeAuthRepository(isConfigured: true, initialUser: testUser)
        ..signOutError = StateError('sign-out blocked');
      final app = await authedApp(tester, auth: auth);

      await tester.tap(find.byTooltip('Log out'));
      await tester.pumpAndSettle();

      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(app.router.state.uri.path, RoutePaths.dashboard);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );

      // Drain the snack bar auto-dismiss timer before the test ends.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
