/// Route paths used by the GoRouter configuration.
///
/// A single source of truth prevents the redirect logic and the navigation
/// items from drifting apart.
abstract final class RoutePaths {
  static const String startup = '/startup';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  static const String dashboard = '/';
  static const String organizations = '/organizations';
  static const String dataSources = '/data-sources';
  static const String aiBrain = '/ai-brain';
  static const String aiChat = '/ai-chat';
  static const String businessRules = '/business-rules';
  static const String insights = '/insights';
  static const String reports = '/reports';
  static const String activityLogs = '/activity-logs';
  static const String settings = '/settings';
  static const String timeLapse = '/time-lapse';

  /// Routes reachable without a session.
  ///
  /// [startup] is included: it only reports build/configuration status and
  /// holds no business data, so it stays reachable while the session is being
  /// resolved (or when the build has no usable authentication backend).
  static const Set<String> publicPaths = <String>{
    startup,
    login,
    register,
    forgotPassword,
  };

  /// Every location actually registered in `app_router.dart`.
  ///
  /// Used to validate the `redirect` query parameter: an unknown destination
  /// is rejected instead of navigated to. Keep this set in sync with the
  /// router - the route table test in `test/app/router/app_router_test.dart`
  /// fails when they drift apart.
  static const Set<String> knownPaths = <String>{
    startup,
    login,
    register,
    forgotPassword,
    dashboard,
    organizations,
    dataSources,
    aiBrain,
    aiChat,
    businessRules,
    insights,
    reports,
    activityLogs,
    settings,
    timeLapse,
  };

  /// Query parameter carrying the deep link to restore after signing in.
  static const String redirectQueryParam = 'redirect';

  static bool isPublic(String location) =>
      publicPaths.contains(normalize(location));

  static bool isKnown(String location) =>
      knownPaths.contains(normalize(location));

  /// Strips trailing slashes so `/login/` and `/login` behave identically.
  static String normalize(String location) {
    if (location.length > 1 && location.endsWith('/')) {
      return location.substring(0, location.length - 1);
    }
    return location;
  }
}
