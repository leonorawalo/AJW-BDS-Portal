import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/set_password_screen.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/consultants/presentation/assign_consultant_screen.dart';
import '../../features/consultants/presentation/consultant_portfolio_screen.dart';
import '../../features/enterprises/presentation/enterprise_list_screen.dart';
import '../../features/enterprises/presentation/enterprise_workspace_screen.dart';
import '../../features/enterprises/presentation/register_enterprise_screen.dart';
import '../../features/legal_workstream/presentation/consultant_workstream_screen.dart';
import '../../features/legal_workstream/presentation/owner_workstream_screen.dart';
import '../../features/legal_workstream/presentation/task_detail_screen.dart';
import '../../shared/models/user_profile.dart';

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

// /set-password is public because an invite link arrives before there's a
// session (the screen exchanges the link's token for one).
const _publicPaths = ['/login', '/forgot-password', '/set-password'];

final routerProvider = Provider<GoRouter>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  final refreshNotifier = GoRouterRefreshStream(authRepo.authStateChanges);

  // The auth-stream event and the profile fetch completing don't always
  // land in the same tick — without this, redirect could fire while the
  // fetch is still in flight and briefly act on the *previous* session's
  // cached profile. Re-triggering redirect explicitly once the fetch
  // actually resolves closes that race for good.
  ref.listen(currentUserProfileProvider, (_, _) => refreshNotifier.refresh());

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refreshNotifier,
    // An unknown URL (a stale bookmark, a mangled link) goes to login —
    // which the redirect then turns into the right home — instead of
    // go_router's error page.
    onException: (context, state, router) => router.go('/login'),
    redirect: (context, state) {
      final isPublicRoute = _publicPaths.contains(state.matchedLocation);
      final user = authRepo.currentUser;

      // Not signed in: only the public auth screens are reachable.
      if (user == null) {
        return isPublicRoute ? null : '/login';
      }

      // Invited and hasn't chosen a password yet (Phase 9a): nowhere else
      // until they do.
      if (authRepo.needsPassword) {
        return state.matchedLocation == '/set-password' ? null : '/set-password';
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
          //
          // /workstream/... is a deliberate exception: Task Detail is
          // shared by Consultant AND Owner (and now Admin), reached from
          // three different role homes, so it can never start with any
          // single homePath. RLS — not this route match — is the actual
          // security boundary for what's inside it.
          final isSharedWorkstreamRoute = state.matchedLocation.startsWith('/workstream');
          if (!isSharedWorkstreamRoute && !state.matchedLocation.startsWith(homePath)) {
            return homePath;
          }

          return null;
        },
      );
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/set-password',
        builder: (context, state) => SetPasswordScreen(
          tokenHash: state.uri.queryParameters['token_hash'],
          type: state.uri.queryParameters['type'],
        ),
      ),
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
            builder: (context, state) => EnterpriseWorkspaceScreen(
              enterpriseId: state.pathParameters['enterpriseId']!,
            ),
            routes: [
              GoRoute(
                path: 'assign-consultant',
                builder: (context, state) => AssignConsultantScreen(
                  preselectedEnterpriseId: state.pathParameters['enterpriseId'],
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'assign-consultant',
            builder: (context, state) => const AssignConsultantScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/consultant',
        builder: (context, state) => const ConsultantPortfolioScreen(),
        routes: [
          GoRoute(
            path: 'enterprises/:enterpriseId',
            builder: (context, state) => ConsultantWorkstreamScreen(
              enterpriseId: state.pathParameters['enterpriseId']!,
              enterpriseName: state.uri.queryParameters['name'] ?? 'Enterprise',
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/owner',
        builder: (context, state) => const OwnerWorkstreamScreen(),
      ),
      GoRoute(
        path: '/workstream/enterprises/:enterpriseId/tasks/:taskId',
        builder: (context, state) => TaskDetailScreen(
          taskId: state.pathParameters['taskId']!,
          readOnly: state.uri.queryParameters['readOnly'] == 'true',
        ),
      ),
    ],
  );
});