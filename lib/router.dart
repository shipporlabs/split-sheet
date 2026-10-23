import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'models/models.dart';
import 'screens/auth_screens.dart';
import 'screens/create_sheet_screen.dart';
import 'screens/deposit_screen.dart';
import 'screens/home_screen.dart';
import 'screens/invite_screen.dart';
import 'screens/join_screens.dart';
import 'screens/landing_page.dart';
import 'screens/payouts_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/request_change_screen.dart';
import 'screens/shell.dart';
import 'screens/sheet_detail_screen.dart';
import 'screens/sign_screen.dart';
import 'screens/verify_page.dart';
import 'state/app_state.dart';
import 'widgets/common.dart';

const _authPages = {'/welcome', '/sign-in', '/sign-up', '/setup'};
const _tabs = {'/home', '/payouts', '/profile', '/app'};

bool _isPublic(String loc) => loc == '/' || loc.startsWith('/verify') || _authPages.contains(loc);

Widget _framed(Widget child) => PhoneFrame(child: child);

GoRouter buildRouter(AppState state) {
  return GoRouter(
    initialLocation: kIsWeb ? '/' : '/app',
    refreshListenable: state,
    redirect: (context, s) {
      final loc = s.matchedLocation;
      if (loc == '/app') {
        if (state.signedIn) return '/home';
        return state.needsProfile ? '/setup' : '/welcome';
      }
      // The landing page is the web front door; the phone app opens straight into the product.
      if (loc == '/' && !kIsWeb) return '/app';

      if (state.signedOut) {
        if (loc == '/setup') return '/welcome';
        if (!_isPublic(loc)) {
          // Remember deep links (an invite, a sheet) so sign-up continues there; tabs just go home.
          state.afterAuthPath = _tabs.contains(loc) ? null : s.uri.toString();
          return '/welcome';
        }
        return null;
      }
      if (state.needsProfile) {
        if (loc == '/setup' || loc == '/' || loc.startsWith('/verify')) return null;
        if (!_authPages.contains(loc) && !_tabs.contains(loc)) state.afterAuthPath = s.uri.toString();
        return '/setup';
      }
      if (state.signedIn && _authPages.contains(loc)) return state.takeAfterAuthPath() ?? '/home';
      return null;
    },
    errorBuilder: (context, s) => _framed(const NotFoundView(message: 'That page does not exist.')),
    routes: [
      GoRoute(path: '/', builder: (c, s) => const LandingPage()),
      GoRoute(path: '/app', builder: (c, s) => const SizedBox.shrink()),
      GoRoute(path: '/welcome', builder: (c, s) => _framed(const WelcomeScreen())),
      GoRoute(path: '/sign-in', builder: (c, s) => _framed(const SignInScreen())),
      GoRoute(path: '/sign-up', builder: (c, s) => _framed(const SignUpScreen())),
      GoRoute(path: '/setup', builder: (c, s) => _framed(const SetupScreen())),
      ShellRoute(
        builder: (c, s, child) => _framed(AppShell(location: s.uri.path, child: child)),
        routes: [
          GoRoute(path: '/home', pageBuilder: (c, s) => const NoTransitionPage(child: HomeScreen())),
          GoRoute(path: '/payouts', pageBuilder: (c, s) => const NoTransitionPage(child: PayoutsScreen())),
          GoRoute(path: '/profile', pageBuilder: (c, s) => const NoTransitionPage(child: ProfileScreen())),
        ],
      ),
      GoRoute(
        path: '/new',
        builder: (c, s) => _framed(CreateSheetScreen(initial: s.extra is SheetDraft ? s.extra as SheetDraft : null)),
      ),
      GoRoute(path: '/join', builder: (c, s) => _framed(const JoinScreen())),
      GoRoute(path: '/join/:code', builder: (c, s) => _framed(JoinScreen(code: s.pathParameters['code']))),
      GoRoute(path: '/scan', builder: (c, s) => const ScanScreen()),
      GoRoute(path: '/sheet/:id', builder: (c, s) => _framed(SheetDetailScreen(id: s.pathParameters['id']!))),
      GoRoute(path: '/sheet/:id/invite', builder: (c, s) => _framed(InviteScreen(id: s.pathParameters['id']!))),
      GoRoute(
        path: '/sheet/:id/sign/:index',
        builder: (c, s) => _framed(SignScreen(
          id: s.pathParameters['id']!,
          index: int.tryParse(s.pathParameters['index'] ?? '') ?? 0,
        )),
      ),
      GoRoute(
        path: '/sheet/:id/change/:index',
        builder: (c, s) => _framed(RequestChangeScreen(
          id: s.pathParameters['id']!,
          index: int.tryParse(s.pathParameters['index'] ?? '') ?? 0,
        )),
      ),
      GoRoute(path: '/deposit/:id', builder: (c, s) => _framed(DepositScreen(id: s.pathParameters['id']!))),
      GoRoute(path: '/verify', builder: (c, s) => const VerifyPage()),
      GoRoute(path: '/verify/:id', builder: (c, s) => VerifyPage(id: s.pathParameters['id'])),
    ],
  );
}
