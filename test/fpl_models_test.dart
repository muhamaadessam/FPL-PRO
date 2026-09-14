import 'package:flutter_test/flutter_test.dart';

import 'package:fantasy_pl/core/models/fpl_models.dart';
import 'package:fantasy_pl/core/network/fpl_api_client.dart';
import 'package:fantasy_pl/features/auth/data/official_auth_client.dart';

void main() {
  test('selects the current gameweek and parses public data', () {
    final bootstrap = FplBootstrap.fromJson({
      'events': [
        {
          'id': 1,
          'name': 'Gameweek 1',
          'deadline_time': '2026-08-21T17:30:00Z',
          'finished': true,
          'is_current': false,
          'is_next': false,
        },
        {
          'id': 2,
          'name': 'Gameweek 2',
          'deadline_time': '2026-08-28T17:30:00Z',
          'finished': false,
          'is_current': true,
          'is_next': false,
          'average_entry_score': 45,
          'highest_score': 120,
        },
      ],
      'teams': [
        {'id': 1, 'name': 'Arsenal', 'short_name': 'ARS'},
      ],
      'elements': [
        {
          'id': 10,
          'web_name': 'Player',
          'team': 1,
          'element_type': 3,
          'total_points': 42,
          'now_cost': 70,
        },
      ],
    });

    expect(bootstrap.currentGameweekId, 2);
    final gw2 = bootstrap.gameweeks.firstWhere((g) => g.id == 2);
    expect(gw2.averageEntryScore, 45);
    expect(gw2.highestScore, 120);
    expect(bootstrap.teams[1]?.shortName, 'ARS');
    expect(bootstrap.players[10]?.totalPoints, 42);
  });

  test('parses team picks and gameweek summary', () {
    final team = MyTeam.fromJson({
      'entry_history': {
        'event': 2,
        'points': 58,
        'total_points': 112,
        'overall_rank': 100,
        'bank': 10,
        'value': 1005,
        'points_on_bench': 4,
      },
      'picks': [
        {
          'element': 10,
          'position': 1,
          'multiplier': 2,
          'is_captain': true,
          'is_vice_captain': false,
          'element_type': 3,
          'purchase_price': 68,
          'selling_price': 69,
        },
      ],
      'transfers': {'bank': 12, 'limit': 3, 'made': 1, 'cost': 0},
      'chips': [
        {
          'name': 'wildcard',
          'status_for_entry': 'available',
          'start_event': 2,
          'stop_event': 19,
          'played_by_entry': [4],
        },
      ],
    });

    expect(team.summary.points, 58);
    expect(team.summary.totalPoints, 112);
    expect(team.picks.single.elementId, 10);
    expect(team.picks.single.isCaptain, isTrue);
    expect(team.picks.single.sellingPrice, 69);
    expect(team.transfers.bank, 12);
    expect(team.transfers.limit, 3);
    expect(team.chips.single.isAvailableFor(5), isTrue);
  });

  test('creates the RFC 7636 PKCE challenge', () {
    expect(
      pkceCodeChallenge('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
      'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
    );
  });

  test('finds the entry id in the /api/me response', () {
    expect(
      findEntryId({
        'player': {'entry_id': '12345'},
      }),
      12345,
    );
    expect(
      findEntryId({
        'entry': {'id': 67890},
      }),
      67890,
    );
    expect(
      findEntryId({
        'player': {'id': 99},
      }),
      isNull,
    );
    expect(findEntryId({'player': null}), isNull);
  });

  test('maps live gameweek points by player id', () {
    expect(
      parseGameweekPoints({
        'elements': [
          {
            'id': 10,
            'stats': {'total_points': 12},
          },
          {
            'id': 11,
            'stats': {'total_points': '4'},
          },
        ],
      }),
      {10: 12, 11: 4},
    );
  });

  test('maps official entry history points by gameweek', () {
    expect(
      parseEntryHistoryPoints({
        'current': [
          {'event': 4, 'points': 60},
          {'event': 5, 'points': '42'},
        ],
      }),
      {4: 60, 5: 42},
    );
  });

  test('blocks consecutive free hit gameweeks', () {
    final chip = FplChipState.fromJson({
      'name': 'freehit',
      'status_for_entry': 'available',
      'start_event': 20,
      'stop_event': 38,
      'played_by_entry': [19],
    });

    expect(chip.isAvailableFor(20), isFalse);
    expect(chip.isAvailableFor(21), isTrue);
  });
}
