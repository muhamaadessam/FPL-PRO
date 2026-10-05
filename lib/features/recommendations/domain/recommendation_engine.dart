import 'dart:math' as math;

import '../../../core/models/fpl_models.dart';

enum SuggestedChip { none, wildcard, freeHit, benchBoost, tripleCaptain }

enum ChipReason {
  availabilityUnknown,
  missingStarters,
  squadOverhaul,
  strongBench,
  captainCeiling,
  chipExpiring,
  chipActive,
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

  /// Rough 80% band for the next Gameweek. FPL scores are high-variance, so
  /// this heuristic uses a standard deviation of 1.6 × √points.
  (double, double) get nextRange {
    final spread = 1.28 * 1.6 * math.sqrt(math.max(nextPoints, 0));
    return (math.max(0, nextPoints - spread), nextPoints + spread);
  }
}

/// A bench player who should start instead of a current starter.
class LineupChange {
  const LineupChange({required this.starting, required this.benched});

  final PlayerProjection starting;
  final PlayerProjection benched;
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
    this.lineupEvaluated = false,
    this.lineupChanges = const [],
    this.suggestedBench = const [],
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

  /// Whether the squad was complete enough to pick a best legal XI.
  final bool lineupEvaluated;
  final List<LineupChange> lineupChanges;

  /// Suggested bench in autosub order: reserve goalkeeper first.
  final List<PlayerProjection> suggestedBench;
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

  // 2026/27 scoring by position id (1 GKP, 2 DEF, 3 MID, 4 FWD).
  static const _goalPoints = {1: 10, 2: 6, 3: 5, 4: 4};
  static const _assistPoints = 3;
  static const _cleanSheetPoints = {1: 4, 2: 4, 3: 1, 4: 0};
  static const _appearancePoints = 2;
  static const _defensiveContributionPoints = 2;
  static const _defensiveContributionThreshold = {2: 10, 3: 12, 4: 12};

  /// Minutes before underlying per-90 stats are trusted at all, and the
  /// minutes at which they reach their full blend weight.
  static const _minUnderlyingMinutes = 270;
  static const _fullUnderlyingMinutes = 900;
  static const _maxUnderlyingWeight = 0.4;

  /// Share of points driven by the opponent's defence (attack) and attack
  /// (defence) when a player has no underlying stats; the rest is neutral.
  static const _defaultAttackShare = {1: 0.0, 2: 0.25, 3: 0.6, 4: 0.75};
  static const _defaultDefenceShare = {1: 0.6, 2: 0.45, 3: 0.1, 4: 0.0};

  /// Recent matches weigh more than the season when estimating minutes.
  static const _recentMinutesWeight = 0.7;

  /// Weight of the season start rate against the season minutes share.
  static const _startRateWeight = 0.5;

  // Legal squad and XI shape by position id: (squad size, XI min, XI max).
  static const _squadShape = {
    1: (2, 1, 1),
    2: (5, 3, 5),
    3: (5, 2, 5),
    4: (3, 1, 3),
  };

  RecommendationResult build({
    required FplBootstrap bootstrap,
    required List<FplFixture> fixtures,
    required MyTeam team,
    required int gameweekId,
    Map<int, List<int>> recentMinutes = const {},
  }) {
    final strengths = _TeamStrengths.from(bootstrap.teams);
    final projections = {
      for (final player in bootstrap.players.values)
        player.id: _project(
          player,
          fixtures,
          gameweekId,
          strengths,
          recentMinutes[player.id],
        ),
    };
    final selectable =
        projections.values
            .where(
              (projection) =>
                  projection.player.canSelect && projection.horizonPoints > 0,
            )
            .toList()
          ..sort((a, b) => b.horizonPoints.compareTo(a.horizonPoints));

    final currentStarters = team.picks
        .where((pick) => pick.position <= 11)
        .map((pick) => projections[pick.elementId])
        .whereType<PlayerProjection>()
        .toList();
    final currentBench = team.picks
        .where((pick) => pick.position > 11)
        .map((pick) => projections[pick.elementId])
        .whereType<PlayerProjection>()
        .toList();
    final lineup = _bestLineup(
      team.picks
          .map((pick) => projections[pick.elementId])
          .whereType<PlayerProjection>()
          .toList(),
    );
    final starters = [...(lineup?.$1 ?? currentStarters)]
      ..sort((a, b) => b.nextPoints.compareTo(a.nextPoints));
    final bench = lineup?.$2 ?? currentBench;
    final activeChip = team.chips
        .where((chip) => chip.statusForEntry == 'active')
        .map((chip) => chip.name)
        .firstOrNull;
    final transferIdeas = _transferIdeas(
      team,
      bootstrap,
      projections,
      activeChip,
    );
    final chipDecision = _chipDecision(
      team: team,
      bootstrap: bootstrap,
      projections: projections,
      starters: starters,
      bench: bench,
      transferIdeas: transferIdeas,
      gameweekId: gameweekId,
      activeChip: activeChip,
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
      lineupEvaluated: lineup != null,
      lineupChanges: lineup == null
          ? const []
          : _lineupChanges(currentStarters, lineup.$1),
      suggestedBench: lineup?.$2 ?? const [],
    );
  }

