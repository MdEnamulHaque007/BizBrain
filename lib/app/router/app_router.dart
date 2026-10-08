import 'package:bizbrain/app/router/auth_redirect.dart';
import 'package:bizbrain/app/router/route_paths.dart';
import 'package:bizbrain/app/router/router_refresh.dart';
import 'package:bizbrain/app/screens/activity_logs_screen.dart';
import 'package:bizbrain/app/screens/settings_screen.dart';
import 'package:bizbrain/app/screens/startup_screen.dart';
import 'package:bizbrain/app/shell/app_shell.dart';
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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Router for the whole application, provided via Riverpod so the redirect
/// logic can read the authentication state and tests can override it.
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final router = GoRouter(
    initialLocation: RoutePaths.dashboard,
    refreshListenable: RouterRefreshNotifier(ref),
    redirect: (context, state) => AuthRedirect.redirect(
      location: _locationOf(state.uri),
      auth: ref.read(authControllerProvider),
    ),
    // Unknown locations fold back into the app instead of dead-ending on an
    // error page; the redirect above then applies the usual auth rules.
    onException: (context, state, router) => router.go(RoutePaths.dashboard),
    routes: <RouteBase>[
      // Authenticated area: every protected page renders inside the
      // responsive shell, which receives the current location so the active
      // destination and app bar title always match the URL.
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: <RouteBase>[
          for (final MapEntry(key: path, value: builder) in _shellPages.entries)
            GoRoute(path: path, builder: builder),
        ],
      ),
      for (final MapEntry(key: path, value: builder) in _publicPages.entries)
        GoRoute(path: path, builder: builder),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});

/// Public locations rendered without the application shell: the start screen
/// and the authentication screens. Keep in sync with
/// `RoutePaths.publicPaths` - the drift test checks both directions.
final _publicPages = <String, GoRouterWidgetBuilder>{
  RoutePaths.startup: (_, _) => const StartupScreen(),
  RoutePaths.login: (_, _) => const LoginScreen(),
  RoutePaths.register: (_, _) => const RegisterScreen(),
  RoutePaths.forgotPassword: (_, _) => const ForgotPasswordScreen(),
};

/// Protected locations rendered inside [AppShell]. Keep in sync with
/// `RoutePaths.knownPaths` minus `RoutePaths.publicPaths` - the drift test
/// in `test/app/router/app_router_test.dart` checks both directions.
final _shellPages = <String, GoRouterWidgetBuilder>{
  RoutePaths.dashboard: (_, _) => const DashboardScreen(),
  RoutePaths.organizations: (_, _) => const OrganizationsScreen(),
  RoutePaths.dataSources: (_, _) => const DataSourcesScreen(),
  RoutePaths.aiBrain: (_, _) => const AiBrainScreen(),
  RoutePaths.businessRules: (_, _) => const BusinessRulesScreen(),
  RoutePaths.insights: (_, _) => const InsightsScreen(),
  RoutePaths.reports: (_, _) => const ReportsScreen(),
  RoutePaths.activityLogs: (_, _) => const ActivityLogsScreen(),
  RoutePaths.settings: (_, _) => const SettingsScreen(),
};

/// Reconstructs the path-plus-query representation the redirect logic uses.
String _locationOf(Uri uri) {
  final query = uri.query;
  return query.isEmpty ? uri.path : '${uri.path}?$query';
}
