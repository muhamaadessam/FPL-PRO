import 'package:fpl_engine/fpl_engine.dart';
import 'package:test/test.dart';

void main() {
  const bootstrap = FplBootstrap(
    gameweeks: [],
    teams: {},
    players: {
      1: FplPlayer(
        id: 1,
        webName: 'Original',
        teamId: 1,
        positionId: 3,
        nowCost: 57,
        costChangeStart: 5,
      ),
      2: FplPlayer(
        id: 2,
        webName: 'Bought',
        teamId: 1,
        positionId: 3,
        nowCost: 60,
        costChangeStart: 10,
      ),
    },
  );
  final team = MyTeam.fromJson(const {
    'picks': [
      {'element': 1, 'position': 1},
      {'element': 2, 'position': 2},
    ],
    'entry_history': {'event': 5, 'bank': 13, 'value': 1000},
  });

  MyTeam build(
    List<(int event, int made)> gameweeks, {
    Map<int, String> chips = const {},
    List<Map<String, Object>> transfers = const [],
  }) => withPublicTransferState(
    team: team,
    bootstrap: bootstrap,
    history: {
      'current': [
        for (final (event, made) in gameweeks)
          {'event': event, 'event_transfers': made},
      ],
      'chips': [
        for (final chip in chips.entries)
          {'event': chip.key, 'name': chip.value},
      ],
    },
    transfers: transfers,
  );

  test('banks free transfers up to five', () {
    int? free(List<(int, int)> gameweeks) => build(gameweeks).transfers.limit;
    expect(free([(1, 0)]), 1);
    expect(free([(1, 0), (2, 1)]), 1);
    expect(free([(1, 0), (2, 0)]), 2);
    expect(free([(1, 0), (2, 3)]), 1);
    expect(free([for (var i = 1; i <= 9; i++) (i, 0)]), 5);
  });

  test('keeps saved transfers through a Wildcard or Free Hit', () {
    final played = build([(1, 0), (2, 0), (3, 9)], chips: {3: 'wildcard'});
    expect(played.transfers.limit, 2);
  });

  test('uses the published bank', () {
    expect(build([(1, 0)]).transfers.bank, 13);
  });

  test('keeps half of a price rise, rounded down', () {
    final picks = build(
      [(1, 0), (2, 1)],
      transfers: [
        {
          'element_in': 2,
          'element_in_cost': 62,
          'event': 2,
          'time': '2026-09-01T00:00:00Z',
        },
      ],
    ).picks;
    // Bought at 52, now 57.
    expect(picks[0].sellingPrice, 54);
    // Bought at 62, now 60: a fall is taken in full.
    expect(picks[1].sellingPrice, 60);
  });

  test('ignores Free Hit purchases and uses the latest other one', () {
    final picks = build(
      [(1, 0), (2, 1), (3, 5)],
      chips: {3: 'freehit'},
      transfers: [
        {
          'element_in': 2,
          'element_in_cost': 59,
          'event': 3,
          'time': '2026-09-08T00:00:00Z',
        },
        {
          'element_in': 2,
          'element_in_cost': 54,
          'event': 2,
          'time': '2026-09-01T00:00:00Z',
        },
      ],
    ).picks;
    expect(picks[1].purchasePrice, 54);
    expect(picks[1].sellingPrice, 57);
  });

  test('leaves the team alone without any history', () {
    expect(build([]).transfers.limit, isNull);
  });
}