  /// Best legal XI by next-Gameweek projection, or null when the squad is
  /// not a complete 2/5/5/3 squad. Filling each position's minimum first and
  /// then the best remaining players within the maximums is optimal here.
  (List<PlayerProjection>, List<PlayerProjection>)? _bestLineup(
    List<PlayerProjection> squad,
  ) {
    final byPosition = {
      for (final position in _squadShape.keys)
        position:
            squad.where((item) => item.player.positionId == position).toList()
              ..sort((a, b) => b.nextPoints.compareTo(a.nextPoints)),
    };
    for (final MapEntry(key: position, value: (size, _, _))
        in _squadShape.entries) {
      if (byPosition[position]!.length != size) return null;
    }

    final starters = <PlayerProjection>[];
    for (final MapEntry(key: position, value: (_, min, _))
        in _squadShape.entries) {
      starters.addAll(byPosition[position]!.take(min));
    }
    final remaining =
        squad
            .where(
              (item) => !starters.contains(item) && item.player.positionId != 1,
            )
            .toList()
          ..sort((a, b) => b.nextPoints.compareTo(a.nextPoints));
    for (final candidate in remaining) {
      if (starters.length == 11) break;
      final position = candidate.player.positionId;
      final count = starters
          .where((item) => item.player.positionId == position)
          .length;
      if (count < _squadShape[position]!.$3) starters.add(candidate);
    }

    final bench = squad.where((item) => !starters.contains(item)).toList()
      ..sort((a, b) {
        final goalkeeperFirst = (b.player.positionId == 1 ? 1 : 0).compareTo(
          a.player.positionId == 1 ? 1 : 0,
        );
        return goalkeeperFirst != 0
            ? goalkeeperFirst
            : b.nextPoints.compareTo(a.nextPoints);
      });
    return (starters, bench);
  }

  List<LineupChange> _lineupChanges(
    List<PlayerProjection> current,
    List<PlayerProjection> suggested,
  ) {
    int byPoints(PlayerProjection a, PlayerProjection b) =>
        b.nextPoints.compareTo(a.nextPoints);
    final currentIds = current.map((item) => item.player.id).toSet();
    final suggestedIds = suggested.map((item) => item.player.id).toSet();
    final starting =
        suggested.where((item) => !currentIds.contains(item.player.id)).toList()
          ..sort(byPoints);
    final benched =
        current.where((item) => !suggestedIds.contains(item.player.id)).toList()
          ..sort((a, b) => byPoints(b, a));
    return [
      for (var i = 0; i < starting.length && i < benched.length; i++)
        LineupChange(starting: starting[i], benched: benched[i]),
    ];
  }

