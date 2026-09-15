import 'package:flutter_test/flutter_test.dart';

import 'package:fantasy_pl/features/auth/domain/entities/official_session.dart';
import 'package:fantasy_pl/features/auth/domain/repositories/auth_repository.dart';
import 'package:fantasy_pl/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:fantasy_pl/features/dashboard/presentation/cubit/home_preload_cubit.dart';
import 'package:fantasy_pl/features/fixtures/data/models/fpl_models.dart';
import 'package:fantasy_pl/features/fixtures/domain/repositories/fixtures_repository.dart';
import 'package:fantasy_pl/features/team/data/models/team_models.dart';
import 'package:fantasy_pl/features/team/domain/repositories/team_repository.dart';

void main() {
  test(
    'preloads current and next home data once and keeps history optional',
    () async {
      final session = const OfficialSession(accessToken: 'token', entryId: 42);
      final authCubit = AuthCubit(
        _FakeAuthRepository(session),
        initialState: AuthAuthenticated(session),
      );
      final fixturesRepository = _FakeFixturesRepository();
      final teamRepository = _FakeTeamRepository();
      final cubit = HomePreloadCubit(
        fixturesRepository: fixturesRepository,
        teamRepository: teamRepository,
        authCubit: authCubit,
      );

      await Future.wait([cubit.load(), cubit.load()]);

      expect(cubit.state.status, PreloadStatus.success);
      expect(cubit.state.entryId, 42);
      expect(teamRepository.currentRequests, [4]);
      expect(teamRepository.nextRequests, [5]);
      expect(fixturesRepository.fixtureRequests, [null]);
      expect(cubit.state.currentGameweekFixtures.map((fixture) => fixture.id), [
        1,
      ]);
      expect(cubit.state.teamCurrent, same(teamRepository.currentTeam));
      expect(cubit.state.teamNext, same(teamRepository.nextTeam));
      expect(cubit.state.playerSummaries.keys, {10});
      expect(cubit.state.historyPoints, isEmpty);
      expect(cubit.state.entry?.name, 'Fake FC');
    },
  );
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

class _FakeFixturesRepository implements FixturesRepository {
  final fixtureRequests = <int?>[];

  final _bootstrap = FplBootstrap.fromJson({
    'events': [
      {'id': 4, 'name': 'Gameweek 4', 'is_current': true},
      {'id': 5, 'name': 'Gameweek 5', 'is_next': true},
    ],
    'elements': [
      {'id': 10, 'web_name': 'Player', 'team': 1, 'element_type': 4},
    ],
  });

  final _fixtures = [
    FplFixture(
      id: 1,
      gameweekId: 4,
      homeTeamId: 1,
      awayTeamId: 2,
      kickoffTime: null,
      finished: false,
      started: false,
    ),
    FplFixture(
      id: 2,
      gameweekId: 5,
      homeTeamId: 1,
      awayTeamId: 2,
      kickoffTime: null,
      finished: false,
      started: false,
    ),
  ];

  @override
  Future<FplBootstrap> getBootstrap() async => _bootstrap;

  @override
  Future<List<FplFixture>> getFixtures({int? gameweekId}) async {
    fixtureRequests.add(gameweekId);
    return _fixtures;
  }

  @override
  Future<Map<int, int>> getGameweekPoints(int gameweekId) async => {10: 7};

  @override
  Future<Map<int, int>> getEntryHistoryPoints(int entryId) async {
    throw StateError('history is supplementary');
  }

  @override
  Future<FplPlayerSummary> getPlayerSummary(int playerId) async =>
      const FplPlayerSummary();
}

class _FakeTeamRepository implements TeamRepository {
  final currentRequests = <int>[];
  final nextRequests = <int>[];

  final currentTeam = MyTeam.fromJson({
    'picks': [
      {
        'element': 10,
        'position': 1,
        'multiplier': 1,
        'is_captain': false,
        'element_type': 4,
      },
    ],
    'entry_history': {'event': 4},
  });

  final nextTeam = MyTeam.fromJson({
    'picks': [
      {
        'element': 10,
        'position': 1,
        'multiplier': 1,
        'is_captain': false,
        'element_type': 4,
      },
    ],
    'entry_history': {'event': 5},
  });

  @override
  Future<FplEntry> getEntry(int entryId) async =>
      FplEntry(id: entryId, name: 'Fake FC');

  @override
  Future<FplLeagueDetails> getLeagueStandings({
    required FplLeague league,
  }) async => FplLeagueDetails(league: league, standings: const []);

  @override
  Future<MyTeam> getTeamForGameweek({
    required OfficialSession session,
    required int entryId,
    required int gameweekId,
    required int currentGameweekId,
  }) async {
    currentRequests.add(gameweekId);
    return currentTeam;
  }

  @override
  Future<MyTeam> getMyTeam({
    required OfficialSession session,
    required int entryId,
    required int gameweekId,
  }) async {
    nextRequests.add(gameweekId);
    return nextTeam;
  }

  @override
  Future<MyTeam> getPublicTeam({
    required int entryId,
    required int gameweekId,
  }) async => currentTeam;

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
