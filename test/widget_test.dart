import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

import 'package:fantasy_pl/core/app/app.dart';
import 'package:fantasy_pl/features/auth/data/datasources/session_store.dart';
import 'package:fantasy_pl/features/auth/data/datasources/official_auth_client.dart';
import 'package:fantasy_pl/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:fantasy_pl/features/auth/domain/entities/official_session.dart';
import 'package:fantasy_pl/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:fantasy_pl/features/fixtures/data/datasources/fpl_api_client.dart';
import 'package:fantasy_pl/features/fixtures/data/repositories/fixtures_repository_impl.dart';
import 'package:fantasy_pl/features/team/data/repositories/team_repository.dart';
import 'package:fantasy_pl/features/dashboard/presentation/cubit/home_preload_cubit.dart';

void main() {
  testWidgets('team lookup page exposes public team access', (tester) async {
    final apiClient = FplApiClient(dio: Dio());
    final authCubit = AuthCubit(AuthRepositoryImpl(_FakeAuthClient()))
      ..restoreSession();
    final fixturesRepo = FixturesRepositoryImpl(apiClient);
    final teamRepo = TeamRepositoryImpl(apiClient);
    final preloadCubit = HomePreloadCubit(
      fixturesRepository: fixturesRepo,
      teamRepository: teamRepo,
      authCubit: authCubit,
    );
    await tester.pumpWidget(
      FantasyPlApp(
        authCubit: authCubit,
        preloadCubit: preloadCubit,
        fixturesRepository: fixturesRepo,
        teamRepository: teamRepo,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Open your team'), findsOneWidget);
    expect(find.text('Sign in officially'), findsOneWidget);
    expect(find.text('Open my team'), findsOneWidget);
    expect(find.text('Browse public matches'), findsOneWidget);
  });
}

class _FakeAuthClient extends OfficialAuthClient {
  _FakeAuthClient() : super(SessionStore());

  @override
  Future<OfficialSession?> restoreSession() async => null;
}