  PlayerProjection _project(
    FplPlayer player,
    List<FplFixture> fixtures,
    int gameweekId,
    _TeamStrengths? strengths,
    List<int>? recentMinutes,
  ) {
    final availability = _availability(player);
    final reliability = _reliability(player, gameweekId, recentMinutes);
    // `form` averages over all of the club's recent matches, so absences are
    // already priced in; `points_per_game` only counts appearances.
    final formScore =
        player.form * 0.6 + player.pointsPerGame * reliability * 0.4;
    final underlying = _underlying(player, reliability);
    final underlyingWeight = underlying == null
        ? 0.0
        : _maxUnderlyingWeight *
              (player.minutes / _fullUnderlyingMinutes).clamp(0.0, 1.0);
    final recent =
        formScore * (1 - underlyingWeight) +
        (underlying?.points ?? 0) * underlyingWeight;
    final attackShare =
        underlying?.attackShare ?? _defaultAttackShare[player.positionId] ?? 0;
    final defenceShare =
        underlying?.defenceShare ??
        _defaultDefenceShare[player.positionId] ??
        0;
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
      final fixtureFactor = eventFixtures.fold(
        0.0,
        (total, fixture) =>
            total +
            _fixtureFactor(
              player.teamId,
              fixture,
              strengths,
              attackShare: attackShare,
              defenceShare: defenceShare,
            ),
      );
      final recentScore = recent * availability * fixtureFactor;
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
    String? activeChip,
  ) {
    final benchWeight = activeChip == 'bboost' ? 1.0 : _benchWeight;
    if (activeChip == 'wildcard' || activeChip == 'freehit') {
      // Transfers are free this Gameweek, so there is no hit or roll value.
      return _planTransfers(
        team: team,
        bootstrap: bootstrap,
        projections: projections,
        maxTransfers: _maxSuggestedTransfers,
        benchWeight: benchWeight,
        hitCostFor: (_) => 0,
        minGainFor: (_, _) => _cappedFreeTransferGain,
      );
    }
    // Unknown free transfers are treated as none so a hit is never hidden.
    final freeTransfers = _freeTransfers(team.transfers) ?? 0;
    return _planTransfers(
      team: team,
      bootstrap: bootstrap,
      projections: projections,
      maxTransfers: _maxSuggestedTransfers,
      benchWeight: benchWeight,
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
    required double benchWeight,
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
          benchWeight: benchWeight,
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
    required double benchWeight,
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
    final weight = pick.position > 11 ? benchWeight : 1.0;
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
    required String? activeChip,
  }) {
    if (team.chips.isEmpty) {
      return (SuggestedChip.none, ChipReason.availabilityUnknown);
    }
    // Only one chip can be played per Gameweek.
    final active = switch (activeChip) {
      'wildcard' => SuggestedChip.wildcard,
      'freehit' => SuggestedChip.freeHit,
      'bboost' => SuggestedChip.benchBoost,
      '3xc' => SuggestedChip.tripleCaptain,
      _ => null,
    };
    if (active != null) return (active, ChipReason.chipActive);
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
      benchWeight: _benchWeight,
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

  /// Expected share of the available minutes. Recent matches, when known,
  /// dominate so a new starter or a dropped player is picked up quickly.
  double _reliability(
    FplPlayer player,
    int gameweekId,
    List<int>? recentMinutes,
  ) {
    final matches = (gameweekId - 1).clamp(1, 38);
    final minutesShare = player.minutes / (90 * matches);
    final starts = player.starts;
    // Starting earns the full appearance points and keeps a clean sheet even
    // when subbed after 60 minutes, so the start rate counts as much as
    // minutes. Unknown starts fall back to minutes alone.
    final played = starts == null
        ? minutesShare
        : minutesShare * (1 - _startRateWeight) +
              (starts / matches).clamp(0.0, 1.0) * _startRateWeight;
    final season = player.minutes == 0 ? 0.55 : played.clamp(0.45, 1.0);
    if (recentMinutes == null || recentMinutes.isEmpty) return season;
    final recent =
        recentMinutes.fold(0, (total, minutes) => total + minutes) /
        (90 * recentMinutes.length);
    return (recent * _recentMinutesWeight + season * (1 - _recentMinutesWeight))
        .clamp(0.2, 1.0);
  }

  /// Fixture multiplier around 1.0. With team strengths, attacking returns
  /// scale with the opponent's defence and clean-sheet returns with its
  /// attack; otherwise the official FDR is used for the whole projection.
  double _fixtureFactor(
    int teamId,
    FplFixture fixture,
    _TeamStrengths? strengths, {
    required double attackShare,
    required double defenceShare,
  }) {
    final factors = strengths?.factors(teamId, fixture);
    if (factors == null) {
      return 1.24 - (_difficultyFor(teamId, fixture) * 0.08);
    }
    final (attack, defence) = factors;
    return attackShare * attack +
        defenceShare * defence +
        (1 - attackShare - defenceShare);
  }

  /// Per-match points implied by season xG, xA, xGC, defensive actions,
  /// bonus and saves, plus the share of them that depends on the opponent.
  _Underlying? _underlying(FplPlayer player, double reliability) {
    final minutes = player.minutes;
    final expectedConceded = player.expectedGoalsConceded;
    if (minutes < _minUnderlyingMinutes || expectedConceded == null) {
      return null;
    }
    var expectedGoals = player.expectedGoals;
    var expectedAssists = player.expectedAssists;
    if (expectedGoals == null || expectedAssists == null) {
      final involvements = player.expectedGoalInvolvements;
      if (involvements == null) return null;
      // Without the split, assume involvements are half goals, half assists.
      expectedGoals = involvements / 2;
      expectedAssists = involvements / 2;
    }

    final position = player.positionId;
    final per90 = 90 / minutes;
    final attack =
        expectedGoals * per90 * (_goalPoints[position] ?? 0) +
        expectedAssists * per90 * _assistPoints;

    final concededPer90 = expectedConceded * per90;
    final cleanSheet =
        math.exp(-concededPer90) * (_cleanSheetPoints[position] ?? 0);
    final concededPenalty = position <= 2 ? concededPer90 / 2 : 0.0;
    // Floored at zero so the opponent-dependent share stays meaningful.
    final defence = math.max(0.0, cleanSheet - concededPenalty);

    final threshold = _defensiveContributionThreshold[position];
    final actions = player.defensiveContribution;
    final defensiveContribution = threshold == null || actions == null
        ? 0.0
        : _defensiveContributionPoints *
              _poissonAtLeast(actions * per90, threshold);
    final neutral =
        _appearancePoints +
        defensiveContribution +
        (player.bonus ?? 0) * per90 +
        (position == 1 ? (player.saves ?? 0) * per90 / 3 : 0);

    final total = attack + defence + neutral;
    return _Underlying(
      points: total * reliability,
      attackShare: attack / total,
      defenceShare: defence / total,
    );
  }

  /// P(X >= threshold) for X ~ Poisson(mean).
  double _poissonAtLeast(double mean, int threshold) {
    var term = math.exp(-mean);
    var below = 0.0;
    for (var k = 0; k < threshold; k++) {
      below += term;
      term *= mean / (k + 1);
    }
    return (1 - below).clamp(0.0, 1.0);
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
      // Injured, suspended or unavailable without a published chance.
      'i' || 's' || 'n' => 0,
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

class _Underlying {
  const _Underlying({
    required this.points,
    required this.attackShare,
    required this.defenceShare,
  });

  final double points;
  final double attackShare;
  final double defenceShare;
}

/// Opponent strength relative to the league average, from the official
/// team `strength_attack_*` and `strength_defence_*` ratings.
class _TeamStrengths {
  const _TeamStrengths(this._teams, this._averageAttack, this._averageDefence);

  /// Exponent that widens the ratings' narrow spread into a fixture swing.
  static const _sensitivity = 2.0;
  static const _minFactor = 0.6;
  static const _maxFactor = 1.5;

  final Map<int, FplTeam> _teams;
  final double _averageAttack;
  final double _averageDefence;

  static _TeamStrengths? from(Map<int, FplTeam> teams) {
    final rated = {
      for (final team in teams.values)
        if (team.strengthAttackHome != null &&
            team.strengthAttackAway != null &&
            team.strengthDefenceHome != null &&
            team.strengthDefenceAway != null)
          team.id: team,
    };
    if (rated.length < 2) return null;
    double average(Iterable<int> values) =>
        values.fold(0, (total, value) => total + value) / values.length;
    // Pooled over both venues so home advantage is kept in the factors.
    return _TeamStrengths(
      rated,
      average(
        rated.values.expand(
          (team) => [team.strengthAttackHome!, team.strengthAttackAway!],
        ),
      ),
      average(
        rated.values.expand(
          (team) => [team.strengthDefenceHome!, team.strengthDefenceAway!],
        ),
      ),
    );
  }

  /// (attack, defence) multipliers for [teamId] in [fixture], or null when
  /// either side has no rating.
  (double, double)? factors(int teamId, FplFixture fixture) {
    final isHome = teamId == fixture.homeTeamId;
    if (!_teams.containsKey(teamId)) return null;
    final opponent = _teams[isHome ? fixture.awayTeamId : fixture.homeTeamId];
    if (opponent == null) return null;
    final opponentAttack = isHome
        ? opponent.strengthAttackAway!
        : opponent.strengthAttackHome!;
    final opponentDefence = isHome
        ? opponent.strengthDefenceAway!
        : opponent.strengthDefenceHome!;
    double scale(double ratio) =>
        math.pow(ratio, _sensitivity).toDouble().clamp(_minFactor, _maxFactor);
    return (
      scale(_averageDefence / opponentDefence),
      scale(_averageAttack / opponentAttack),
    );
  }
}
