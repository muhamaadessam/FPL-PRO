import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/screens/login_page.dart';
import '../../features/auth/presentation/screens/official_web_login_page.dart';
import '../../features/dashboard/presentation/screens/dashboard_shell.dart';
import '../../features/dashboard/presentation/cubit/home_preload_cubit.dart';
import '../../features/fixtures/presentation/screens/fixtures_view.dart';
import '../../features/leagues/presentation/screens/leagues_view.dart';
import '../../features/recommendations/presentation/screens/recommendations_view.dart';
import '../../features/settings/presentation/screens/settings_view.dart';
import '../../features/team/presentation/screens/manage_team_page.dart';
import 'package:fpl_engine/fpl_engine.dart';
import '../../features/team/presentation/screens/team_view.dart';
import '../widgets/splash_page.dart';
import '../widgets/update_checker.dart';
import 'routes.dart';
import '../layout/responsive.dart';

GoRouter createRouter(AuthCubit authCubit, HomePreloadCubit preloadCubit) {
  final refresh = ValueNotifier(0);
  authCubit.stream.listen((_) => refresh.value++);
  preloadCubit.stream.listen((_) => refresh.value++);
  // Pushed pages update the address bar too, so every page has a link.
  GoRouter.optionURLReflectsImperativeAPIs = true;

  /// Sub-pages handed over as `extra` cannot be rebuilt from the URL alone;
  /// a reload sends them back to [parent].
  GoRoute extraPage(String path, String parent) => GoRoute(
    path: path,
    redirect: (_, state) => state.extra is Widget ? null : parent,
    builder: (_, state) => SubPageFrame(child: state.extra! as Widget),
  );

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final auth = authCubit.state;
      final preload = preloadCubit.state;

      final authResult = authRedirect(auth, location);
      if (authResult == AppRoutes.splash && AppRoutes.isDashboard(location)) {
        return _splashFor(state.uri);
      }
      if (authResult != null) return authResult;

      if (auth.session != null) {
        final isPreloadValid =
            preload.status == PreloadStatus.success &&
            preload.entryId == auth.session?.entryId;

        // Load the team first, then come back to the page that was asked for.
        if (AppRoutes.isDashboard(location) && !isPreloadValid) {
          return _splashFor(state.uri);
        }
        if (location == AppRoutes.splash && isPreloadValid) {
          return splashDestination(state.uri);
        }
      }
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashPage()),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginPage()),
      GoRoute(
        path: AppRoutes.loginWeb,
        builder: (_, _) => const OfficialWebLoginPage(),
      ),
      GoRoute(
        path: '/team/:entryId',
        builder: (_, state) => SubPageFrame(
          child: TeamLookupPage(
            entryId: int.tryParse(state.pathParameters['entryId'] ?? ''),
          ),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) => UpdateChecker(
          child: DashboardShell(navigationShell: navigationShell),
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (_, _) => const TeamView(),
                routes: [
                  GoRoute(
                    path: 'manage',
                    builder: (_, _) =>
                        const SubPageFrame(child: ManageTeamPage()),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.tips,
                builder: (_, _) => const RecommendationsView(),
                routes: [
                  extraPage('analysis', AppRoutes.tips),
                  extraPage('players', AppRoutes.tips),
                  extraPage('compare', AppRoutes.tips),
                  extraPage('news', AppRoutes.tips),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.matches,
                builder: (_, _) => const FixturesView(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.leagues,
                builder: (_, _) => const LeaguesView(),
                routes: [
                  GoRoute(
                    path: ':leagueId',
                    redirect: (_, state) =>
                        _leagueFor(state, preloadCubit) == null
                        ? AppRoutes.leagues
                        : null,
                    builder: (_, state) => SubPageFrame(
                      maxWidth: leaguesMaxWidth,
                      child: LeagueDetailsPage(
                        league: _leagueFor(state, preloadCubit)!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (_, _) => const SettingsView(),
                routes: [
                  GoRoute(
                    path: 'privacy',
                    builder: (_, _) =>
                        const SubPageFrame(child: PrivacyPolicyPage()),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// Centres a sub-page, app bar included, in the content column on wide
/// screens, so its back button lines up with the content below the top nav.
class SubPageFrame extends StatelessWidget {
  const SubPageFrame({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.content,
  });

  final Widget child;

  /// Match the page's own content width so the app bar lines up with it.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = math.min(media.size.width, maxWidth);
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: SizedBox(
          width: width,
          // Pages size their content from the screen width, so they see the
          // frame's width instead of the whole window.
          child: MediaQuery(
            data: media.copyWith(size: Size(width, media.size.height)),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The league in `extra`, or the one with the URL's id from the loaded entry.
FplLeague? _leagueFor(GoRouterState state, HomePreloadCubit preloadCubit) {
  final extra = state.extra;
  if (extra is FplLeague) return extra;
  final id = int.tryParse(state.pathParameters['leagueId'] ?? '');
  if (id == null) return null;
  for (final league in preloadCubit.state.entry?.leagues ?? const []) {
    if (league.id == id) return league;
  }
  return null;
}

/// The splash screen, remembering [target] to open once the team is loaded.
String _splashFor(Uri target) => Uri(
  path: AppRoutes.splash,
  queryParameters: {'from': target.toString()},
).toString();

/// Where the splash screen goes once the team is loaded: the dashboard page
/// that was asked for, or the home tab.
String splashDestination(Uri splashUri) {
  final from = splashUri.queryParameters['from'];
  if (from != null &&
      from.startsWith('/') &&
      !from.startsWith('//') &&
      AppRoutes.isDashboard(Uri.parse(from).path)) {
    return from;
  }
  return AppRoutes.home;
}

String? authRedirect(AuthState auth, String location) {
  final isSplash = location == AppRoutes.splash;
  final isLogin = location == AppRoutes.login;
  final isWebLogin = location == AppRoutes.loginWeb;
  final isPublicTeam = location.startsWith('/team/');

  if (auth is AuthInitial || auth.isLoading) {
    return isSplash || isLogin || isWebLogin || isPublicTeam
        ? null
        : AppRoutes.splash;
  }

  if (auth.session == null) {
    return isLogin || isWebLogin || isPublicTeam ? null : AppRoutes.login;
  }
  return isLogin || isWebLogin ? AppRoutes.splash : null;
}
