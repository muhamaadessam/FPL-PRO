import 'models/fpl_models.dart';
import 'models/team_models.dart';

/// Most free transfers a manager can hold.
const _maxFreeTransfers = 5;

/// Fills in what [team]'s public picks leave out but transfer advice needs:
/// bank, free transfers and selling prices. [history] is `/entry/{id}/history/`
/// and [transfers] is `/entry/{id}/transfers/`; moves made since the last
/// deadline are private, so they cannot be included.
MyTeam withPublicTransferState({
  required MyTeam team,
  required FplBootstrap bootstrap,
  required Map<String, dynamic> history,
  required List<dynamic> transfers,
}) {
  final chips = <int, String>{
    for (final chip in (history['chips'] as List? ?? const []).whereType<Map>())
      if (chip['event'] is int) chip['event'] as int: '${chip['name']}',
  };
  final freeTransfers = _freeTransfers(history, chips);
  if (freeTransfers == null) return team;

  // A Free Hit squad is handed back, so its purchases never stick. The latest
  // purchase of a player is the one that counts.
  final bought = <int, (DateTime, int)>{};
  for (final move in transfers.whereType<Map>()) {
    final id = move['element_in'];
    final cost = move['element_in_cost'];
    final time = DateTime.tryParse('${move['time']}');
    if (id is! int || cost is! int || time == null) continue;
    if (chips[move['event']] == FplChipName.freeHit) continue;
    final known = bought[id];
    if (known == null || time.isAfter(known.$1)) bought[id] = (time, cost);
  }

  return MyTeam(
    picks: [
      for (final pick in team.picks)
        _priced(pick, bootstrap.players[pick.elementId], bought),
    ],
    summary: team.summary,
    transfers: TeamTransferState(
      bank: team.summary.bank,
      value: team.summary.value,
      limit: freeTransfers,
      made: 0,
      cost: 4,
    ),
    chips: team.chips,
    activeChip: team.activeChip,
  );
}

/// Free transfers for the next deadline: one more each Gameweek up to the cap,
/// with none gained or used in a Wildcard or Free Hit week.
int? _freeTransfers(Map<String, dynamic> history, Map<int, String> chips) {
  final gameweeks =
      (history['current'] as List? ?? const [])
          .whereType<Map>()
          .where((gameweek) => gameweek['event'] is int)
          .toList()
        ..sort((a, b) => (a['event'] as int).compareTo(b['event'] as int));
  if (gameweeks.isEmpty) return null;
  // The first Gameweek has unlimited transfers.
  var free = 1;
  for (final gameweek in gameweeks.skip(1)) {
    if (FplChipName.transferChips.contains(chips[gameweek['event']])) continue;
    final made = gameweek['event_transfers'] as int? ?? 0;
    free = ((free - made).clamp(0, _maxFreeTransfers) + 1).clamp(
      1,
      _maxFreeTransfers,
    );
  }
  return free;
}

/// The manager keeps half of any price rise, rounded down, and takes the whole
/// of a fall. Players never transferred in were bought at the season's start.
TeamPick _priced(
  TeamPick pick,
  FplPlayer? player,
  Map<int, (DateTime, int)> bought,
) {
  final now = player?.nowCost;
  if (player == null || now == null) return pick;
  final paid = bought[pick.elementId]?.$2 ?? now - player.costChangeStart;
  return pick.copyWith(
    purchasePrice: paid,
    sellingPrice: now > paid ? paid + (now - paid) ~/ 2 : now,
  );
}
