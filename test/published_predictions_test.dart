import 'package:flutter_test/flutter_test.dart';

import 'package:fantasy_pl/features/auth/domain/entities/official_session.dart';
import 'package:fantasy_pl/features/auth/domain/repositories/auth_repository.dart';
import 'package:fantasy_pl/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:fantasy_pl/features/fixtures/domain/repositories/fixtures_repository.dart';
import 'package:fantasy_pl/features/fixtures/presentation/cubit/fixtures_cubit.dart';
import 'package:fantasy_pl/features/recommendations/presentation/cubit/recommendations_cubit.dart';
import 'package:fantasy_pl/features/team/domain/repositories/team_repository.dart';
import 'package:fpl_engine/fpl_engine.dart';

void main() {
  final bootstrap = FplBootstrap.fromJson({
    'events': [
      {'id': 4, 'name': 'Gameweek 4', 'is_current': true, 'finished': true},
      {'id': 5, 'name': 'Gameweek 5', 'is_next': true},
    ],
    'teams': [
      {'id': 1, 'name': 'Home', 'short_name': 'HOM'},
      {'id': 2, 'name': 'Away', 'short_name': 'AWY'},
    ],
    'elements': [
      {'id': 10, 'web_name': 'Striker', 'team': 1, 'element_type': 4},
      {'id': 20, 'web_name': 'Winger', 'team': 2, 'element_type': 3},
    ],
  });
  final fixtures = [
    FplFixture.fromJson({'id': 1, 'event': 5, 'team_h': 1, 'team_a': 2}),
  ];
  const published = FixturePrediction(
    homeGoals: 7,
    awayGoals: 0,
    homeCleanSheetChance: 99,
    awayCleanSheetChance: 0,
    confidence: 99,
    scorers: [],
    assists: [],
  );

  group('FixturesCubit', () {
    test('shows the published predictions when they are current', () async {
      final repository = _FakeFixturesRepository(bootstrap, fixtures)
        ..fixturePredictions = PublishedFixturePredictions(
          generatedAt: DateTime.now(),
          fromGameweekId: 4,
          predictions: const {1: published},
        );
      final cubit = FixturesCubit(repository);

      await cubit.load();

      expect(cubit.state.predictions![1]!.homeGoals, 7);
    });

    test('computes on device when the published file is stale', () async {
      final repository = _FakeFixturesRepository(bootstrap, fixtures)
        ..fixturePredictions = PublishedFixturePredictions(
          generatedAt: DateTime.now().subtract(const Duration(days: 3)),
          fromGameweekId: 4,
          predictions: const {1: published},
        );
      final cubit = FixturesCubit(repository);

      await cubit.load();

      expect(cubit.state.predictions!.keys, [1]);
      expect(cubit.state.predictions![1]!.homeGoals, isNot(7));
    });

    test('computes on device when nothing is published', () async {
      final cubit = FixturesCubit(_FakeFixturesRepository(bootstrap, fixtures));

      await cubit.load();

      expect(cubit.state.status, FixturesStatus.success);
      expect(cubit.state.predictions!.keys, [1]);
    });
  });

  group('RecommendationsCubit', () {
    RecommendationsCubit cubitFor(FixturesRepository repository) {
      const session = OfficialSession(accessToken: 'token', entryId: 123);
      return RecommendationsCubit(
        fixturesRepository: repository,
        teamRepository: _FakeTeamRepository(),
        authCubit: AuthCubit(
          const _FakeAuthRepository(session),
          initialState: const AuthAuthenticated(session),
        ),
      );
    }

    test('uses published projections and skips the live minutes', () async {
      final repository = _FakeFixturesRepository(bootstrap, fixtures)
        ..playerProjections = PublishedPlayerProjections(
          generatedAt: DateTime.now(),
          gameweekId: 5,
          projections: [
            for (final player in bootstrap.players.values)
              PlayerProjection(
                player: player,
                nextPoints: player.id / 2,
                horizonPoints: player.id.toDouble(),
                availability: 1,
                nextFixtureCount: 1,
                nextDifficulties: const [3],
              ),
          ],
        );
      final cubit = cubitFor(repository);

      await cubit.load();

      expect(cubit.state.status, RecommendationsStatus.success);
      expect(cubit.state.data!.projections.map((p) => p.nextPoints), [
        5.0,
        10.0,
      ]);
      expect(repository.minutesRequests, isEmpty);
    });

    test('computes projections on device for another Gameweek', () async {
      final repository = _FakeFixturesRepository(bootstrap, fixtures)
        ..playerProjections = PublishedPlayerProjections(
          generatedAt: DateTime.now(),
          gameweekId: 4,
          projections: const [],
        );
      final cubit = cubitFor(repository);

      await cubit.load();

      expect(cubit.state.status, RecommendationsStatus.success);
      expect(cubit.state.data!.projections, hasLength(2));
      expect(repository.minutesRequests, [4]);
    });
  });
}

class _FakeFixturesRepository implements FixturesRepository {
  _FakeFixturesRepository(this.bootstrap, this.fixtures);

  final FplBootstrap bootstrap;
  final List<FplFixture> fixtures;
  PublishedFixturePredictions? fixturePredictions;
  PublishedPlayerProjections? playerProjections;
  final minutesRequests = <int>[];

  @override
  Future<FplBootstrap> getBootstrap() async => bootstrap;

  @override
  Future<List<FplFixture>> getFixtures({int? gameweekId}) async => fixtures;

  @override
  Future<Map<int, int>> getGameweekPoints(int gameweekId) async => const {};

  @override
  Future<Map<int, int>> getGameweekMinutes(int gameweekId) async {
    minutesRequests.add(gameweekId);
    return const {};
  }

  @override
  Future<Map<int, int>> getEntryHistoryPoints(int entryId) async => const {};

  @override
  Future<FplPlayerSummary> getPlayerSummary(int playerId) async =>
      const FplPlayerSummary();

  @override
  Future<PublishedFixturePredictions?> getPublishedFixturePredictions(
    Map<int, FplPlayer> players,
  ) async => fixturePredictions;

  @override
  Future<PublishedPlayerProjections?> getPublishedPlayerProjections(
    Map<int, FplPlayer> players,
  ) async => playerProjections;
}

class _FakeTeamRepository implements TeamRepository {
  @override
  Future<MyTeam> getMyTeam({
    required OfficialSession session,
    required int entryId,
    required int gameweekId,
  }) async => MyTeam.fromJson(const {
    'picks': [
      {'element': 10, 'position': 1, 'is_captain': true},
    ],
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeAuthRepository implements AuthRepository {
  const _FakeAuthRepository(this.session);

  final OfficialSession session;

  @override
  Future<OfficialSession?> restoreSession() async => session;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
