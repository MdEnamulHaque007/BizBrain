import 'package:bizbrain/app/router/route_paths.dart';
import 'package:bizbrain/features/authentication/presentation/providers/auth_state.dart';

/// Pure redirect decisions for the application router.
///
/// The logic is a function of `(location, auth state)` only - no widget tree,
/// no provider container - so every rule can be unit tested directly:
///
/// 1. Unauthenticated users cannot open protected routes.
/// 2. They are sent to [RoutePaths.login], with the original destination kept
///    in the `redirect` query parameter.
/// 3. Authenticated and guest users may open protected routes.
/// 4. Authenticated and guest users visiting the sign-in / registration
///    screens are sent to a *validated* destination, falling back to the
///    dashboard.
/// 5. While the session is still resolving the startup screen is shown, and
///    the destination being travelled to is remembered there.
/// 6. A missing or failed Firebase configuration resolves to "no session" -
///    it never grants access to protected routes.
/// 8. Safe internal destinations are preserved across the sign-in flow.
/// 9. External or malformed destinations are rejected.
/// 10. Every chain reaches a fixed point, so redirects cannot loop.
/// 11. Guest mode is a local session: it grants the same route access as an
///    authenticated session without ever producing a user.
abstract final class AuthRedirect {
  /// Longest accepted `redirect` value; anything larger is rejected outright.
  static const int maxDestinationLength = 512;

  /// Returns the location to navigate to, or `null` to stay where we are.
  ///
  /// [location] is a path with an optional query string, e.g.
  /// `/login?redirect=%2Forganizations`.
  static String? redirect({required String location, required AuthState auth}) {
    final path = _pathOf(location);

    return switch (auth.status) {
      AuthStatus.loading => _whileLoading(path: path, location: location),
      AuthStatus.authenticated ||
      AuthStatus.guest => _whileSignedIn(path: path, location: location),
      AuthStatus.unauthenticated ||
      AuthStatus.unavailable => _withoutSession(path: path, location: location),
    };
  }

  /// Rule 5: the session is unknown, so the startup screen is shown and the
  /// destination we were travelling to is carried there for later.
  static String? _whileLoading({
    required String path,
    required String location,
  }) {
    if (path == RoutePaths.startup) return null;
    return _pending(RoutePaths.startup, path);
  }

  /// Rules 3, 4 and 11: signed-in and guest users move freely, except on the
  /// authentication screens - there the validated pending destination wins,
  /// then the dashboard. The startup screen is not a dead end either: without
  /// a pending destination it hands over to the dashboard.
  static String? _whileSignedIn({
    required String path,
    required String location,
  }) {
    if (path == RoutePaths.login ||
        path == RoutePaths.register ||
        path == RoutePaths.startup) {
      return safeDestination(_readRedirect(location)) ?? RoutePaths.dashboard;
    }
    return null;
  }

  /// Rules 1, 2 and 6: no session - including "Firebase is not configured" -
  /// never reaches a protected route.
  static String? _withoutSession({
    required String path,
    required String location,
  }) {
    if (path == RoutePaths.startup) {
      final pending = safeDestination(_readRedirect(location));
      // A deliberate visit to the status screen stays put; a destination
      // carried over from the loading phase is resumed, through the sign-in
      // screen when it is protected.
      if (pending == null) return null;
      return _loginFor(pending);
    }
    if (RoutePaths.isPublic(path)) return null;
    return _loginFor(path);
  }

  /// Validates a `redirect` value and returns the location it points at, or
  /// `null` when it must be ignored (rule 9).
  ///
  /// Accepted destinations are internal paths of this application only: they
  /// start with a single `/`, contain no control characters or backslashes,
  /// match a registered route, and are never one of the public authentication
  /// screens - which also removes any chance of bouncing between sign-in and
  /// its own destination (rule 10).
  static String? safeDestination(String? candidate) {
    if (candidate == null) return null;

    final raw = candidate.trim();
    if (raw.isEmpty || raw.length > maxDestinationLength) return null;
    if (!raw.startsWith('/')) return null;
    // `//host` and `/\host` are protocol-relative URLs in browsers.
    if (raw.startsWith('//') || raw.startsWith(r'/\')) return null;

    final path = _pathOf(raw);
    if (path.contains(r'\') || _hasUnsafeCharacters(path)) return null;
    if (!RoutePaths.knownPaths.contains(path)) return null;
    if (RoutePaths.isPublic(path)) return null;
    return path;
  }

  /// `/login?redirect=<encoded path>`, or plain `/login` when the destination
  /// is the dashboard itself.
  static String _loginFor(String path) {
    if (path == RoutePaths.dashboard) return RoutePaths.login;
    return '${RoutePaths.login}'
        '?${RoutePaths.redirectQueryParam}=${Uri.encodeComponent(path)}';
  }

  /// Location carrying [path] as the pending destination of [target].
  static String _pending(String target, String path) {
    return '$target'
        '?${RoutePaths.redirectQueryParam}=${Uri.encodeComponent(path)}';
  }

  /// Reads the `redirect` query parameter out of [location].
  static String? _readRedirect(String location) {
    final index = location.indexOf('?');
    if (index < 0) return null;

    try {
      final query = Uri.splitQueryString(location.substring(index + 1));
      return query[RoutePaths.redirectQueryParam];
    } on FormatException {
      // Malformed percent-encoding: reject rather than guess.
      return null;
    } on ArgumentError {
      // `Uri.splitQueryString` reports bad escapes as an ArgumentError.
      return null;
    }
  }

  /// Path part of [location] with query and fragment removed and the trailing
  /// slash normalised.
  static String _pathOf(String location) {
    var path = location;
    final query = path.indexOf('?');
    if (query >= 0) path = path.substring(0, query);
    final fragment = path.indexOf('#');
    if (fragment >= 0) path = path.substring(0, fragment);
    if (path.isEmpty) return RoutePaths.dashboard;
    return RoutePaths.normalize(path);
  }

  static bool _hasUnsafeCharacters(String value) {
    for (final code in value.runes) {
      if (code <= 0x20 || code == 0x7f) return true;
    }
    return false;
  }
}
