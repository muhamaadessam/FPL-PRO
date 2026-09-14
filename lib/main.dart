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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CacheHelper.init();
  DioHelper.init();
  final apiClient = FplApiClient();
  final authClient = OfficialAuthClient(SessionStore());
  final authCubit = AuthCubit(AuthRepositoryImpl(authClient))..restoreSession();
  runApp(
    FantasyPlApp(
      authCubit: authCubit,
      fixturesRepository: FixturesRepositoryImpl(apiClient),
      teamRepository: TeamRepositoryImpl(apiClient),
    ),
  );
}
