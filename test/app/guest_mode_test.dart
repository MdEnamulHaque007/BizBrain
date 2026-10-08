import 'package:bizbrain/app/router/route_paths.dart';
import 'package:bizbrain/app/shell/app_shell.dart';
import 'package:bizbrain/app/shell/navigation_items.dart';
import 'package:bizbrain/core/config/app_providers.dart';
import 'package:bizbrain/core/config/firebase_initialization.dart';
import 'package:bizbrain/core/widgets/state_views.dart';
import 'package:bizbrain/features/authentication/presentation/providers/auth_providers.dart';
import 'package:bizbrain/features/authentication/presentation/providers/auth_state.dart';
import 'package:bizbrain/features/authentication/presentation/screens/login_screen.dart';
import 'package:bizbrain/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:bizbrain/features/organizations/data/repositories/unconfigured_organization_repository.dart';
import 'package:bizbrain/features/organizations/domain/entities/organization.dart';
import 'package:bizbrain/features/organizations/domain/entities/organization_member.dart';
import 'package:bizbrain/features/organizations/domain/repositories/organization_repository.dart';
import 'package:bizbrain/features/organizations/presentation/providers/organization_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_test_helpers.dart';

/// Records every repository call: guest mode must never reach tenant data.
class SpyOrganizationRepository implements OrganizationRepository {
  int calls = 0;

  @override
  Stream<List<Organization>> watchUserOrganizations(String userId) {
    calls++;
    return Stream<List<Organization>>.value(const <Organization>[]);
  }

  @override
  Future<Organization?> fetchOrganization(String organizationId) async {
    calls++;
    return null;
  }

  @override
  Stream<OrganizationMember?> watchMembership({
    required String organizationId,
    required String userId,
  }) {
    calls++;
    return const Stream<OrganizationMember?>.empty();
  }
}

