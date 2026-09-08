import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/enterprises/presentation/enterprise_detail_screen.dart';
import '../../features/enterprises/presentation/enterprise_list_screen.dart';
import '../../features/enterprises/presentation/register_enterprise_screen.dart';
import '../../shared/models/user_profile.dart';

import 'role_home_placeholder.dart';

/// go_router's `redirect` is synchronous, but Supabase auth events arrive
/// as a stream. This bridges the two: every auth event calls
/// notifyListeners(), which GoRouter is watching via `refreshListenable`,
/// so it re-runs `redirect` right after a sign-in/sign-out.
///
/// [refresh] is exposed publicly (notifyListeners() itself is protected)
/// so routerProvider can also trigger a re-check when the *profile*
/// fetch resolves — not just the raw auth event — closing a race where
/// the two don't land in the same tick (see routerProvider below).
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  void refresh() => notifyListeners();

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

String _homePathFor(UserRole role) {
  switch (role) {
    case UserRole.administrator:
      return '/admin';
    case UserRole.consultant:
      return '/consultant';
    case UserRole.enterpriseOwner:
      return '/owner';
  }
}

const _publicPaths = ['/login', '/register', '/forgot-password'];

final routerProvider = Provider<GoRouter>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  final refreshNotifier = GoRouterRefreshStream(authRepo.authStateChanges);

  // The auth-stream event and the profile fetch completing don't always
  // land in the same tick — without this, redirect could fire while the
  // fetch is still in flight and briefly act on the *previous* session's
  // cached profile. Re-triggering redirect explicitly once the fetch
  // actually resolves closes that race for good.
  ref.listen(currentUserProfileProvider, (_, __) => refreshNotifier.refresh());

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final isPublicRoute = _publicPaths.contains(state.matchedLocation);
      final user = authRepo.currentUser;

      // Not signed in: only the public auth screens are reachable.
      if (user == null) {
        return isPublicRoute ? null : '/login';
      }

      // Signed in — figure out the role home before deciding anything.
      final profileAsync = ref.read(currentUserProfileProvider);

      return profileAsync.when(
        // Profile still loading (first frame after sign-in, or a fresh
        // refetch after switching accounts): stay put. The ref.listen
        // above guarantees redirect re-runs the moment this resolves.
        loading: () => null,
        error: (_, _) => '/login',
        data: (profile) {
          if (profile == null) return '/login';

          if (profile.isSuspended) {
            authRepo.signOut();
            return '/login';
          }

          final homePath = _homePathFor(profile.role);

          // Signed in but sitting on a login/register screen, or at the
          // root: send them to their role home.
          if (isPublicRoute || state.matchedLocation == '/') {
            return homePath;
          }

          // Cross-role guard: block navigating into another role's
          // section entirely, not just the initial post-login redirect.
          // e.g. a Consultant manually typing /admin/... in the address
          // bar gets bounced back to their own home, not allowed to
          // view Admin screens. startsWith (not ==) so this also covers
          // nested routes like /admin/enterprises/new.
          if (!state.matchedLocation.startsWith(homePath)) {
            return homePath;
          }

          return null;
        },
      );
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const EnterpriseListScreen(),
        routes: [
          GoRoute(
            path: 'enterprises/new',
            builder: (context, state) => const RegisterEnterpriseScreen(),
          ),
          GoRoute(
            path: 'enterprises/:enterpriseId',
            builder: (context, state) => EnterpriseDetailScreen(
              enterpriseId: state.pathParameters['enterpriseId']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/consultant',
        builder: (context, state) => const RoleHomePlaceholder(label: 'Consultant'),
      ),
      GoRoute(
        path: '/owner',
        builder: (context, state) => const RoleHomePlaceholder(label: 'Enterprise Owner'),
      ),
    ],
  );
});