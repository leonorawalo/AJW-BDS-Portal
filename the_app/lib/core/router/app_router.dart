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
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

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

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: GoRouterRefreshStream(authRepo.authStateChanges),
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
        // Profile still loading (first frame after sign-in): stay put,
        // this redirect re-runs automatically once the FutureProvider
        // resolves because it's watched inside currentUserProfileProvider.
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

          // TODO(Module 1 milestone check): once /admin, /consultant,
          // /owner have real feature routes, also guard here so e.g. a
          // Consultant can't navigate into an /admin/* path directly.
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
      // Placeholder home routes — replaced by real feature screens in
      // Phase 2+ (Enterprise Management, Consultant Portfolio, etc).
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
        builder: (context, state) => const RoleHomePlaceholder(
          label: 'Consultant',
        ),
      ),
      GoRoute(
        path: '/owner',
        builder: (context, state) => const RoleHomePlaceholder(label: 'Enterprise Owner'),
      ),
    ],
  );
});

