import 'dart:convert';

import 'package:fpl_engine/fpl_engine.dart';
import 'package:test/test.dart';

void main() {
  const teams = {
    1: FplTeam(id: 1, name: 'Home', shortName: 'HOM'),
    2: FplTeam(id: 2, name: 'Away', shortName: 'AWY'),
  };
  const players = {
    1: FplPlayer(
      id: 1,
      webName: 'Striker',
      teamId: 1,
      positionId: 4,
      minutes: 900,
      expectedGoals: 6,
      expectedAssists: 1,
      nowCost: 90,
    ),
    2: FplPlayer(
      id: 2,
      webName: 'Winger',
      teamId: 2,
      positionId: 3,
      minutes: 800,
      expectedGoals: 2,
      expectedAssists: 4,
      nowCost: 70,
    ),
  };
  final generatedAt = DateTime.utc(2026, 10, 17, 12);
  const gameweeks = [
    Gameweek(
      id: 7,
      name: 'Gameweek 7',
      deadlineTime: null,
      isCurrent: true,
      isNext: false,
      finished: true,
    ),
    Gameweek(
      id: 8,
      name: 'Gameweek 8',
      deadlineTime: null,
      isCurrent: false,
      isNext: true,
      finished: false,
    ),
  ];
  const bootstrap = FplBootstrap(
    gameweeks: gameweeks,
    teams: teams,
    players: players,
  );
  const fixtures = [
    FplFixture(
      id: 10,
      gameweekId: 8,
      homeTeamId: 1,
      awayTeamId: 2,
      kickoffTime: null,
      finished: false,
      started: false,
    ),
    FplFixture(
      id: 11,
      gameweekId: 8,
      homeTeamId: 2,
      awayTeamId: 1,
      kickoffTime: null,
      finished: false,
      started: false,
    ),
  ];

  Object? roundTrip(Map<String, dynamic> json) => jsonDecode(jsonEncode(json));

  test('match predictions survive a JSON round trip', () {
    final predicted = const FixturePredictionEngine().predictNextGameweeks(
      fixtures: fixtures,
      teams: teams,
      players: players,
      fromGameweekId: 7,
    );
    final published = PublishedFixturePredictions(
      generatedAt: generatedAt,
      fromGameweekId: 7,
      predictions: predicted,
    );

    final read = PublishedFixturePredictions.fromJson(
      roundTrip(published.toJson()),
      players,
    )!;

    expect(read.fromGameweekId, 7);
    expect(read.generatedAt, generatedAt);
    expect(read.predictions.keys, predicted.keys);
    final original = predicted[10]!;
    final copy = read.predictions[10]!;
    expect(copy.homeGoals, original.homeGoals);
    expect(copy.homeWinChance, original.homeWinChance);
    expect(copy.homeExpectedGoals, closeTo(original.homeExpectedGoals, 1e-3));
    expect(
      copy.scorers.map((e) => (e.player.id, e.chance)),
      original.scorers.map((e) => (e.player.id, e.chance)),
    );
    expect(identical(copy.homeScorers.first.player, players[1]), isTrue);
  });

  test('player projections survive a JSON round trip', () {
    final projections = const RecommendationEngine().buildPlayerProjections(
      bootstrap: bootstrap,
      fixtures: fixtures,
      gameweekId: 8,
    );
    final published = PublishedPlayerProjections(
      generatedAt: generatedAt,
      gameweekId: 8,
      projections: projections,
    );

    final read = PublishedPlayerProjections.fromJson(
      roundTrip(published.toJson()),
      players,
    )!;

    expect(read.gameweekId, 8);
    expect(
      read.projections.map((p) => p.player.id),
      projections.map((p) => p.player.id),
    );
    for (var i = 0; i < projections.length; i++) {
      expect(
        read.projections[i].nextPoints,
        closeTo(projections[i].nextPoints, 1e-3),
      );
      expect(read.projections[i].nextDifficulties, [
        ...projections[i].nextDifficulties,
      ]);
    }
  });

  test(
    'rejects other schema versions, malformed files and missing players',
    () {
      final json = PublishedPlayerProjections(
        generatedAt: generatedAt,
        gameweekId: 8,
        projections: const RecommendationEngine().buildPlayerProjections(
          bootstrap: bootstrap,
          fixtures: fixtures,
          gameweekId: 8,
        ),
      ).toJson();

      expect(
        PublishedPlayerProjections.fromJson({
          ...json,
          'schemaVersion': 2,
        }, players),
        isNull,
      );
      expect(PublishedPlayerProjections.fromJson('<html>', players), isNull);
      expect(PublishedFixturePredictions.fromJson({}, players), isNull);
      expect(
        PublishedPlayerProjections.fromJson(roundTrip(json), {
          ...players,
          3: const FplPlayer(id: 3, webName: 'New', teamId: 1, positionId: 2),
        }),
        isNull,
      );
    },
  );

  test('is only used for the same Gameweek while fresh', () {
    final published = PublishedPlayerProjections(
      generatedAt: generatedAt,
      gameweekId: 8,
      projections: const [],
    );
    final soon = generatedAt.add(const Duration(hours: 6));

    expect(published.usableFor(8, now: soon), isEmpty);
    expect(published.usableFor(9, now: soon), isNull);
    expect(
      published.usableFor(8, now: generatedAt.add(const Duration(days: 2))),
      isNull,
    );
  });

  test('drops predictions for fixtures that have since kicked off', () {
    final predicted = const FixturePredictionEngine().predictNextGameweeks(
      fixtures: fixtures,
      teams: teams,
      players: players,
      fromGameweekId: 7,
    );
    final published = PublishedFixturePredictions(
      generatedAt: generatedAt,
      fromGameweekId: 7,
      predictions: predicted,
    );
    final now = generatedAt.add(const Duration(hours: 1));

    final usable = published.usableFor(
      bootstrap: bootstrap,
      fixtures: [
        const FplFixture(
          id: 10,
          gameweekId: 8,
          homeTeamId: 1,
          awayTeamId: 2,
          kickoffTime: null,
          finished: false,
          started: true,
        ),
        fixtures[1],
      ],
      now: now,
    );

    expect(usable!.keys, [11]);
    expect(
      published.usableFor(
        bootstrap: const FplBootstrap(
          gameweeks: [],
          teams: teams,
          players: players,
        ),
        fixtures: fixtures,
        now: now,
      ),
      isNull,
    );
  });

  test('projectionGameweekId is the next deadline', () {
    expect(projectionGameweekId(bootstrap), 8);
  });
}
