import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fantasy_pl/features/auth/domain/entities/official_session.dart';
import 'package:fantasy_pl/features/auth/domain/repositories/auth_repository.dart';
import 'package:fantasy_pl/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:fantasy_pl/features/fixtures/data/models/fpl_models.dart';
import 'package:fantasy_pl/features/fixtures/domain/repositories/fixtures_repository.dart';
import 'package:fantasy_pl/features/recommendations/presentation/screens/recommendations_view.dart';
import 'package:fantasy_pl/features/team/data/models/team_models.dart';
import 'package:fantasy_pl/features/team/domain/repositories/team_repository.dart';
import 'package:fantasy_pl/l10n/app_localizations.dart';

void main() {
  testWidgets('recommendations fit a narrow Arabic screen', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bootstrap = FplBootstrap.fromJson({
      'events': [
        {'id': 38, 'name': 'Gameweek 38', 'is_next': true},
      ],
      'teams': const [],
      'elements': const [],
    });
    final session = const OfficialSession(
      accessToken: 'test-token',
      entryId: 123,
    );

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<FixturesRepository>.value(
            value: _FakeFixturesRepository(bootstrap),
          ),
          RepositoryProvider<TeamRepository>.value(
            value: _FakeTeamRepository(),
          ),
        ],
        child: BlocProvider(
          create: (_) => AuthCubit(
            _FakeAuthRepository(session),
            initialState: AuthAuthenticated(session),
          ),
          child: MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: RecommendationsView()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('next-gameweek-analysis')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('next-gameweek-analysis')));
    await tester.pumpAndSettle();
    expect(find.text('تحليل الجولة القادمة'), findsOneWidget);
  });
}

class _FakeFixturesRepository implements FixturesRepository {
  const _FakeFixturesRepository(this.bootstrap);

  final FplBootstrap bootstrap;

  @override
  Future<FplBootstrap> getBootstrap() async => bootstrap;

  @override
  Future<List<FplFixture>> getFixtures({int? gameweekId}) async => const [];

  @override
  Future<Map<int, int>> getGameweekPoints(int gameweekId) async => const {};

  @override
  Future<Map<int, int>> getEntryHistoryPoints(int entryId) async => const {};

  @override
  Future<FplPlayerSummary> getPlayerSummary(int playerId) async =>
      const FplPlayerSummary();
}

class _FakeTeamRepository implements TeamRepository {
  _FakeTeamRepository([MyTeam? team])
    : team = team ?? MyTeam.fromJson(const {'entry_history': {}});

  final MyTeam team;

  @override
  Future<FplEntry> getEntry(int entryId) async =>
      FplEntry(id: entryId, name: 'Fake FC');

  @override
  Future<MyTeam> getMyTeam({
    required OfficialSession session,
    required int entryId,
    required int gameweekId,
  }) async => team;

  @override
  Future<MyTeam> getTeamForGameweek({
    required OfficialSession session,
    required int entryId,
    required int gameweekId,
    required int currentGameweekId,
  }) async => team;

  @override
  Future<MyTeam> getPublicTeam({
    required int entryId,
    required int gameweekId,
  }) async => team;

  @override
  Future<void> makeTransfer({
    required OfficialSession session,
    required int entryId,
    required int gameweekId,
    required int elementIn,
    required int elementOut,
    required int purchasePrice,
    required int sellingPrice,
  }) async {}

  @override
  Future<void> saveMyTeam({
    required OfficialSession session,
    required int entryId,
    required String? chip,
    required List<TeamPick> picks,
  }) async {}
}

class _FakeAuthRepository implements AuthRepository {
  const _FakeAuthRepository(this.session);

  final OfficialSession session;

  @override
  Future<OfficialSession?> restoreSession() async => session;

  @override
  Future<OfficialSession> signIn({
    Future<String> Function(Uri authorizationUri)? authenticate,
    Future<Map<String, String>> Function()? webSessionProvider,
  }) async => session;

  @override
  Future<void> logout() async {}
}
