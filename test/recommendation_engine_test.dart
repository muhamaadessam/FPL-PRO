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
}

FplBootstrap _bootstrap(List<Map<String, dynamic>> players) {
  return FplBootstrap.fromJson({
    'events': [
      {'id': 4, 'name': 'Gameweek 4', 'is_current': true},
      {'id': 5, 'name': 'Gameweek 5', 'is_next': true},
    ],
    'teams': [
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
  double expectedPoints,
) {
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
    'ep_next': '$expectedPoints',
    'minutes': 360,
    'starts': 4,
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
