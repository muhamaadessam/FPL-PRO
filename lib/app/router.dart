import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/official_web_login_page.dart';
import '../features/dashboard/presentation/dashboard_shell.dart';
import '../features/fixtures/presentation/public_matches_page.dart';
import '../features/team/presentation/team_view.dart';
import 'splash_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;
      final isSplash = location == '/splash';
      final isLogin = location == '/login';
      final isWebLogin = location == '/login/web';
      final isPreview = location == '/preview';
      final isPublicTeam = location.startsWith('/team/');

      if (auth.isLoading && !auth.hasValue) {
        return isSplash || isWebLogin ? null : '/splash';
      }

      final session = auth.value;
      if (session == null) {
        return isLogin || isWebLogin || isPreview || isPublicTeam
            ? null
            : '/login';
      }
      return isSplash || isLogin || isWebLogin ? '/home' : null;
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
});
