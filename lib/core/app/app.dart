import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/fixtures/domain/repositories/fixtures_repository.dart';
import '../../features/team/domain/repositories/team_repository.dart';
import '../localization/cubit/locale_cubit.dart';
import '../../l10n/app_localizations.dart';
import 'router.dart';
import '../themes/theme.dart';
import '../themes/cubit/theme_cubit.dart';
import '../../features/dashboard/presentation/cubit/home_preload_cubit.dart';

class FantasyPlApp extends StatelessWidget {
  FantasyPlApp({
    super.key,
    required this.authCubit,
    required this.preloadCubit,
    required this.fixturesRepository,
    required this.teamRepository,
  }) : _router = createRouter(authCubit, preloadCubit);

  final AuthCubit authCubit;
  final HomePreloadCubit preloadCubit;
  final FixturesRepository fixturesRepository;
  final TeamRepository teamRepository;
  final RouterConfig<Object> _router;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: fixturesRepository),
        RepositoryProvider.value(value: teamRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: authCubit),
          BlocProvider(create: (_) => LocaleCubit()),
          BlocProvider(create: (_) => ThemeCubit()),
          BlocProvider.value(value: preloadCubit),
        ],
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, themeMode) {
            return BlocBuilder<LocaleCubit, Locale>(
              builder: (context, locale) {
                return MaterialApp.router(
                  title: 'FPL Pro',
                  debugShowCheckedModeBanner: false,
                  theme: buildLightTheme(),
                  darkTheme: buildDarkTheme(),
                  themeMode: themeMode,
                  locale: locale,
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  localeResolutionCallback: (deviceLocale, supportedLocales) {
                    final language = deviceLocale?.languageCode ?? 'en';
                    return supportedLocales.firstWhere(
                      (supported) => supported.languageCode == language,
                      orElse: () => const Locale('en'),
                    );
                  },
                  routerConfig: _router,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