void main() {
  /// Pumps the sign-in screen at [width]x[height] with a configured auth
  /// backend that has no session. The organization repository is intentionally
  /// *not* overridden, so the guest gate in `organizationRepositoryProvider`
  /// stays under test.
  Future<PumpedApp> signedOutApp(
    WidgetTester tester, {
    double width = 900,
    double height = 1000,
    FirebaseInitialization firebase = const FirebaseInitialization.configured(),
    OrganizationRepository? organizations,
    bool overrideAuth = true,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    return pumpApp(
      tester,
      firebase: firebase,
      auth: overrideAuth ? FakeAuthRepository(isConfigured: true) : null,
      organizations: organizations,
    );
  }

  Future<void> enterGuest(WidgetTester tester, {Finder? via}) async {
    final button = via ?? find.text('Continue as Guest');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  group('guest entry', () {
    testWidgets('Continue as Guest starts a guest session on the dashboard', (
      tester,
    ) async {
      final app = await signedOutApp(tester);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Continue as Guest'), findsOneWidget);

      await enterGuest(tester);

      expect(tester.takeException(), isNull);
      expect(app.router.state.uri.path, RoutePaths.dashboard);
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(ErrorStateView), findsNothing);
      expect(find.text('Guest Demo'), findsWidgets);

      final auth = app.container.read(authControllerProvider);
      expect(auth.status, AuthStatus.guest);
      expect(auth.user, isNull);

      // The gate keeps the Firestore-backed repository out of guest mode;
      // constructing it would throw because no Firebase app exists in tests.
      expect(
        app.container.read(organizationRepositoryProvider),
        isA<UnconfiguredOrganizationRepository>(),
      );

      // Honest demo dashboard: no fabricated metrics, no error state.
      expect(
        find.text('Guest demo mode: sign in to load organization data.'),
        findsOneWidget,
      );
    });

    testWidgets('every registered shell route stays reachable in guest mode', (
      tester,
    ) async {
      final app = await signedOutApp(tester);
      await enterGuest(tester);

      for (final destination in NavigationItems.destinations) {
        app.router.go(destination.path);
        await tester.pumpAndSettle();

        expect(app.router.state.uri.path, destination.path);
        expect(
          find.byType(AppShell),
          findsOneWidget,
          reason: '${destination.path} must render inside the shell',
        );
        expect(
          find.byType(LoginScreen),
          findsNothing,
          reason: '${destination.path} must not bounce a guest to sign-in',
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('a pending ?redirect= destination is handed over to a guest', (
      tester,
    ) async {
      final app = await signedOutApp(tester);

      app.router.go(
        '${RoutePaths.login}'
        '?${RoutePaths.redirectQueryParam}='
        '${Uri.encodeComponent(RoutePaths.reports)}',
      );
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);

      await enterGuest(tester);

      expect(app.router.state.uri.path, RoutePaths.reports);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets('a build without Firebase can enter and leave guest mode', (
      tester,
    ) async {
      // No auth override: the production configuration-driven repository,
      // which refuses every operation in this build.
      final app = await signedOutApp(
        tester,
        overrideAuth: false,
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
      expect(find.byType(LoginScreen), findsOneWidget);

      await enterGuest(tester);

      expect(app.router.state.uri.path, RoutePaths.dashboard);
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.text('Guest Demo'), findsWidgets);
      expect(
        app.container.read(authControllerProvider).status,
        AuthStatus.guest,
      );

      await tester.ensureVisible(find.byTooltip('Exit Guest Mode'));
      await tester.tap(find.byTooltip('Exit Guest Mode'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
      expect(app.router.state.uri.path, RoutePaths.login);
      final auth = app.container.read(authControllerProvider);
      expect(auth.status, AuthStatus.unavailable);
      expect(auth.user, isNull);
      expect(
        find.text('Firebase configuration is missing for this build.'),
        findsWidgets,
      );
    });
  });

  group('guest indicator and exit', () {
    testWidgets('medium layout shows the badge and exits from the rail', (
      tester,
    ) async {
      final app = await signedOutApp(tester, width: 800, height: 600);
      app.container.read(authControllerProvider.notifier).continueAsGuest();
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Guest Demo'), findsOneWidget); // app bar badge
      expect(find.byTooltip('Exit Guest Mode'), findsOneWidget);

      await tester.tap(find.byTooltip('Exit Guest Mode'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
      expect(find.text('Guest Demo'), findsNothing);
      expect(app.router.state.uri.path, RoutePaths.login);
      expect(
        app.container.read(authControllerProvider).status,
        AuthStatus.unauthenticated,
      );
    });

    testWidgets('compact layout gets a drawer with guest header and exit', (
      tester,
    ) async {
      final app = await signedOutApp(tester, width: 400, height: 800);
      app.container.read(authControllerProvider.notifier).continueAsGuest();
      await tester.pumpAndSettle();

      // No rail on compact layouts: navigation lives behind the menu button.
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byIcon(Icons.menu), findsOneWidget);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.drawer, isA<NavigationDrawer>());

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      final drawer = find.byType(NavigationDrawer);
      expect(
        find.descendant(of: drawer, matching: find.text('Guest Demo')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: drawer,
          matching: find.text('Browsing without an account'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: drawer, matching: find.text('Exit Guest Mode')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: drawer, matching: find.text('Log out')),
        findsNothing,
      );

      await tester.tap(
        find.descendant(of: drawer, matching: find.text('Exit Guest Mode')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
      expect(app.router.state.uri.path, RoutePaths.login);
      expect(
        app.container.read(authControllerProvider).status,
        AuthStatus.unauthenticated,
      );
    });

    testWidgets('a signed-in user sees no guest chrome', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpApp(
        tester,
        auth: FakeAuthRepository(isConfigured: true, initialUser: testUser),
        organizations: const FakeOrganizationRepository(),
      );

      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.text('Guest Demo'), findsNothing);
      expect(find.byTooltip('Exit Guest Mode'), findsNothing);
      expect(find.text('Continue as Guest'), findsNothing);
    });
  });

  group('guest data isolation', () {
    testWidgets('no organization repository method is ever called', (
      tester,
    ) async {
      final spy = SpyOrganizationRepository();
      final app = await signedOutApp(tester, organizations: spy);
      await enterGuest(tester);

      for (final destination in NavigationItems.destinations) {
        app.router.go(destination.path);
        await tester.pumpAndSettle();
      }

      expect(spy.calls, 0, reason: 'guest mode must not read tenant data');
      expect(
        app.container.read(authControllerProvider).user,
        isNull,
        reason: 'a guest session never carries a user id',
      );
    });

    test('the repository gate blocks Firestore and exits cleanly', () async {
      final container = ProviderContainer(
        overrides: [
          firebaseInitializationProvider.overrideWithValue(
            const FirebaseInitialization.configured(),
          ),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(isConfigured: true),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(authControllerProvider.notifier).continueAsGuest();
      // The real session stream emits an initial value asynchronously; the
      // guest state must survive it.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(container.read(authControllerProvider).status, AuthStatus.guest);

      // `FirebaseFirestore.instance` would throw here (no Firebase app), so
      // reaching the unconfigured fallback proves the gate never builds the
      // Firestore-backed repository.
      final repository = container.read(organizationRepositoryProvider);
      expect(repository, isA<UnconfiguredOrganizationRepository>());
      expect(
        (repository as UnconfiguredOrganizationRepository).reason,
        contains('Guest demo mode'),
      );

      container.read(authControllerProvider.notifier).exitGuest();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.unauthenticated,
      );
      expect(container.read(authControllerProvider).user, isNull);
    });
  });
}
