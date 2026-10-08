import 'package:bizbrain/app/router/auth_redirect.dart';
import 'package:bizbrain/app/router/route_paths.dart';
import 'package:bizbrain/features/authentication/domain/entities/app_user.dart';
import 'package:bizbrain/features/authentication/presentation/providers/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const user = AppUser(uid: 'u-test', email: 'owner@example.com');
  const loading = AuthState.loading();
  const signedOut = AuthState.signedOut();
  const unavailable = AuthState.unavailable('Firebase is not configured.');
  const authenticated = AuthState.authenticated(user);
  const guest = AuthState.guest();

  group('AuthRedirect - loading session (rule 5)', () {
    test('hands every destination to the startup screen', () {
      expect(
        AuthRedirect.redirect(location: RoutePaths.dashboard, auth: loading),
        '${RoutePaths.startup}'
        '?${RoutePaths.redirectQueryParam}=${Uri.encodeComponent(RoutePaths.dashboard)}',
      );
      expect(
        AuthRedirect.redirect(location: RoutePaths.reports, auth: loading),
        '${RoutePaths.startup}'
        '?${RoutePaths.redirectQueryParam}=${Uri.encodeComponent(RoutePaths.reports)}',
      );
      expect(
        AuthRedirect.redirect(location: RoutePaths.login, auth: loading),
        '${RoutePaths.startup}'
        '?${RoutePaths.redirectQueryParam}=${Uri.encodeComponent(RoutePaths.login)}',
      );
    });

    test('stays on the startup screen while it is showing', () {
      expect(
        AuthRedirect.redirect(location: RoutePaths.startup, auth: loading),
        isNull,
      );
    });
  });

  group('AuthRedirect - no session, protected routes (rules 1 and 2)', () {
    test('signed-out users are sent to sign-in with the destination kept', () {
      expect(
        AuthRedirect.redirect(
          location: RoutePaths.organizations,
          auth: signedOut,
        ),
        '${RoutePaths.login}'
        '?${RoutePaths.redirectQueryParam}='
        '${Uri.encodeComponent(RoutePaths.organizations)}',
      );
      expect(
        AuthRedirect.redirect(location: RoutePaths.reports, auth: signedOut),
        '${RoutePaths.login}'
        '?${RoutePaths.redirectQueryParam}='
        '${Uri.encodeComponent(RoutePaths.reports)}',
      );
      // Query strings on the protected destination do not confuse the guard.
      expect(
        AuthRedirect.redirect(
          location: '${RoutePaths.dataSources}?tab=connections',
          auth: signedOut,
        ),
        '${RoutePaths.login}'
        '?${RoutePaths.redirectQueryParam}='
        '${Uri.encodeComponent(RoutePaths.dataSources)}',
      );
    });

    test('the dashboard is special-cased to a bare sign-in screen', () {
      expect(
        AuthRedirect.redirect(location: RoutePaths.dashboard, auth: signedOut),
        RoutePaths.login,
      );
    });

    test('unavailable backend behaves like no session (rule 6)', () {
      expect(
        AuthRedirect.redirect(location: RoutePaths.reports, auth: unavailable),
        '${RoutePaths.login}'
        '?${RoutePaths.redirectQueryParam}='
        '${Uri.encodeComponent(RoutePaths.reports)}',
      );
      expect(
        AuthRedirect.redirect(
          location: RoutePaths.dashboard,
          auth: unavailable,
        ),
        RoutePaths.login,
      );
    });
  });

  group('AuthRedirect - guest session (rules 3, 4 and 11)', () {
    test('guests may open every protected route (rule 3)', () {
      for (final path in <String>[
        RoutePaths.dashboard,
        RoutePaths.organizations,
        RoutePaths.dataSources,
        RoutePaths.aiBrain,
        RoutePaths.businessRules,
        RoutePaths.insights,
        RoutePaths.reports,
        RoutePaths.activityLogs,
        RoutePaths.settings,
      ]) {
        expect(
          AuthRedirect.redirect(location: path, auth: guest),
          isNull,
          reason: '$path must be reachable in guest mode',
        );
      }
    });

    test('the authentication screens hand over to the dashboard (rule 4)', () {
      expect(
        AuthRedirect.redirect(location: RoutePaths.login, auth: guest),
        RoutePaths.dashboard,
      );
      expect(
        AuthRedirect.redirect(location: RoutePaths.register, auth: guest),
        RoutePaths.dashboard,
      );
      expect(
        AuthRedirect.redirect(location: RoutePaths.startup, auth: guest),
        RoutePaths.dashboard,
      );
    });

    test('a pending destination wins on the sign-in screen (rule 8)', () {
      expect(
        AuthRedirect.redirect(
          location:
              '${RoutePaths.login}'
              '?${RoutePaths.redirectQueryParam}='
              '${Uri.encodeComponent(RoutePaths.reports)}',
          auth: guest,
        ),
        RoutePaths.reports,
      );
    });
  });

  group('AuthRedirect - no session, public routes', () {
    test('the authentication screens stay reachable', () {
      for (final path in RoutePaths.publicPaths) {
        expect(
          AuthRedirect.redirect(location: path, auth: signedOut),
          isNull,
          reason: '$path must stay reachable when signed out',
        );
      }
      for (final path in RoutePaths.publicPaths) {
        expect(
          AuthRedirect.redirect(location: path, auth: unavailable),
          isNull,
          reason: '$path must stay reachable without a backend',
        );
      }
    });
  });

  group('AuthRedirect - signed in', () {
    test('movement is unrestricted on protected routes (rule 3)', () {
      for (final path in <String>[
        RoutePaths.dashboard,
        RoutePaths.organizations,
        RoutePaths.dataSources,
        RoutePaths.aiBrain,
        RoutePaths.businessRules,
        RoutePaths.insights,
        RoutePaths.reports,
      ]) {
        expect(
          AuthRedirect.redirect(location: path, auth: authenticated),
          isNull,
          reason: '$path must be reachable when signed in',
        );
      }
    });

    test('auth screens hand over to the dashboard (rule 4)', () {
      expect(
        AuthRedirect.redirect(location: RoutePaths.login, auth: authenticated),
        RoutePaths.dashboard,
      );
      expect(
        AuthRedirect.redirect(
          location: RoutePaths.register,
          auth: authenticated,
        ),
        RoutePaths.dashboard,
      );
      expect(
        AuthRedirect.redirect(
          location: RoutePaths.startup,
          auth: authenticated,
        ),
        RoutePaths.dashboard,
      );
    });

    test(
      'a validated pending destination wins on the auth screens (rule 8)',
      () {
        expect(
          AuthRedirect.redirect(
            location:
                '${RoutePaths.login}'
                '?${RoutePaths.redirectQueryParam}='
                '${Uri.encodeComponent(RoutePaths.reports)}',
            auth: authenticated,
          ),
          RoutePaths.reports,
        );
        expect(
          AuthRedirect.redirect(
            location:
                '${RoutePaths.register}'
                '?${RoutePaths.redirectQueryParam}='
                '${Uri.encodeComponent(RoutePaths.organizations)}',
            auth: authenticated,
          ),
          RoutePaths.organizations,
        );
        expect(
          AuthRedirect.redirect(
            location:
                '${RoutePaths.startup}'
                '?${RoutePaths.redirectQueryParam}='
                '${Uri.encodeComponent(RoutePaths.insights)}',
            auth: authenticated,
          ),
          RoutePaths.insights,
        );
      },
    );

    test('an invalid pending destination falls back to the dashboard', () {
      expect(
        AuthRedirect.redirect(
          location:
              '${RoutePaths.login}'
              '?${RoutePaths.redirectQueryParam}='
              '${Uri.encodeComponent(RoutePaths.login)}',
          auth: authenticated,
        ),
        RoutePaths.dashboard,
      );
      expect(
        AuthRedirect.redirect(
          location:
              '${RoutePaths.login}'
              '?${RoutePaths.redirectQueryParam}=%ZZ',
          auth: authenticated,
        ),
        RoutePaths.dashboard,
      );
    });
  });

  group('AuthRedirect.safeDestination (rules 8 and 9)', () {
    test('accepts known internal protected paths', () {
      const protectedPaths = <String>[
        RoutePaths.dashboard,
        RoutePaths.organizations,
        RoutePaths.dataSources,
        RoutePaths.aiBrain,
        RoutePaths.businessRules,
        RoutePaths.insights,
        RoutePaths.reports,
        RoutePaths.activityLogs,
        RoutePaths.settings,
      ];
      for (final path in protectedPaths) {
        expect(AuthRedirect.safeDestination(path), path);
      }
      // A trailing slash normalises to the canonical path. The dashboard is
      // excluded: its trailing-slash form would be `//`, a protocol-relative
      // URL, which must stay rejected (see the malformed-destinations test).
      for (final path in protectedPaths.where(
        (path) => path != RoutePaths.dashboard,
      )) {
        expect(AuthRedirect.safeDestination('$path/'), path);
      }
    });

    test('rejects blank, malformed and external destinations', () {
      expect(AuthRedirect.safeDestination(null), isNull);
      expect(AuthRedirect.safeDestination(''), isNull);
      expect(AuthRedirect.safeDestination('   '), isNull);
      expect(AuthRedirect.safeDestination('reports'), isNull);
      expect(AuthRedirect.safeDestination('//evil.example.com/path'), isNull);
      expect(AuthRedirect.safeDestination(r'/\evil.example.com/path'), isNull);
      expect(AuthRedirect.safeDestination(r'/reports\evil'), isNull);
      expect(AuthRedirect.safeDestination('/repo\ts'), isNull);
      expect(AuthRedirect.safeDestination('/reports\x7f'), isNull);
      expect(AuthRedirect.safeDestination('/${'a' * 512}'), isNull);
    });

    test('rejects paths that are not registered routes', () {
      expect(AuthRedirect.safeDestination('/does-not-exist'), isNull);
      expect(AuthRedirect.safeDestination('/billing'), isNull);
    });

    test('rejects the public authentication screens (loop prevention)', () {
      for (final path in <String>[
        RoutePaths.login,
        RoutePaths.register,
        RoutePaths.forgotPassword,
        RoutePaths.startup,
      ]) {
        expect(
          AuthRedirect.safeDestination(path),
          isNull,
          reason: '$path must never be a sign-in destination',
        );
      }
    });
  });

  group('AuthRedirect - every chain reaches a fixed point (rule 10)', () {
    String settled(String location, AuthState state) {
      var current = location;
      final seen = <String>{};
      var hops = 0;
      while (true) {
        if (!seen.add(current)) break;
        final next = AuthRedirect.redirect(location: current, auth: state);
        if (next == null || next == current) break;
        current = next;
        hops++;
        if (hops > 4) break; // mirrors go_router's redirectLimit of 5
      }
      return current;
    }

    test('signed out: protected -> login stops moving', () {
      // The fixed point keeps the pending destination in its query string;
      // from there the public sign-in screen has nowhere left to go.
      expect(
        settled(RoutePaths.organizations, signedOut),
        '${RoutePaths.login}'
        '?${RoutePaths.redirectQueryParam}='
        '${Uri.encodeComponent(RoutePaths.organizations)}',
      );
      expect(settled(RoutePaths.dashboard, signedOut), RoutePaths.login);
      expect(settled(RoutePaths.login, signedOut), RoutePaths.login);
    });

    test('signed in: auth screens -> validated destination then stop', () {
      expect(settled(RoutePaths.login, authenticated), RoutePaths.dashboard);
      expect(settled(RoutePaths.register, authenticated), RoutePaths.dashboard);
      expect(
        settled(
          '${RoutePaths.login}'
          '?${RoutePaths.redirectQueryParam}='
          '${Uri.encodeComponent(RoutePaths.reports)}',
          authenticated,
        ),
        RoutePaths.reports,
      );
      // A public pending destination cannot create a login/login cycle.
      expect(
        settled(
          '${RoutePaths.register}'
          '?${RoutePaths.redirectQueryParam}='
          '${Uri.encodeComponent(RoutePaths.login)}',
          authenticated,
        ),
        RoutePaths.dashboard,
      );
    });

    test('guest: auth screens -> validated destination then stop', () {
      expect(settled(RoutePaths.login, guest), RoutePaths.dashboard);
      expect(
        settled(RoutePaths.organizations, guest),
        RoutePaths.organizations,
      );
      expect(
        settled(
          '${RoutePaths.login}'
          '?${RoutePaths.redirectQueryParam}='
          '${Uri.encodeComponent(RoutePaths.reports)}',
          guest,
        ),
        RoutePaths.reports,
      );
    });

    test('loading: every destination settles on the startup screen', () {
      expect(
        settled(RoutePaths.organizations, loading),
        '${RoutePaths.startup}'
        '?${RoutePaths.redirectQueryParam}='
        '${Uri.encodeComponent(RoutePaths.organizations)}',
      );
      expect(settled(RoutePaths.startup, loading), RoutePaths.startup);
    });

    test('never exceeds the router redirect limit', () {
      int hops(String start, AuthState state) {
        var current = start;
        var count = 0;
        while (true) {
          final next = AuthRedirect.redirect(location: current, auth: state);
          if (next == null || next == current) return count;
          current = next;
          count++;
          if (count > 20) return count;
        }
      }

      for (final state in [
        loading,
        signedOut,
        unavailable,
        authenticated,
        guest,
      ]) {
        for (final path in RoutePaths.knownPaths) {
          expect(
            hops(path, state),
            lessThan(5),
            reason: 'redirect from $path under $state must settle quickly',
          );
          expect(
            hops('$path?${RoutePaths.redirectQueryParam}=x', state),
            lessThan(5),
            reason:
                'redirect from "$path?..." under $state must settle quickly',
          );
        }
      }
    });
  });
}
