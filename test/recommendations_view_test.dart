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
import 'package:fantasy_pl/features/team/presentation/widgets/pitch_view.dart';

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
    await tester.pumpWidget(
      _recommendationsApp(
        _FakeFixturesRepository(bootstrap),
        _FakeTeamRepository(),
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

  testWidgets(
    'weekly plan refreshes for a new gameweek and previews without writes',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final positions = [1, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 1, 2, 2, 3];
      FplBootstrap bootstrap(int gw) => FplBootstrap.fromJson({
        'events': [
          {'id': gw, 'name': 'Gameweek $gw', 'is_next': true},
        ],
        'teams': [
          {'id': 1, 'name': 'Arsenal', 'short_name': 'ARS'},
        ],
        'elements': [
          for (var i = 0; i < positions.length; i++)
            {
              'id': i + 1,
              'web_name': 'Player ${i + 1}',
              'team': 1,
              'element_type': positions[i],
              'now_cost': 60,
              'minutes': 360,
              'starts': 4,
              'form': i == 14 ? '10' : '4',
              'points_per_game': '4',
            },
        ],
      });
      final fixtures = _FakeFixturesRepository(bootstrap(5));
      fixtures.fixtures = [
        for (final gw in [5, 6])
          FplFixture.fromJson({
            'id': gw,
            'event': gw,
            'team_h': 1,
            'team_a': 2,
          }),
      ];
      final team = _FakeTeamRepository(
        MyTeam.fromJson({
          'picks': [
            for (var i = 0; i < positions.length; i++)
              {'element': i + 1, 'position': i + 1, 'is_captain': i == 8},
          ],
        }),
      );
      await tester.pumpWidget(_recommendationsApp(fixtures, team));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('weekly-plan')), findsOneWidget);
      expect(find.textContaining('ابدأ بـ: Player 15'), findsOneWidget);
      expect(tester.takeException(), isNull);

      fixtures.bootstrap = bootstrap(6);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(team.requestedGameweeks, [5, 6]);
      expect(find.text('Gameweek 6'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('suggested-lineup-preview')));
      await tester.pumpAndSettle();
      final pitch = tester.widget<PitchView>(find.byType(PitchView));
      expect(pitch.starting, hasLength(11));
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _recommendationsApp(FixturesRepository fixtures, TeamRepository team) {
  const session = OfficialSession(accessToken: 'test-token', entryId: 123);
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<FixturesRepository>.value(value: fixtures),
      RepositoryProvider<TeamRepository>.value(value: team),
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
  );
}

class _FakeFixturesRepository implements FixturesRepository {
  _FakeFixturesRepository(this.bootstrap);

  FplBootstrap bootstrap;
  List<FplFixture> fixtures = const [];

  @override
  Future<FplBootstrap> getBootstrap() async => bootstrap;

  @override
  Future<List<FplFixture>> getFixtures({int? gameweekId}) async => fixtures;

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
  final requestedGameweeks = <int>[];
  int writeCalls = 0;

  @override
  Future<FplEntry> getEntry(int entryId) async =>
      FplEntry(id: entryId, name: 'Fake FC');

  @override
  Future<FplLeagueDetails> getLeagueStandings({
    required FplLeague league,
    int page = 1,
  }) async => FplLeagueDetails(
    league: league,
    standings: const [],
    page: page,
    hasNext: false,
  );

  @override
  Future<MyTeam> getMyTeam({
    required OfficialSession session,
    required int entryId,
    required int gameweekId,
  }) async {
    requestedGameweeks.add(gameweekId);
    return team;
  }

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
  }) async {
    writeCalls++;
  }

  @override
  Future<void> saveMyTeam({
    required OfficialSession session,
    required int entryId,
    required String? chip,
    required List<TeamPick> picks,
  }) async {
    writeCalls++;
  }
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
