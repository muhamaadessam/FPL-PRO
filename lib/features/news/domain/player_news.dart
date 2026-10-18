import 'package:fpl_engine/fpl_engine.dart';

/// Ownership from which a news item counts as key news for everyone.
const keyNewsOwnershipPercent = 3.0;

class PlayerNewsItem {
  const PlayerNewsItem({required this.player, required this.inSquad});

  final FplPlayer player;
  final bool inSquad;

  bool get isKey =>
      inSquad || player.selectedByPercent >= keyNewsOwnershipPercent;
}

class GameweekNews {
  const GameweekNews({required this.gameweek, required this.items});

  final Gameweek gameweek;

  /// Squad players first, then by ownership.
  final List<PlayerNewsItem> items;

  Iterable<PlayerNewsItem> get keyItems => items.where((item) => item.isKey);
}

/// Every player's current FPL news, grouped by the Gameweek whose deadline
/// it came before, newest Gameweek first.
///
/// FPL keeps only each player's latest news, so an older Gameweek lists the
/// news from then that still stands. News added after the last deadline, or
/// with no date, belongs to the next deadline.
List<GameweekNews> groupPlayerNews(
  FplBootstrap bootstrap, {
  Set<int> squadIds = const {},
}) {
  final gameweeks =
      bootstrap.gameweeks.where((gw) => gw.deadlineTime != null).toList()
        ..sort((a, b) => a.deadlineTime!.compareTo(b.deadlineTime!));
  if (gameweeks.isEmpty) return const [];
  final upcoming = gameweeks.firstWhere(
    (gw) => gw.id == bootstrap.editableGameweekId,
    orElse: () => gameweeks.last,
  );

  final byGameweek = <int, List<PlayerNewsItem>>{};
  for (final player in bootstrap.players.values) {
    if (player.news.trim().isEmpty) continue;
    final added = player.newsAdded;
    final gameweek = added == null
        ? upcoming
        : gameweeks.firstWhere(
            (gw) => gw.deadlineTime!.isAfter(added),
            orElse: () => upcoming,
          );
    byGameweek
        .putIfAbsent(gameweek.id, () => [])
        .add(
          PlayerNewsItem(player: player, inSquad: squadIds.contains(player.id)),
        );
  }

  return [
    for (final gameweek in gameweeks.reversed)
      if (byGameweek[gameweek.id] case final items?)
        GameweekNews(gameweek: gameweek, items: items..sort(_byImportance)),
  ];
}

int _byImportance(PlayerNewsItem a, PlayerNewsItem b) {
  if (a.inSquad != b.inSquad) return a.inSquad ? -1 : 1;
  final owned = b.player.selectedByPercent.compareTo(
    a.player.selectedByPercent,
  );
  if (owned != 0) return owned;
  final at = a.player.newsAdded, bt = b.player.newsAdded;
  if (at != null && bt != null) return bt.compareTo(at);
  return a.player.webName.compareTo(b.player.webName);
}
