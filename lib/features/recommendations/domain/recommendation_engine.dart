import '../../../core/models/fpl_models.dart';

enum SuggestedChip { none, wildcard, freeHit, benchBoost, tripleCaptain }

enum ChipReason {
  availabilityUnknown,
  missingStarters,
  squadOverhaul,
  strongBench,
  captainCeiling,
  hold,
}

class PlayerProjection {
  const PlayerProjection({
    required this.player,
    required this.nextPoints,
    required this.horizonPoints,
    required this.availability,
    required this.nextFixtureCount,
    required this.nextDifficulties,
  });

  final FplPlayer player;
  final double nextPoints;
  final double horizonPoints;
  final double availability;
  final int nextFixtureCount;
  final List<int> nextDifficulties;
}

class TransferSuggestion {
  const TransferSuggestion({
    required this.outPlayer,
    required this.inPlayer,
    required this.projectedGain,
    required this.hitCost,
  });

  final FplPlayer outPlayer;
  final FplPlayer inPlayer;
  final double projectedGain;
  final int hitCost;

  double get netProjectedGain => projectedGain - hitCost;
}

class RecommendationResult {
  const RecommendationResult({
    required this.gameweekId,
    required this.captain,
    required this.viceCaptain,
    required this.transfers,
    required this.topByPosition,
    required this.chip,
    required this.chipReason,
    required this.benchProjectedPoints,
    required this.freeTransfers,
    required this.bank,
  });

  final int gameweekId;
  final PlayerProjection? captain;
  final PlayerProjection? viceCaptain;
  final List<TransferSuggestion> transfers;
  final Map<int, List<PlayerProjection>> topByPosition;
  final SuggestedChip chip;
  final ChipReason chipReason;
  final double benchProjectedPoints;
  final int? freeTransfers;
  final int? bank;
}

class RecommendationEngine {
  const RecommendationEngine();

  RecommendationResult build({
    required FplBootstrap bootstrap,
    required List<FplFixture> fixtures,
    required MyTeam team,
    required int gameweekId,
  }) {
    final projections = {
      for (final player in bootstrap.players.values)
        player.id: _project(player, fixtures, gameweekId),
    };
    final selectable =
        projections.values
            .where(
              (projection) =>
                  projection.player.canSelect && projection.horizonPoints > 0,
            )
            .toList()
          ..sort((a, b) => b.horizonPoints.compareTo(a.horizonPoints));

    final starters =
        team.picks
            .where((pick) => pick.position <= 11)
            .map((pick) => projections[pick.elementId])
            .whereType<PlayerProjection>()
            .toList()
          ..sort((a, b) => b.nextPoints.compareTo(a.nextPoints));
    final bench = team.picks
        .where((pick) => pick.position > 11)
        .map((pick) => projections[pick.elementId])
        .whereType<PlayerProjection>()
        .toList();
    final transferIdeas = _transferIdeas(team, bootstrap, projections);
    final chipDecision = _chipDecision(
      team: team,
      starters: starters,
      bench: bench,
      transferIdeas: transferIdeas,
      gameweekId: gameweekId,
    );

    return RecommendationResult(
      gameweekId: gameweekId,
      captain: starters.firstOrNull,
      viceCaptain: starters.length > 1 ? starters[1] : null,
      transfers: transferIdeas,
      topByPosition: {
        for (var position = 1; position <= 4; position++)
          position: selectable
              .where((item) => item.player.positionId == position)
              .take(3)
              .toList(growable: false),
      },
      chip: chipDecision.$1,
      chipReason: chipDecision.$2,
      benchProjectedPoints: bench.fold(
        0,
        (total, player) => total + player.nextPoints,
      ),
      freeTransfers: _freeTransfers(team.transfers),
      bank: team.transfers.bank ?? team.summary.bank,
    );
  }

  PlayerProjection _project(
    FplPlayer player,
    List<FplFixture> fixtures,
    int gameweekId,
  ) {
    final availability = _availability(player);
    final reliability = player.minutes == 0
        ? 0.55
        : (player.minutes / (90 * (gameweekId - 1).clamp(1, 38))).clamp(
            0.45,
            1.0,
          );
    final recent = player.form * 0.6 + player.pointsPerGame * 0.4;
    final nextBase = player.expectedPointsNext > 0
        ? player.expectedPointsNext * 0.6 + recent * 0.4
        : recent;
    var horizon = 0.0;
    var next = 0.0;
    var nextCount = 0;
    var nextDifficulties = const <int>[];

    for (var offset = 0; offset < 3; offset++) {
      final eventFixtures = fixtures
          .where(
            (fixture) =>
                fixture.gameweekId == gameweekId + offset &&
                (fixture.homeTeamId == player.teamId ||
                    fixture.awayTeamId == player.teamId),
          )
          .toList();
      if (eventFixtures.isEmpty) continue;
      final difficulties = eventFixtures
          .map((fixture) => _difficultyFor(player.teamId, fixture))
          .toList(growable: false);
      final difficulty =
          difficulties.reduce((a, b) => a + b) / difficulties.length;
      final difficultyFactor = 1.24 - (difficulty * 0.08);
      final base = offset == 0 ? nextBase : recent;
      final eventScore =
          base *
          availability *
          reliability *
          difficultyFactor *
          eventFixtures.length;
      horizon += eventScore * const [1.0, 0.65, 0.4][offset];
      if (offset == 0) {
        next = eventScore;
        nextCount = eventFixtures.length;
        nextDifficulties = difficulties;
      }
    }

    return PlayerProjection(
      player: player,
      nextPoints: next,
      horizonPoints: horizon,
      availability: availability,
      nextFixtureCount: nextCount,
      nextDifficulties: nextDifficulties,
    );
  }

