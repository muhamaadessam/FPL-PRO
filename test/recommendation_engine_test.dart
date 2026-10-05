import 'package:flutter_test/flutter_test.dart';

import 'package:fantasy_pl/core/models/fpl_models.dart';
import 'package:fantasy_pl/features/recommendations/domain/recommendation_engine.dart';

void main() {
  test('recommends an affordable same-position transfer and captain', () {
    final bootstrap = _bootstrap([
      _player(1, 'Weak Mid', 1, 3, 70, 1),
      _player(2, 'Strong Mid', 2, 3, 75, 8),
      _player(3, 'Captain', 3, 4, 100, 10),
    ]);
    final team = MyTeam.fromJson({
      'picks': [
        {'element': 1, 'position': 1, 'element_type': 3, 'selling_price': 70},
        {'element': 3, 'position': 2, 'element_type': 4},
      ],
      'transfers': {'bank': 10, 'limit': 1, 'made': 1},
      'chips': [
        {
          'name': '3xc',
          'status_for_entry': 'available',
          'start_event': 1,
          'stop_event': 19,
        },
      ],
    });

    final result = const RecommendationEngine().build(
      bootstrap: bootstrap,
      fixtures: [
        _fixture(5, 1, 2),
        _fixture(5, 3, 4),
        _fixture(6, 1, 2),
        _fixture(6, 3, 4),
        _fixture(7, 1, 2),
        _fixture(7, 3, 4),
      ],
      team: team,
      gameweekId: 5,
    );

    expect(result.captain?.player.id, 3);
    expect(
      result.transfers.any(
        (transfer) => transfer.outPlayer.id == 1 && transfer.inPlayer.id == 2,
      ),
      isTrue,
    );
    expect(result.freeTransfers, 0);
    expect(result.transfers.first.hitCost, 4);
    expect(result.chip, SuggestedChip.tripleCaptain);
  });

  test('recommends free hit when four starters have no fixture', () {
    final bootstrap = _bootstrap([
      for (var id = 1; id <= 5; id++)
        _player(id, 'Player $id', id, id == 5 ? 4 : 3, 60, 5),
    ]);
    final team = MyTeam.fromJson({
      'picks': [
        for (var id = 1; id <= 5; id++)
          {'element': id, 'position': id, 'element_type': id == 5 ? 4 : 3},
      ],
      'chips': [
        {
          'name': 'freehit',
          'status_for_entry': 'available',
          'start_event': 2,
          'stop_event': 19,
        },
      ],
    });

    final result = const RecommendationEngine().build(
      bootstrap: bootstrap,
      fixtures: [_fixture(5, 5, 20)],
      team: team,
      gameweekId: 5,
    );

    expect(result.chip, SuggestedChip.freeHit);
    expect(result.chipReason, ChipReason.missingStarters);
  });

  group('projection', () {
    test('does not scale ep_next by Double Gameweek fixtures again', () {
      final result = _build(
        players: [_player(1, 'Double', 1, 3, 80, 4, epNext: 8)],
        picks: [_pick(1, 1, 3)],
        fixtures: [_fixture(5, 1, 2), _fixture(5, 3, 1)],
      );

      // 8 * 0.6 from ep_next plus 4 points * two fixtures * 0.4 from form.
      expect(result.captain?.nextPoints, closeTo(8.0, 0.001));
      expect(result.captain?.nextFixtureCount, 2);
    });

    test('applies chance of playing to the form part only', () {
      final result = _build(
        players: [_player(1, 'Doubtful', 1, 3, 80, 6, epNext: 3, chance: 50)],
        picks: [_pick(1, 1, 3)],
        fixtures: [_fixture(5, 1, 2)],
      );

      // ep_next already priced in the 50% chance: 3 * 0.6 + 6 * 0.5 * 0.4.
      expect(result.captain?.nextPoints, closeTo(3.0, 0.001));
    });
  });

  group('transfer plan', () {
    test('charges a hit for every transfer beyond the free ones', () {
      final result = _build(
        players: [
          for (var id = 1; id <= 3; id++) _player(id, 'Weak $id', id, 3, 50, 1),
          for (var id = 4; id <= 6; id++)
            _player(id, 'Strong $id', id, 3, 50, 8),
        ],
        picks: [for (var id = 1; id <= 3; id++) _pick(id, id, 3)],
        transfers: {'bank': 0, 'limit': 1, 'made': 0},
        fixtures: _fixturesFor(teams: [1, 2, 3, 4, 5, 6]),
      );

      expect(result.freeTransfers, 1);
      expect(result.transfers.map((transfer) => transfer.hitCost), [0, 4, 4]);
    });

    test('treats unknown free transfers as paid', () {
      final result = _build(
        players: [
          _player(1, 'Weak', 1, 3, 50, 1),
          _player(2, 'Strong', 2, 3, 50, 8),
        ],
        picks: [_pick(1, 1, 3)],
        fixtures: _fixturesFor(teams: [1, 2]),
      );

      expect(result.freeTransfers, isNull);
      expect(result.transfers.single.hitCost, 4);
    });

    test('shares one bank across the whole plan', () {
      final result = _build(
        players: [
          _player(1, 'Weak Mid', 1, 3, 50, 1),
          _player(2, 'Weak Fwd', 2, 4, 50, 1),
          _player(3, 'Strong Mid', 3, 3, 60, 8),
          _player(4, 'Strong Fwd', 4, 4, 60, 8),
        ],
        picks: [_pick(1, 1, 3), _pick(2, 2, 4)],
        transfers: {'bank': 10, 'limit': 2, 'made': 0},
        fixtures: _fixturesFor(teams: [1, 2, 3, 4]),
      );

      // Each move alone fits the £1.0m bank, but not both together.
      expect(result.transfers, hasLength(1));
    });

    test('keeps the three-per-club limit across the whole plan', () {
      final result = _build(
        players: [
          _player(1, 'Weak Mid', 1, 3, 50, 1),
          _player(2, 'Weak Fwd', 2, 4, 50, 1),
          _player(3, 'Club Def A', 9, 2, 50, 5),
          _player(4, 'Club Def B', 9, 2, 50, 5),
          _player(5, 'Club Mid', 9, 3, 50, 8),
          _player(6, 'Club Fwd', 9, 4, 50, 8),
        ],
        picks: [_pick(1, 1, 3), _pick(2, 2, 4), _pick(3, 3, 2), _pick(4, 4, 2)],
        transfers: {'bank': 0, 'limit': 2, 'made': 0},
        fixtures: _fixturesFor(teams: [1, 2, 9]),
      );

      // Either move alone leaves three from club 9; both would make four.
      expect(result.transfers, hasLength(1));
      expect(result.transfers.single.inPlayer.teamId, 9);
    });

    test('weights bench upgrades and values rolling a free transfer', () {
      List<TransferSuggestion> transfersFor({
        required int position,
        required int made,
      }) {
        return _build(
          players: [
            _player(1, 'Weak', 1, 3, 50, 1),
            _player(2, 'Better', 2, 3, 50, 4),
          ],
          picks: [_pick(1, position, 3)],
          transfers: {'bank': 0, 'limit': 5, 'made': made},
          fixtures: _fixturesFor(teams: [1, 2]),
        ).transfers;
      }

      // A raw 6.15 gain is worth 1.85 from the bench: below the roll value.
      expect(transfersFor(position: 12, made: 4), isEmpty);
      expect(transfersFor(position: 1, made: 4), hasLength(1));
      // At five saved transfers, rolling would waste one.
      expect(transfersFor(position: 12, made: 0), hasLength(1));
    });
  });

  group('chips', () {
    test('does not wildcard just because the bench is fodder', () {
      final result = _build(
        players: [
          for (var id = 1; id <= 10; id++)
            _player(id, 'Starter $id', id, 3, 60, 5),
          _player(11, 'Weak Starter', 11, 3, 60, 0.5),
          _player(12, 'Fodder Gkp', 12, 1, 40, 0.5),
          for (var id = 13; id <= 15; id++)
            _player(id, 'Fodder $id', id, 2, 40, 0.5),
          _player(16, 'Upgrade Gkp', 16, 1, 40, 6),
          _player(17, 'Upgrade Def', 17, 2, 40, 6),
          _player(18, 'Upgrade Mid', 18, 3, 50, 6),
        ],
        picks: [
          for (var id = 1; id <= 11; id++) _pick(id, id, 3),
          _pick(12, 12, 1),
          for (var id = 13; id <= 15; id++) _pick(id, id, 2),
        ],
        transfers: {'bank': 0, 'limit': 1, 'made': 0},
        chips: [_chip('wildcard', 2, 19)],
        fixtures: _fixturesFor(teams: [for (var id = 1; id <= 18; id++) id]),
      );

      // Four bench fodder plus one weak starter is not a squad overhaul.
      expect(result.chip, SuggestedChip.none);
      expect(result.chipReason, ChipReason.hold);
    });

    test('wildcards when a rebuild clearly beats normal transfers', () {
      final result = _build(
        players: [
          for (var id = 1; id <= 5; id++)
            _player(id, 'Weak $id', id, 3, 50, 0.5),
          for (var id = 6; id <= 10; id++)
            _player(id, 'Strong $id', id, 3, 50, 8),
        ],
        picks: [for (var id = 1; id <= 5; id++) _pick(id, id, 3)],
        transfers: {'bank': 0, 'limit': 1, 'made': 0},
        chips: [_chip('wildcard', 2, 19)],
        fixtures: _fixturesFor(teams: [for (var id = 1; id <= 10; id++) id]),
      );

      expect(result.chip, SuggestedChip.wildcard);
      expect(result.chipReason, ChipReason.squadOverhaul);
    });

    test('plays a chip that would otherwise expire unused', () {
      RecommendationResult resultFor(int gameweek, List<String> chips) {
        return _build(
          players: [
            for (var id = 1; id <= 11; id++)
              _player(id, 'Starter $id', id, 3, 60, 5),
            for (var id = 12; id <= 15; id++)
              _player(id, 'Bench $id', id, 2, 45, 2),
          ],
          picks: [
            for (var id = 1; id <= 11; id++) _pick(id, id, 3),
            for (var id = 12; id <= 15; id++) _pick(id, id, 2),
          ],
          transfers: {'bank': 0, 'limit': 1, 'made': 1},
          chips: [for (final name in chips) _chip(name, 1, 19)],
          fixtures: _fixturesFor(
            teams: [for (var id = 1; id <= 15; id++) id],
            events: [gameweek, gameweek + 1, gameweek + 2],
          ),
          gameweekId: gameweek,
        );
      }

      final early = resultFor(18, ['bboost']);
      expect(early.chip, SuggestedChip.none);

      final lastChance = resultFor(19, ['bboost']);
      expect(lastChance.chip, SuggestedChip.benchBoost);
      expect(lastChance.chipReason, ChipReason.chipExpiring);

      // Two chips and two Gameweeks left: the stronger one is played now.
      final crowded = resultFor(18, ['bboost', '3xc']);
      expect(crowded.chip, SuggestedChip.benchBoost);
      expect(crowded.chipReason, ChipReason.chipExpiring);
    });
  });

  group('underlying stats and opponent strength', () {
    test('scales attackers and defenders by different opponent sides', () {
      final teams = [
        _ratedTeam(1),
        _ratedTeam(2, attack: 1400, defence: 1000),
        _ratedTeam(3, attack: 1000, defence: 1400),
      ];
      Map<int, double> nextPointsAgainst(int opponent) {
        final result = _build(
          players: [
            _player(1, 'Defender', 1, 2, 50, 5, epNext: 0),
            _player(2, 'Forward', 1, 4, 50, 5, epNext: 0),
          ],
          picks: [_pick(1, 1, 2), _pick(2, 2, 4)],
          fixtures: [_fixture(5, 1, opponent)],
          teams: teams,
        );
        return {
          for (final projection in [result.captain!, result.viceCaptain!])
            projection.player.id: projection.nextPoints,
        };
      }

      final dangerousButLeaky = nextPointsAgainst(2);
      final bluntButSolid = nextPointsAgainst(3);
      expect(dangerousButLeaky[2]!, greaterThan(bluntButSolid[2]!));
      expect(dangerousButLeaky[1]!, lessThan(bluntButSolid[1]!));
    });

    test('blends expected goal involvement into the projection', () {
      final result = _build(
        players: [
          _player(
            1,
            'Threat',
            1,
            3,
            50,
            5,
            epNext: 0,
            stats: _underlyingStats(
              expectedGoals: '6.0',
              expectedAssists: '3.0',
            ),
          ),
          _player(
            2,
            'Passenger',
            2,
            3,
            50,
            5,
            epNext: 0,
            stats: _underlyingStats(
              expectedGoals: '0.5',
              expectedAssists: '0.5',
            ),
          ),
        ],
        picks: [_pick(1, 1, 3), _pick(2, 2, 3)],
        fixtures: _fixturesFor(teams: [1, 2]),
        gameweekId: 5,
      );

      expect(result.captain?.player.id, 1);
      expect(
        result.captain!.nextPoints,
        greaterThan(result.viceCaptain!.nextPoints),
      );
    });

    test(
      'rewards defenders who reach the defensive contribution threshold',
      () {
        final result = _build(
          players: [
            _player(
              1,
              'Blocker',
              1,
              2,
              50,
              4,
              epNext: 0,
              stats: _underlyingStats(defensiveActions: 120),
            ),
            _player(
              2,
              'Spectator',
              2,
              2,
              50,
              4,
              epNext: 0,
              stats: _underlyingStats(defensiveActions: 30),
            ),
          ],
          picks: [_pick(1, 1, 2), _pick(2, 2, 2)],
          fixtures: _fixturesFor(teams: [1, 2]),
        );

        expect(result.captain?.player.id, 1);
        expect(
          result.captain!.nextPoints,
          greaterThan(result.viceCaptain!.nextPoints),
        );
      },
    );

    test('ignores underlying stats that are missing or too thin', () {
      double nextPoints(Map<String, dynamic> stats) {
        return _build(
          players: [_player(1, 'Mid', 1, 3, 50, 5, epNext: 0, stats: stats)],
          picks: [_pick(1, 1, 3)],
          fixtures: [_fixture(5, 1, 2)],
        ).captain!.nextPoints;
      }

      // No expected stats at all: form only, at full reliability.
      expect(nextPoints(const {}), closeTo(5.0, 0.001));
      // 180 minutes is too few: form with 0.5 reliability on PPG only.
      expect(
        nextPoints(_underlyingStats(minutes: 180)),
        closeTo(5 * 0.6 + 5 * 0.5 * 0.4, 0.001),
      );
    });
  });
}

