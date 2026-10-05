import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/screens/login_page.dart';
import '../../features/auth/presentation/screens/official_web_login_page.dart';
import '../../features/dashboard/presentation/screens/dashboard_shell.dart';
import '../../features/dashboard/presentation/cubit/home_preload_cubit.dart';
import '../../features/fixtures/presentation/screens/public_matches_page.dart';
import '../../features/team/presentation/screens/team_view.dart';
import '../widgets/splash_page.dart';

GoRouter createRouter(AuthCubit authCubit, HomePreloadCubit preloadCubit) {
  final refresh = ValueNotifier(0);
  authCubit.stream.listen((_) => refresh.value++);
  preloadCubit.stream.listen((_) => refresh.value++);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final auth = authCubit.state;
      final preload = preloadCubit.state;

      final authResult = authRedirect(auth, location);
      if (authResult != null) return authResult;

      if (auth.session != null) {
        final isHome = location == '/home';
        final isSplash = location == '/splash';
        final isPreloadValid =
            preload.status == PreloadStatus.success &&
            preload.entryId == auth.session?.entryId;

        if (isHome && !isPreloadValid) return '/splash';
        if (isSplash && isPreloadValid) return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(
        path: '/login/web',
        builder: (_, _) => const OfficialWebLoginPage(),
      ),
      GoRoute(path: '/preview', builder: (_, _) => const PublicMatchesPage()),
      GoRoute(
        path: '/team/:entryId',
        builder: (_, state) => TeamLookupPage(
          entryId: int.tryParse(state.pathParameters['entryId'] ?? ''),
        ),
      ),
      GoRoute(path: '/home', builder: (_, _) => const DashboardShell()),
    ],
  );
}

String? authRedirect(AuthState auth, String location) {
  final isSplash = location == '/splash';
  final isLogin = location == '/login';
  final isWebLogin = location == '/login/web';
  final isPreview = location == '/preview';
  final isPublicTeam = location.startsWith('/team/');

  if (auth is AuthInitial || auth.isLoading) {
    return isSplash || isLogin || isWebLogin || isPreview || isPublicTeam
        ? null
        : '/splash';
  }

  if (auth.session == null) {
    return isLogin || isWebLogin || isPreview || isPublicTeam ? null : '/login';
  }
  return isLogin || isWebLogin ? '/splash' : null;
}
