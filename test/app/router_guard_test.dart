// Router Guard Tests — Phase 5 (audit defect #17)
//
// The redirect decision was previously inlined in the GoRouter closure,
// and `/chat` + `/achievements` (pushed on top of the shell, outside the
// bottom nav) were missing from the protected set. With Supabase
// configured, a deep link straight to either screen bypassed the auth
// gate every other screen honors. The decision now lives in the pure
// `guardRedirect` / `isProtectedLocation` functions so the full gate
// matrix is testable without building a GoRouter or touching the static
// environment flags.

import 'package:flutter_test/flutter_test.dart';

import 'package:vaanix_app/app/router/app_router.dart';
import 'package:vaanix_app/core/constants/route_names.dart';

void main() {
  group('isProtectedLocation', () {
    test('matches every declared protected route exactly', () {
      for (final route in protectedRoutes) {
        expect(isProtectedLocation(route), isTrue,
            reason: '$route must be protected');
      }
    });

    test('covers /chat and /achievements (Phase 5 regression)', () {
      expect(protectedRoutes, contains(RouteNames.chat));
      expect(protectedRoutes, contains(RouteNames.achievements));
    });

    test('matches locations nested under a protected route', () {
      expect(isProtectedLocation('/learn/lesson/ls_greetings'), isTrue);
      expect(isProtectedLocation('/learn/lesson/ls_greetings/practice'),
          isTrue);
      expect(isProtectedLocation('/home/x'), isTrue);
    });

    test('does not match public routes or look-alike prefixes', () {
      expect(isProtectedLocation(RouteNames.splash), isFalse);
      expect(isProtectedLocation(RouteNames.onboarding), isFalse);
      expect(isProtectedLocation(RouteNames.auth), isFalse);
      // A route whose path merely STARTS with another route's text must
      // not match — the prefix check requires the '/' boundary.
      expect(isProtectedLocation('/settingsX'), isFalse);
      expect(isProtectedLocation('/unknown'), isFalse);
    });
  });

  group('guardRedirect — onboarding gate', () {
    test('redirects every non-public route while onboarding is incomplete',
        () {
      const locations = [
        RouteNames.home,
        RouteNames.learn,
        RouteNames.exam,
        RouteNames.progress,
        RouteNames.vanProfile,
        RouteNames.settings,
        RouteNames.chat,
        RouteNames.achievements,
        '/learn/lesson/ls_1',
        '/learn/lesson/ls_1/practice',
      ];
      for (final location in locations) {
        expect(
          guardRedirect(
            location: location,
            onboardingComplete: false,
            supabaseConfigured: false,
            isAuthenticated: false,
          ),
          RouteNames.onboarding,
          reason: '$location must be unreachable before onboarding',
        );
      }
    });

    test('public routes stay reachable during onboarding', () {
      for (final location in _publicLocations) {
        expect(
          guardRedirect(
            location: location,
            onboardingComplete: false,
            supabaseConfigured: false,
            isAuthenticated: false,
          ),
          isNull,
          reason: '$location is public and must not redirect',
        );
      }
    });
  });

  group('guardRedirect — auth gate (Supabase configured)', () {
    test(
        'unauthenticated users are redirected away from ALL protected '
        'routes — including /chat and /achievements (Phase 5 regression)',
        () {
      for (final location in protectedRoutes) {
        expect(
          guardRedirect(
            location: location,
            onboardingComplete: true,
            supabaseConfigured: true,
            isAuthenticated: false,
          ),
          RouteNames.auth,
          reason: '$location must require a session when Supabase is set',
        );
      }
    });

    test('nested protected locations are also gated', () {
      expect(
        guardRedirect(
          location: '/learn/lesson/ls_1/practice',
          onboardingComplete: true,
          supabaseConfigured: true,
          isAuthenticated: false,
        ),
        RouteNames.auth,
      );
    });

    test('authenticated users pass everywhere', () {
      for (final location in [...protectedRoutes, ..._publicLocations]) {
        expect(
          guardRedirect(
            location: location,
            onboardingComplete: true,
            supabaseConfigured: true,
            isAuthenticated: true,
          ),
          isNull,
          reason: '$location must be reachable when authenticated',
        );
      }
    });
  });

  group('guardRedirect — offline / no backend', () {
    test('auth gate never fires without Supabase (offline-first contract)',
        () {
      for (final location in [...protectedRoutes, ..._publicLocations]) {
        expect(
          guardRedirect(
            location: location,
            onboardingComplete: true,
            supabaseConfigured: false,
            isAuthenticated: false,
          ),
          isNull,
          reason:
              '$location must stay reachable for offline (noop-auth) users',
        );
      }
    });
  });
}

const _publicLocations = <String>[
  RouteNames.splash,
  RouteNames.onboarding,
  RouteNames.auth,
];
