import 'package:flutter_test/flutter_test.dart';

import 'package:fantasy_pl/features/fixtures/data/models/fpl_models.dart';
import 'package:fantasy_pl/features/recommendations/domain/usecases/recommendation_engine.dart';
import 'package:fantasy_pl/features/team/data/models/team_models.dart';

void main() {
  test(
    'weekly plan promotes the best bench player and preserves a legal squad',
    () {
      final positions = [1, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 1, 2, 2, 3];
      final bootstrap = _bootstrap([
        for (var i = 0; i < positions.length; i++)
          _player(
            i + 1,
            'Player ${i + 1}',
            i + 1,
            positions[i],
            60,
            i == 14 ? 10 : (i >= 11 ? 3 : 5),
          ),
      ]);
      final team = MyTeam.fromJson({
        'picks': [
          for (var i = 0; i < positions.length; i++)
            {
              'element': i + 1,
              'position': i + 1,
              'element_type': positions[i],
              'is_captain': i == 8,
            },
        ],
      });
      final result = const RecommendationEngine().build(
        bootstrap: bootstrap,
        fixtures: [for (var id = 1; id <= 15; id++) _fixture(5, id, 20)],
        team: team,
        gameweekId: 5,
      );
      final lineup = result.suggestedLineup;
      expect(
        const RecommendationEngine().isLegalStartingLineup(lineup.players),
        isTrue,
      );
      expect(lineup.starters, hasLength(11));
      expect(lineup.bench, hasLength(4));
      expect(
        lineup.players.map((p) => p.pick.elementId).toSet(),
        hasLength(15),
      );
      expect(lineup.bench.first.projection.player.positionId, 1);
      expect(result.captain?.player.id, 15);
      expect(
        lineup.starters.singleWhere((p) => p.pick.isCaptain).pick.elementId,
        15,
      );
      expect(
        lineup.bench.every((p) => !p.pick.isCaptain && !p.pick.isViceCaptain),
        isTrue,
      );
      expect(
        lineup.expectedStartingPoints,
        closeTo(lineup.bestLegalLineupPoints, 0.0001),
      );
      expect(
        lineup.expectedStartingPoints,
        greaterThan(result.squadAnalysis.expectedStartingPoints),
      );
      expect(team.picks.last.position, 15);
      expect(team.picks[8].isCaptain, isTrue);
    },
  );

  test(
    'injured player with strong history has zero forecast despite a fixture',
    () {
      final bootstrap = _bootstrap([
        {..._player(1, 'Injured', 1, 3, 70, 10), 'status': 'i'},
      ]);
      final result = const RecommendationEngine().build(
        bootstrap: bootstrap,
        fixtures: [_fixture(5, 1, 2)],
        team: MyTeam.fromJson({
          'picks': [
            {'element': 1, 'position': 1},
          ],
        }),
        gameweekId: 5,
        playerSummaries: {
          1: FplPlayerSummary(
            history: [
              FplPlayerHistory(
                round: 4,
                minutes: 90,
                starts: 1,
                totalPoints: 15,
                expectedGoalInvolvements: 1,
              ),
            ],
          ),
        },
      );
      expect(result.squadAnalysis.players.single.expectedPoints, 0);
      expect(result.captain, isNull);
    },
  );

  test(
    'transfer advice needs current budget, selling price and free transfers',
    () {
      final bootstrap = _bootstrap([
        _player(1, 'Outgoing', 1, 3, 70, 2),
        _player(2, 'Incoming', 2, 3, 75, 8),
      ]);
      final projections = const RecommendationEngine().buildPlayerProjections(
        bootstrap: bootstrap,
        fixtures: [_fixture(5, 1, 2)],
        gameweekId: 5,
      );
      for (final missing in ['bank', 'limit', 'made', 'selling_price']) {
        final result = const RecommendationEngine().buildTransferSuggestion(
          team: MyTeam.fromJson({
            'picks': [
              {
                'element': 1,
                'position': 1,
                if (missing != 'selling_price') 'selling_price': 70,
              },
            ],
            'entry_history': {'bank': 100},
            'transfers': {
              if (missing != 'bank') 'bank': 10,
              if (missing != 'limit') 'limit': 1,
              if (missing != 'made') 'made': 0,
            },
          }),
          bootstrap: bootstrap,
          outgoing: projections.singleWhere((p) => p.player.id == 1),
          incoming: projections.singleWhere((p) => p.player.id == 2),
        );
        expect(result, isNull, reason: 'Missing $missing must not be guessed');
      }
    },
  );

  test(
    'does not suggest a transfer whose forecast gain fails to cover a hit',
    () {
      final result = const RecommendationEngine().build(
        bootstrap: _bootstrap([
          _player(1, 'Outgoing', 1, 3, 70, 4),
          _player(2, 'Incoming', 2, 3, 70, 5),
        ]),
        fixtures: [_fixture(5, 1, 2)],
        team: MyTeam.fromJson({
          'picks': [
            {'element': 1, 'position': 1, 'selling_price': 70},
          ],
          'transfers': {'bank': 0, 'limit': 1, 'made': 1},
        }),
        gameweekId: 5,
      );
      expect(result.freeTransfers, 0);
      expect(result.transfers, isEmpty);
    },
  );

  test('builds next-gameweek projections for every listed player', () {
    final bootstrap = _bootstrap([
      _player(1, 'Available', 1, 3, 70, 6),
      {..._player(2, 'Unavailable', 2, 3, 70, 10), 'status': 'u'},
    ]);

    final projections = const RecommendationEngine().buildPlayerProjections(
      bootstrap: bootstrap,
      fixtures: [_fixture(5, 1, 2)],
      gameweekId: 5,
    );

    expect(projections, hasLength(2));
    expect(projections.first.player.id, 1);
    expect(projections.last.nextPoints, 0);
  });

  test('allows a same-position transfer within the squad budget', () {
    final bootstrap = _bootstrap([
      _player(1, 'Outgoing Mid', 1, 3, 70, 4),
      _player(2, 'Incoming Mid', 2, 3, 75, 8),
    ]);
    final team = MyTeam.fromJson({
      'picks': [
        {'element': 1, 'position': 1, 'element_type': 3, 'selling_price': 70},
      ],
      'transfers': {'bank': 10, 'limit': 1, 'made': 0},
    });
    final projections = const RecommendationEngine().buildPlayerProjections(
      bootstrap: bootstrap,
      fixtures: [_fixture(5, 1, 2)],
      gameweekId: 5,
    );

    final transfer = const RecommendationEngine().buildTransferSuggestion(
      team: team,
      bootstrap: bootstrap,
      outgoing: projections.firstWhere((item) => item.player.id == 1),
      incoming: projections.firstWhere((item) => item.player.id == 2),
    );

    expect(transfer?.outPlayer.id, 1);
    expect(transfer?.inPlayer.id, 2);
    expect(transfer?.hitCost, 0);
  });

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

  test('rates by position and handles doubles and blanks', () {
    final bootstrap = _bootstrap([
      _player(1, 'Double Star', 1, 3, 90, 8),
      _player(2, 'Average Mid', 2, 3, 70, 4),
      {..._player(3, 'Unavailable', 3, 3, 60, 6), 'status': 'u'},
    ]);
    final team = MyTeam.fromJson({
      'picks': [
        {'element': 1, 'position': 1, 'element_type': 3, 'is_captain': true},
        {'element': 3, 'position': 12, 'element_type': 3},
      ],
    });
    final result = const RecommendationEngine().build(
      bootstrap: bootstrap,
      fixtures: [_fixture(5, 1, 2), _fixture(5, 1, 4)],
      team: team,
      gameweekId: 5,
      playerSummaries: {
        1: FplPlayerSummary(
          history: [
            FplPlayerHistory(
              round: 4,
              minutes: 90,
              starts: 1,
              totalPoints: 9,
              expectedGoalInvolvements: 0.8,
            ),
          ],
          historyPast: [
            FplPastSeason(
              seasonName: '2025/26',
              totalPoints: 180,
              minutes: 3000,
              starts: 34,
              expectedGoalInvolvements: 15,
            ),
          ],
        ),
      },
    );

    final star = result.squadAnalysis.players.first;
    final unavailable = result.squadAnalysis.players.last;
    expect(star.projection.nextFixtureCount, 2);
    expect(star.rating, 100);
    expect(star.expectedPoints, greaterThan(0));
    expect(unavailable.expectedPoints, 0);
    expect(result.squadAnalysis.currentSeasonCoverage, 1);
    expect(result.squadAnalysis.previousSeasonPlayers, 1);
  });

  test('recalculates preview metrics from the swapped starters', () {
    final bootstrap = _bootstrap([
      _player(1, 'Starter', 1, 3, 70, 3),
      _player(2, 'Bench', 2, 3, 70, 8),
    ]);
    final team = MyTeam.fromJson({
      'picks': [
        {'element': 1, 'position': 1, 'element_type': 3},
        {'element': 2, 'position': 12, 'element_type': 3},
      ],
    });
    final result = const RecommendationEngine().build(
      bootstrap: bootstrap,
      fixtures: [_fixture(5, 1, 2)],
      team: team,
      gameweekId: 5,
    );
    final swapped = result.squadAnalysis.players
        .map(
          (player) => player.copyWith(
            pick: player.pick.copyWith(
              position: player.pick.elementId == 2 ? 1 : 12,
            ),
          ),
        )
        .toList(growable: false);

    final preview = const RecommendationEngine().buildSquadAnalysisForPreview(
      players: swapped,
      currentSeasonCoverage: result.squadAnalysis.currentSeasonCoverage,
      previousSeasonPlayers: result.squadAnalysis.previousSeasonPlayers,
    );

    expect(preview.starters.single.projection.player.id, 2);
    expect(preview.bench.single.projection.player.id, 1);
    expect(
      preview.expectedStartingPoints,
      closeTo(preview.starters.single.expectedPoints, 0.0001),
    );
  });

  test('keeps the goalkeeper first on the bench and rejects two keepers', () {
    final bootstrap = _bootstrap([
      _player(1, 'Starter Keeper', 1, 1, 45, 4),
      _player(2, 'Bench Mid', 2, 3, 70, 5),
      _player(3, 'Bench Keeper', 3, 1, 45, 3),
    ]);
    final team = MyTeam.fromJson({
      'picks': [
        {'element': 1, 'position': 1, 'element_type': 1},
        {'element': 2, 'position': 12, 'element_type': 3},
        {'element': 3, 'position': 13, 'element_type': 1},
      ],
    });
    final result = const RecommendationEngine().build(
      bootstrap: bootstrap,
      fixtures: [_fixture(5, 1, 2)],
      team: team,
      gameweekId: 5,
    );

    expect(result.squadAnalysis.bench.first.projection.player.id, 3);

    final invalid = result.squadAnalysis.players
        .map(
          (player) => player.copyWith(
            pick: player.pick.copyWith(
              position: player.projection.player.id == 3
                  ? 1
                  : player.pick.position,
            ),
          ),
        )
        .toList(growable: false);
    expect(
      const RecommendationEngine().isLegalStartingLineup(invalid),
      isFalse,
    );
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

    test('suggests no transfers without the free-transfer count', () {
      final result = _build(
        players: [
          _player(1, 'Weak', 1, 3, 50, 1),
          _player(2, 'Strong', 2, 3, 50, 8),
        ],
        picks: [_pick(1, 1, 3)],
        fixtures: _fixturesFor(teams: [1, 2]),
      );

      expect(result.freeTransfers, isNull);
      expect(result.transfers, isEmpty);
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

    test('reads scoring points from game_config', () {
      double nextPoints(Map<String, dynamic>? scoring) {
        return _build(
          players: [
            _player(
              1,
              'Scorer',
              1,
              3,
              50,
              5,
              epNext: 0,
              stats: _underlyingStats(expectedGoals: '6.0'),
            ),
          ],
          picks: [_pick(1, 1, 3)],
          fixtures: [_fixture(5, 1, 2)],
          scoring: scoring,
        ).captain!.nextPoints;
      }

      final defaults = nextPoints(null);
      expect(
        nextPoints({
          'goals_scored': {'GKP': 10, 'DEF': 6, 'MID': 5, 'FWD': 4},
        }),
        closeTo(defaults, 0.001),
      );
      // Doubling midfield goal points raises an xG-heavy midfielder.
      expect(
        nextPoints({
          'goals_scored': {'GKP': 10, 'DEF': 6, 'MID': 10, 'FWD': 4},
        }),
        greaterThan(defaults),
      );
    });

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
        nextPoints({..._underlyingStats(minutes: 180), 'starts': 2}),
        closeTo(5 * 0.6 + 5 * 0.5 * 0.4, 0.001),
      );
    });
  });

  group('minutes, availability and active chips', () {
    test('weights recent minutes over season minutes', () {
      double nextPoints(List<int>? recentMinutes) {
        return _build(
          players: [_player(1, 'Mid', 1, 3, 50, 5, epNext: 0)],
          picks: [_pick(1, 1, 3)],
          fixtures: [_fixture(5, 1, 2)],
          playerSummaries: {
            if (recentMinutes != null)
              1: FplPlayerSummary(
                history: [
                  for (var i = 0; i < recentMinutes.length; i++)
                    FplPlayerHistory.fromJson({
                      'round': i + 1,
                      'minutes': recentMinutes[i],
                    }),
                ],
              ),
          },
        ).captain!.nextPoints;
      }

      expect(nextPoints(null), closeTo(5.0, 0.001));
      // Benched in the last five of seven matches: only those five count,
      // so reliability is 0.7 * 0 + 0.3 * 1 on PPG.
      expect(
        nextPoints([90, 90, 0, 0, 0, 0, 0]),
        closeTo(5 * 0.6 + 5 * 0.3 * 0.4, 0.001),
      );
    });

    test('counts starts as well as minutes for reliability', () {
      double nextPoints(Map<String, dynamic> stats) {
        return _build(
          players: [_player(1, 'Mid', 1, 3, 50, 5, epNext: 0, stats: stats)],
          picks: [_pick(1, 1, 3)],
          fixtures: [_fixture(5, 1, 2)],
        ).captain!.nextPoints;
      }

      const minutesShare = 330 / 360;
      // Started all four matches but was subbed late on.
      expect(
        nextPoints({'minutes': 330, 'starts': 4}),
        closeTo(3 + 5 * (minutesShare / 2 + 0.5) * 0.4, 0.001),
      );
      // Same minutes from the bench: a lower start rate.
      expect(
        nextPoints({'minutes': 330, 'starts': 0}),
        closeTo(3 + 5 * (minutesShare / 2) * 0.4, 0.001),
      );
    });

    test('treats suspended players without a chance as unavailable', () {
      final projection = const RecommendationEngine()
          .buildPlayerProjections(
            bootstrap: _bootstrap([
              _player(1, 'Banned', 1, 3, 50, 6, status: 's'),
            ]),
            fixtures: [_fixture(5, 1, 2)],
            gameweekId: 5,
          )
          .single;

      // Even a stale ep_next must not give an unavailable player points.
      expect(projection.availability, 0);
      expect(projection.nextPoints, 0);
    });

    test('respects a chip that is already active', () {
      final result = _build(
        players: [
          _player(1, 'Weak', 1, 3, 50, 1),
          _player(2, 'Strong', 2, 3, 50, 8),
        ],
        picks: [_pick(1, 1, 3)],
        transfers: {'bank': 0, 'limit': 1, 'made': 1},
        chips: [
          {'name': 'wildcard', 'status_for_entry': 'active'},
          _chip('3xc', 1, 19),
        ],
        fixtures: _fixturesFor(teams: [1, 2]),
      );

      expect(result.chip, SuggestedChip.wildcard);
      expect(result.chipReason, ChipReason.chipActive);
      // Wildcard transfers are free even with no free transfers left.
      expect(result.transfers.single.hitCost, 0);
    });

    test('gives a non-negative likely range around the projection', () {
      final result = _build(
        players: [_player(1, 'Mid', 1, 3, 50, 7)],
        picks: [_pick(1, 1, 3)],
        fixtures: [_fixture(5, 1, 2)],
      );
      final (low, high) = result.captain!.nextRange;

      expect(low, greaterThanOrEqualTo(0));
      expect(low, lessThan(7));
      expect(high, greaterThan(7));
    });
  });
}

FplBootstrap _bootstrap(
  List<Map<String, dynamic>> players, {
  List<Map<String, dynamic>>? teams,
  Map<String, dynamic>? scoring,
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
    'game_config': ?(scoring == null ? null : {'scoring': scoring}),
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
  String status = 'a',
  Map<String, dynamic> stats = const {},
}) {
  return {
    'id': id,
    'web_name': name,
    'team': team,
    'element_type': position,
    'now_cost': cost,
    'can_select': true,
    'status': status,
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
  Map<int, FplPlayerSummary> playerSummaries = const {},
  Map<String, dynamic>? scoring,
  int gameweekId = 5,
}) {
  return const RecommendationEngine().build(
    bootstrap: _bootstrap(players, teams: teams, scoring: scoring),
    fixtures: fixtures,
    team: MyTeam.fromJson({
      'picks': picks,
      'transfers': ?transfers,
      'chips': chips,
    }),
    gameweekId: gameweekId,
    playerSummaries: playerSummaries,
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
