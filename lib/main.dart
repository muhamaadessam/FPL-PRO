import 'package:flutter/material.dart';
import 'core/app/app.dart';
import 'core/network/dio_helper.dart';
import 'core/storage/cache_helper.dart';
import 'features/auth/data/datasources/official_auth_client.dart';
import 'features/auth/data/datasources/session_store.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/fixtures/data/datasources/fpl_api_client.dart';
import 'features/fixtures/data/repositories/fixtures_repository_impl.dart';
import 'features/team/data/repositories/team_repository.dart';
import 'features/dashboard/presentation/cubit/home_preload_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CacheHelper.init();
  DioHelper.init();
  final apiClient = FplApiClient();
  final authClient = OfficialAuthClient(SessionStore());
  final authCubit = AuthCubit(AuthRepositoryImpl(authClient))..restoreSession();
  final fixturesRepo = FixturesRepositoryImpl(apiClient);
  final teamRepo = TeamRepositoryImpl(apiClient);
  final preloadCubit = HomePreloadCubit(
    fixturesRepository: fixturesRepo,
    teamRepository: teamRepo,
    authCubit: authCubit,
  );
  runApp(
    FantasyPlApp(
      authCubit: authCubit,
      preloadCubit: preloadCubit,
      fixturesRepository: fixturesRepo,
      teamRepository: teamRepo,
    ),
  );
}
