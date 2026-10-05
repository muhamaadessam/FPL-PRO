import '../../../core/models/fpl_models.dart';

enum SuggestedChip { none, wildcard, freeHit, benchBoost, tripleCaptain }

enum ChipReason {
  availabilityUnknown,
  missingStarters,
  squadOverhaul,
  strongBench,
  captainCeiling,
  chipExpiring,
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

  static const _hitCost = 4;
  static const _maxFreeTransfers = 5;
  static const _maxSuggestedTransfers = 3;

  /// Option value of rolling a free transfer instead of using it.
  static const _rollTransferValue = 2.0;

  /// Minimum gain when the free transfer would otherwise be wasted at the cap.
  static const _cappedFreeTransferGain = 0.5;

  /// Margin a paid transfer must clear on top of the four-point hit.
  static const _hitMargin = 1.0;

  /// Share of a bench player's projection that is expected to count.
  static const _benchWeight = 0.3;

  static const _weakStarterHorizon = 4.0;
  static const _wildcardMinWeakStarters = 3;

  /// Extra horizon points a wildcard must add over the normal transfer route.
  static const _wildcardMinExtraGain = 12.0;

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
      bootstrap: bootstrap,
      projections: projections,
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
    // `form` averages over all of the club's recent matches, so absences are
    // already priced in; `points_per_game` only counts appearances.
    final recent = player.form * 0.6 + player.pointsPerGame * reliability * 0.4;
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
      final recentScore =
          recent * availability * difficultyFactor * eventFixtures.length;
      // `ep_next` already accounts for availability, fixture difficulty and
      // Double Gameweeks, so it must not be scaled by them again.
      final eventScore = offset == 0 && player.expectedPointsNext > 0
          ? player.expectedPointsNext * 0.6 + recentScore * 0.4
          : recentScore;
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
    // Unknown free transfers are treated as none so a hit is never hidden.
    final freeTransfers = _freeTransfers(team.transfers) ?? 0;
    return _planTransfers(
      team: team,
      bootstrap: bootstrap,
      projections: projections,
      maxTransfers: _maxSuggestedTransfers,
      hitCostFor: (index) => index < freeTransfers ? 0 : _hitCost,
      minGainFor: (index, hitCost) {
        if (hitCost > 0) return hitCost + _hitMargin;
        if (index == 0 && freeTransfers >= _maxFreeTransfers) {
          return _cappedFreeTransferGain;
        }
        return _rollTransferValue;
      },
    );
  }

  /// Greedily builds a transfer plan whose moves are valid together: they
  /// share one bank, respect the club limit and never reuse a player.
  List<TransferSuggestion> _planTransfers({
    required MyTeam team,
    required FplBootstrap bootstrap,
    required Map<int, PlayerProjection> projections,
    required int maxTransfers,
    required int Function(int index) hitCostFor,
    required double Function(int index, int hitCost) minGainFor,
  }) {
    final squadIds = team.picks.map((pick) => pick.elementId).toSet();
    final clubCounts = <int, int>{};
    for (final id in squadIds) {
      final player = bootstrap.players[id];
      if (player == null) continue;
      clubCounts[player.teamId] = (clubCounts[player.teamId] ?? 0) + 1;
    }
    var bank = team.transfers.bank ?? team.summary.bank ?? 0;
    final outgoingIds = <int>{};
    final incomingIds = <int>{};
    final plan = <TransferSuggestion>[];

    while (plan.length < maxTransfers) {
      final hitCost = hitCostFor(plan.length);
      _Upgrade? best;
      for (final pick in team.picks) {
        if (outgoingIds.contains(pick.elementId)) continue;
        final upgrade = _bestUpgrade(
          pick: pick,
          bootstrap: bootstrap,
          projections: projections,
          excludedIds: {...squadIds, ...incomingIds},
          bank: bank,
          clubCounts: clubCounts,
        );
        if (upgrade != null && (best == null || upgrade.gain > best.gain)) {
          best = upgrade;
        }
      }
      if (best == null || best.gain < minGainFor(plan.length, hitCost)) break;

      plan.add(
        TransferSuggestion(
          outPlayer: best.outPlayer,
          inPlayer: best.inPlayer,
          projectedGain: best.gain,
          hitCost: hitCost,
        ),
      );
      bank += best.sellingPrice - best.cost;
      outgoingIds.add(best.outPlayer.id);
      incomingIds.add(best.inPlayer.id);
      clubCounts[best.outPlayer.teamId] =
          (clubCounts[best.outPlayer.teamId] ?? 1) - 1;
      clubCounts[best.inPlayer.teamId] =
          (clubCounts[best.inPlayer.teamId] ?? 0) + 1;
    }
    return plan;
  }

  _Upgrade? _bestUpgrade({
    required TeamPick pick,
    required FplBootstrap bootstrap,
    required Map<int, PlayerProjection> projections,
    required Set<int> excludedIds,
    required int bank,
    required Map<int, int> clubCounts,
  }) {
    final outgoing = bootstrap.players[pick.elementId];
    final outgoingProjection = projections[pick.elementId];
    if (outgoing == null || outgoingProjection == null) return null;
    final sellingPrice = pick.sellingPrice ?? outgoing.nowCost ?? 0;

    PlayerProjection? best;
    for (final candidate in projections.values) {
      final cost = candidate.player.nowCost;
      if (excludedIds.contains(candidate.player.id) ||
          candidate.player.positionId != outgoing.positionId ||
          !candidate.player.canSelect ||
          candidate.availability < 0.5 ||
          cost == null ||
          cost > sellingPrice + bank) {
        continue;
      }
      final clubCount =
          (clubCounts[candidate.player.teamId] ?? 0) -
          (candidate.player.teamId == outgoing.teamId ? 1 : 0);
      if (clubCount >= 3) continue;
      if (best == null || candidate.horizonPoints > best.horizonPoints) {
        best = candidate;
      }
    }
    if (best == null) return null;

    // Only part of a bench player's projection is expected to count.
    final weight = pick.position > 11 ? _benchWeight : 1.0;
    final gain =
        (best.horizonPoints - outgoingProjection.horizonPoints) * weight;
    if (gain <= 0) return null;
    return _Upgrade(
      outPlayer: outgoing,
      inPlayer: best.player,
      gain: gain,
      cost: best.player.nowCost!,
      sellingPrice: sellingPrice,
    );
  }

  (SuggestedChip, ChipReason) _chipDecision({
    required MyTeam team,
    required FplBootstrap bootstrap,
    required Map<int, PlayerProjection> projections,
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

    if (available('wildcard') &&
        _wildcardWorthIt(
          team: team,
          bootstrap: bootstrap,
          projections: projections,
          starters: starters,
          transferIdeas: transferIdeas,
        )) {
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

    final expiring = _forcedExpiringChip(
      team: team,
      gameweekId: gameweekId,
      benchPoints: bench.length == 4 ? benchPoints : 0,
      captainPoints: captain?.nextPoints ?? 0,
    );
    if (expiring != null) return (expiring, ChipReason.chipExpiring);

    return (SuggestedChip.none, ChipReason.hold);
  }

  /// A wildcard is worth it only when several starters are weak and an
  /// unlimited rebuild beats the normal free-transfer/hit route by a margin.
  bool _wildcardWorthIt({
    required MyTeam team,
    required FplBootstrap bootstrap,
    required Map<int, PlayerProjection> projections,
    required List<PlayerProjection> starters,
    required List<TransferSuggestion> transferIdeas,
  }) {
    // Bench fodder is weak by design, so only starters are counted.
    final weakStarters = starters
        .where(
          (player) =>
              player.nextFixtureCount == 0 ||
              player.availability < 0.5 ||
              player.horizonPoints < _weakStarterHorizon,
        )
        .length;
    if (weakStarters < _wildcardMinWeakStarters) return false;

    final rebuild = _planTransfers(
      team: team,
      bootstrap: bootstrap,
      projections: projections,
      maxTransfers: team.picks.length,
      hitCostFor: (_) => 0,
      minGainFor: (_, _) => _cappedFreeTransferGain,
    );
    double netGain(List<TransferSuggestion> plan) =>
        plan.fold(0.0, (total, item) => total + item.netProjectedGain);
    return netGain(rebuild) - netGain(transferIdeas) >= _wildcardMinExtraGain;
  }

  /// Returns a chip that must be played now because the remaining Gameweeks
  /// in its window are no more than the chips still unused in that window.
  SuggestedChip? _forcedExpiringChip({
    required MyTeam team,
    required int gameweekId,
    required double benchPoints,
    required double captainPoints,
  }) {
    final expiring = <String>{};
    final windows = team.chips
        .where((chip) => chip.isAvailableFor(gameweekId))
        .map((chip) => chip.stopEvent)
        .whereType<int>()
        .toSet();
    for (final stop in windows) {
      final unused = team.chips
          .where(
            (chip) => chip.stopEvent == stop && chip.isAvailableFor(gameweekId),
          )
          .map((chip) => chip.name)
          .toSet();
      if (unused.length >= stop - gameweekId + 1) expiring.addAll(unused);
    }
    if (expiring.isEmpty) return null;

    // Prefer the cheap one-week chips by their expected extra points.
    final oneWeek = <SuggestedChip, double>{
      if (expiring.contains('bboost')) SuggestedChip.benchBoost: benchPoints,
      if (expiring.contains('3xc')) SuggestedChip.tripleCaptain: captainPoints,
    };
    if (oneWeek.isNotEmpty) {
      return oneWeek.entries.reduce((a, b) => b.value > a.value ? b : a).key;
    }
    if (expiring.contains('wildcard')) return SuggestedChip.wildcard;
    if (expiring.contains('freehit')) return SuggestedChip.freeHit;
    return null;
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

class _Upgrade {
  const _Upgrade({
    required this.outPlayer,
    required this.inPlayer,
    required this.gain,
    required this.cost,
    required this.sellingPrice,
  });

  final FplPlayer outPlayer;
  final FplPlayer inPlayer;
  final double gain;
  final int cost;
  final int sellingPrice;
}