FplBootstrap _bootstrap(
  List<Map<String, dynamic>> players, {
  List<Map<String, dynamic>>? teams,
}) {
  return FplBootstrap.fromJson({
    'events': [
      {'id': 4, 'name': 'Gameweek 4', 'is_current': true},
      {'id': 5, 'name': 'Gameweek 5', 'is_next': true},
    ],
    'teams':
        teams ??
        [
          for (var id = 1; id <= 20; id++)
            {'id': id, 'name': 'Team $id', 'short_name': 'T$id'},
        ],
    'elements': players,
  });
}

Map<String, dynamic> _player(
  int id,
  String name,
  int team,
  int position,
  int cost,
  double expectedPoints, {
  double? epNext,
  int? chance,
  Map<String, dynamic> stats = const {},
}) {
  return {
    'id': id,
    'web_name': name,
    'team': team,
    'element_type': position,
    'now_cost': cost,
    'can_select': true,
    'status': 'a',
    'form': '$expectedPoints',
    'points_per_game': '$expectedPoints',
    'ep_next': '${epNext ?? expectedPoints}',
    'chance_of_playing_next_round': chance,
    'minutes': 360,
    'starts': 4,
    ...stats,
  };
}

FplFixture _fixture(int event, int home, int away) {
  return FplFixture.fromJson({
    'id': event * 100 + home,
    'event': event,
    'team_h': home,
    'team_a': away,
    'team_h_difficulty': 3,
    'team_a_difficulty': 3,
  });
}