  List<TransferSuggestion> _transferIdeas(
    MyTeam team,
    FplBootstrap bootstrap,
    Map<int, PlayerProjection> projections,
  ) {
    final squadIds = team.picks.map((pick) => pick.elementId).toSet();
    final squad = squadIds
        .map((id) => bootstrap.players[id])
        .whereType<FplPlayer>()
        .toList();
    final bank = team.transfers.bank ?? team.summary.bank ?? 0;
    final freeTransfers = _freeTransfers(team.transfers);
    final hitCost = freeTransfers == 0 ? 4 : 0;
    final ideas = <TransferSuggestion>[];

    for (final pick in team.picks) {
      final outgoing = bootstrap.players[pick.elementId];
      final outgoingProjection = projections[pick.elementId];
      if (outgoing == null || outgoingProjection == null) continue;
      final sellingPrice = pick.sellingPrice ?? outgoing.nowCost ?? 0;

      PlayerProjection? best;
      for (final candidate in projections.values) {
        final cost = candidate.player.nowCost;
        if (squadIds.contains(candidate.player.id) ||
            candidate.player.positionId != outgoing.positionId ||
            !candidate.player.canSelect ||
            candidate.availability < 0.5 ||
            cost == null ||
            cost > sellingPrice + bank) {
          continue;
        }
        final clubCount = squad.where((player) {
          return player.teamId == candidate.player.teamId &&
              player.id != outgoing.id;
        }).length;
        if (clubCount >= 3) continue;
        if (best == null || candidate.horizonPoints > best.horizonPoints) {
          best = candidate;
        }
      }
      if (best == null) continue;
      final gain = best.horizonPoints - outgoingProjection.horizonPoints;
      if (gain - hitCost < 0.75) continue;
      ideas.add(
        TransferSuggestion(
          outPlayer: outgoing,
          inPlayer: best.player,
          projectedGain: gain,
          hitCost: hitCost,
        ),
      );
    }

    ideas.sort((a, b) => b.projectedGain.compareTo(a.projectedGain));
    final selected = <TransferSuggestion>[];
    final incomingIds = <int>{};
    for (final idea in ideas) {
      if (incomingIds.add(idea.inPlayer.id)) selected.add(idea);
      if (selected.length == 3) break;
    }
    return selected;
  }

  (SuggestedChip, ChipReason) _chipDecision({
    required MyTeam team,
    required List<PlayerProjection> starters,
    required List<PlayerProjection> bench,
    required List<TransferSuggestion> transferIdeas,
    required int gameweekId,
  }) {
    if (team.chips.isEmpty) {
      return (SuggestedChip.none, ChipReason.availabilityUnknown);
    }
    bool available(String name) => team.chips.any(
      (chip) => chip.name == name && chip.isAvailableFor(gameweekId),
    );

    final missingStarters = starters
        .where(
          (player) =>
              player.nextFixtureCount == 0 || player.availability < 0.35,
        )
        .length;
    if (missingStarters >= 4 && available('freehit')) {
      return (SuggestedChip.freeHit, ChipReason.missingStarters);
    }

    final weakSquad = [...starters, ...bench]
        .where(
          (player) =>
              player.nextFixtureCount == 0 ||
              player.availability < 0.5 ||
              player.horizonPoints < 3,
        )
        .length;
    if (weakSquad >= 5 && transferIdeas.length >= 3 && available('wildcard')) {
      return (SuggestedChip.wildcard, ChipReason.squadOverhaul);
    }

    final benchPoints = bench.fold(
      0.0,
      (total, player) => total + player.nextPoints,
    );
    if (bench.length == 4 &&
        benchPoints >= 14 &&
        bench.every((player) => player.availability >= 0.75) &&
        available('bboost')) {
      return (SuggestedChip.benchBoost, ChipReason.strongBench);
    }

    final captain = starters.firstOrNull;
    if (captain != null &&
        (captain.nextPoints >= 8.5 ||
            (captain.nextFixtureCount > 1 && captain.nextPoints >= 7)) &&
        available('3xc')) {
      return (SuggestedChip.tripleCaptain, ChipReason.captainCeiling);
    }

    return (SuggestedChip.none, ChipReason.hold);
  }

  int _difficultyFor(int teamId, FplFixture fixture) {
    return teamId == fixture.homeTeamId
        ? fixture.homeDifficulty ?? 3
        : fixture.awayDifficulty ?? 3;
  }

  double _availability(FplPlayer player) {
    if (!player.canSelect || player.status == 'u') return 0;
    final chance = player.chanceOfPlayingNextRound;
    if (chance != null) return (chance / 100).clamp(0, 1);
    return switch (player.status) {
      'a' => 1,
      'd' => 0.75,
      _ => 0.35,
    };
  }

  int? _freeTransfers(TeamTransferState transfers) {
    final limit = transfers.limit;
    if (limit == null) return null;
    return (limit - (transfers.made ?? 0)).clamp(0, 5);
  }
}