RecommendationResult _build({
  required List<Map<String, dynamic>> players,
  required List<Map<String, dynamic>> picks,
  required List<FplFixture> fixtures,
  Map<String, dynamic>? transfers,
  List<Map<String, dynamic>> chips = const [],
  List<Map<String, dynamic>>? teams,
  int gameweekId = 5,
}) {
  return const RecommendationEngine().build(
    bootstrap: _bootstrap(players, teams: teams),
    fixtures: fixtures,
    team: MyTeam.fromJson({
      'picks': picks,
      'transfers': ?transfers,
      'chips': chips,
    }),
    gameweekId: gameweekId,
  );
}

Map<String, dynamic> _pick(int element, int position, int elementType) {
  return {
    'element': element,
    'position': position,
    'element_type': elementType,
    'selling_price': 50,
  };
}

Map<String, dynamic> _chip(String name, int start, int stop) {
  return {
    'name': name,
    'status_for_entry': 'available',
    'start_event': start,
    'stop_event': stop,
  };
}

/// One fixture per team and Gameweek against team 20, which has no players.
List<FplFixture> _fixturesFor({
  required List<int> teams,
  List<int> events = const [5, 6, 7],
}) {
  return [
    for (final event in events)
      for (final team in teams) _fixture(event, team, 20),
  ];
}

Map<String, dynamic> _ratedTeam(
  int id, {
  int attack = 1200,
  int defence = 1200,
}) {
  return {
    'id': id,
    'name': 'Team $id',
    'short_name': 'T$id',
    'strength_attack_home': attack,
    'strength_attack_away': attack,
    'strength_defence_home': defence,
    'strength_defence_away': defence,
  };
}

Map<String, dynamic> _underlyingStats({
  String expectedGoals = '1.0',
  String expectedAssists = '1.0',
  String expectedConceded = '10.0',
  int defensiveActions = 50,
  int minutes = 900,
}) {
  return {
    'minutes': minutes,
    'expected_goals': expectedGoals,
    'expected_assists': expectedAssists,
    'expected_goals_conceded': expectedConceded,
    'defensive_contribution': defensiveActions,
    'bonus': 3,
  };
}
