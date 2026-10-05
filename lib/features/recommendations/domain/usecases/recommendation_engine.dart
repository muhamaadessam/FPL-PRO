import 'dart:math' as math;

import '../../../fixtures/data/models/fpl_models.dart';
import '../../../team/data/models/team_models.dart';

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

  /// Rough 80% band for the next Gameweek; see [likelyPointsRange].
  (double, double) get nextRange => likelyPointsRange(nextPoints);
}

/// Rough 80% band around a single-Gameweek projection. FPL scores are
/// high-variance, so this heuristic uses a standard deviation of 1.6 × √points.
(double, double) likelyPointsRange(double points) {
  final spread = 1.28 * 1.6 * math.sqrt(math.max(points, 0));
  return (math.max(0, points - spread), points + spread);
}

enum PlayerTrend { rising, steady, falling }

class PlayerAnalysis {
  const PlayerAnalysis({
    required this.pick,
    required this.projection,
    required this.rating,
    required this.expectedPoints,
    required this.recentPoints,
    required this.seasonPoints,
    required this.previousSeasonPoints,
    required this.fixtureScore,
    required this.reliability,
    required this.trend,
    required this.nextOpponentTeamIds,
    required this.nextFixturesAtHome,
  });

  final TeamPick pick;
  final PlayerProjection projection;
  final int rating;
  final double expectedPoints;
  final double recentPoints;
  final double seasonPoints;
  final double? previousSeasonPoints;
  final int fixtureScore;
  final double reliability;
  final PlayerTrend trend;
  final List<int> nextOpponentTeamIds;
  final List<bool> nextFixturesAtHome;

  bool get isStarter => pick.position <= 11;

  PlayerAnalysis copyWith({
    TeamPick? pick,
    PlayerProjection? projection,
    int? rating,
    double? expectedPoints,
    double? recentPoints,
    double? seasonPoints,
    double? previousSeasonPoints,
    int? fixtureScore,
    double? reliability,
    PlayerTrend? trend,
    List<int>? nextOpponentTeamIds,
    List<bool>? nextFixturesAtHome,
  }) {
    return PlayerAnalysis(
      pick: pick ?? this.pick,
      projection: projection ?? this.projection,
      rating: rating ?? this.rating,
      expectedPoints: expectedPoints ?? this.expectedPoints,
      recentPoints: recentPoints ?? this.recentPoints,
      seasonPoints: seasonPoints ?? this.seasonPoints,
      previousSeasonPoints: previousSeasonPoints ?? this.previousSeasonPoints,
      fixtureScore: fixtureScore ?? this.fixtureScore,
      reliability: reliability ?? this.reliability,
      trend: trend ?? this.trend,
      nextOpponentTeamIds: nextOpponentTeamIds ?? this.nextOpponentTeamIds,
      nextFixturesAtHome: nextFixturesAtHome ?? this.nextFixturesAtHome,
    );
  }
}

class SquadAnalysis {
  const SquadAnalysis({
    required this.rating,
    required this.expectedStartingPoints,
    required this.expectedBenchPoints,
    required this.averageStarterRating,
    required this.bestLegalLineupPoints,
    required this.selectionEfficiency,
    required this.players,
    required this.currentSeasonCoverage,
    required this.previousSeasonPlayers,
    this.suggestedStartingIds = const [],
  });

  final int rating;
  final double expectedStartingPoints;
  final double expectedBenchPoints;
  final int averageStarterRating;
  final double bestLegalLineupPoints;
  final int selectionEfficiency;
  final List<PlayerAnalysis> players;
  final int currentSeasonCoverage;
  final int previousSeasonPlayers;
  final List<int> suggestedStartingIds;

  List<PlayerAnalysis> get starters =>
      players.where((player) => player.isStarter).toList(growable: false);

  List<PlayerAnalysis> get bench =>
      players.where((player) => !player.isStarter).toList(growable: false);
}

class TransferSuggestion {
  const TransferSuggestion({
    required this.outProjection,
    required this.inProjection,
    required this.projectedGain,
    required this.hitCost,
  });

  final PlayerProjection outProjection;
  final PlayerProjection inProjection;
  final double projectedGain;
  final int hitCost;

  FplPlayer get outPlayer => outProjection.player;
  FplPlayer get inPlayer => inProjection.player;

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
    required this.squadAnalysis,
    required this.suggestedLineup,
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
  final SquadAnalysis squadAnalysis;
  final SquadAnalysis suggestedLineup;
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

  /// 2026/27 defensive actions needed for defensive contribution points, by
  /// position id. The points themselves come from `game_config.scoring`.
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
  static const _recentMatches = 5;

  /// Weight of the season start rate against the season minutes share.
  static const _startRateWeight = 0.5;

  /// [playerSummaries] supplies recent match minutes where available, which
  /// outweigh season-long minutes for those players.
  List<PlayerProjection> buildPlayerProjections({
    required FplBootstrap bootstrap,
    required List<FplFixture> fixtures,
    required int gameweekId,
    Map<int, FplPlayerSummary> playerSummaries = const {},
  }) {
    final strengths = _TeamStrengths.from(bootstrap.teams);
    final projections =
        bootstrap.players.values
            .map(
              (player) => _project(
                player,
                fixtures,
                gameweekId,
                strengths,
                _recentMinutes(playerSummaries[player.id]),
                bootstrap.scoring,
              ),
            )
            .toList()
          ..sort((a, b) => b.nextPoints.compareTo(a.nextPoints));
    return List.unmodifiable(projections);
  }

  /// Minutes in the player's most recent matches, oldest first.
  List<int>? _recentMinutes(FplPlayerSummary? summary) {
    if (summary == null || summary.history.isEmpty) return null;
    final history = [...summary.history]
      ..sort((a, b) => a.round.compareTo(b.round));
    return history
        .skip(math.max(0, history.length - _recentMatches))
        .map((match) => match.minutes)
        .toList(growable: false);
  }

  RecommendationResult build({
    required FplBootstrap bootstrap,
    required List<FplFixture> fixtures,
    required MyTeam team,
    required int gameweekId,
    Map<int, FplPlayerSummary> playerSummaries = const {},
  }) {
    final allProjections = buildPlayerProjections(
      bootstrap: bootstrap,
      fixtures: fixtures,
      gameweekId: gameweekId,
      playerSummaries: playerSummaries,
    );
    final projections = {
      for (final projection in allProjections) projection.player.id: projection,
    };
    final selectable =
        allProjections
            .where(
              (projection) =>
                  projection.player.canSelect && projection.horizonPoints > 0,
            )
            .toList()
          ..sort((a, b) => b.horizonPoints.compareTo(a.horizonPoints));

    final squadAnalysis = _analyzeSquad(
      team: team,
      projections: projections,
      fixtures: fixtures,
      gameweekId: gameweekId,
      playerSummaries: playerSummaries,
      scoring: bootstrap.scoring,
    );
    final suggestedLineup = buildSuggestedLineup(squadAnalysis);
    final starters = suggestedLineup.starters
      ..sort((a, b) => b.expectedPoints.compareTo(a.expectedPoints));
    final captainCandidates = starters
        .where((p) => p.expectedPoints > 0)
        .toList();
    final bench = suggestedLineup.bench.map((p) => p.projection).toList();
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
      starters: starters.map((p) => p.projection).toList(),
      bench: bench,
      transferIdeas: transferIdeas,
      gameweekId: gameweekId,
      activeChip: activeChip,
    );

    return RecommendationResult(
      gameweekId: gameweekId,
      captain: captainCandidates.firstOrNull?.projection,
      viceCaptain: captainCandidates.length > 1
          ? captainCandidates[1].projection
          : null,
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
      squadAnalysis: squadAnalysis,
      suggestedLineup: suggestedLineup,
    );
  }

  TransferSuggestion? buildTransferSuggestion({
    required MyTeam team,
    required FplBootstrap bootstrap,
    required PlayerProjection outgoing,
    required PlayerProjection incoming,
  }) {
    final outgoingPick = team.picks
        .where((pick) => pick.elementId == outgoing.player.id)
        .firstOrNull;
    final incomingPlayer = incoming.player;
    if (outgoingPick == null ||
        outgoing.player.positionId != incomingPlayer.positionId ||
        incomingPlayer.id == outgoing.player.id ||
        team.picks.any((pick) => pick.elementId == incomingPlayer.id) ||
        !incomingPlayer.canSelect ||
        incoming.availability < 0.5 ||
        incomingPlayer.nowCost == null) {
      return null;
    }

    final bank = team.transfers.bank;
    final sellingPrice = outgoingPick.sellingPrice;
    final freeTransfers = _freeTransfers(team.transfers);
    if (bank == null || sellingPrice == null || freeTransfers == null) {
      return null;
    }
    if (incomingPlayer.nowCost! > sellingPrice + bank) return null;

    final clubCount = team.picks.where((pick) {
      final player = bootstrap.players[pick.elementId];
      return player?.teamId == incomingPlayer.teamId &&
          player?.id != outgoing.player.id;
    }).length;
    if (clubCount >= 3) return null;

    return TransferSuggestion(
      outProjection: outgoing,
      inProjection: incoming,
      projectedGain: incoming.horizonPoints - outgoing.horizonPoints,
      hitCost: freeTransfers == 0 ? 4 : 0,
    );
  }

  SquadAnalysis _analyzeSquad({
    required MyTeam team,
    required Map<int, PlayerProjection> projections,
    required List<FplFixture> fixtures,
    required int gameweekId,
    required Map<int, FplPlayerSummary> playerSummaries,
    required FplScoring scoring,
  }) {
    final players = <PlayerAnalysis>[];
    for (final pick in team.picks) {
      final projection = projections[pick.elementId];
      if (projection == null) continue;
      players.add(
        _analyzePlayer(
          pick: pick,
          projection: projection,
          allProjections: projections.values,
          summary: playerSummaries[pick.elementId],
          fixtures: fixtures,
          gameweekId: gameweekId,
          scoring: scoring,
        ),
      );
    }
    players.sort((a, b) => a.pick.position.compareTo(b.pick.position));
    final currentSeasonCoverage = players
        .where(
          (player) =>
              playerSummaries[player.projection.player.id]
                  ?.history
                  .isNotEmpty ??
              false,
        )
        .length;
    final previousSeasonPlayers = players
        .where(
          (player) =>
              playerSummaries[player.projection.player.id]
                  ?.historyPast
                  .isNotEmpty ??
              false,
        )
        .length;
    return buildSquadAnalysisForPreview(
      players: players,
      currentSeasonCoverage: currentSeasonCoverage,
      previousSeasonPlayers: previousSeasonPlayers,
    );
  }

  SquadAnalysis buildSquadAnalysisForPreview({
    required List<PlayerAnalysis> players,
    required int currentSeasonCoverage,
    required int previousSeasonPlayers,
  }) {
    final starters = players.where((player) => player.isStarter).toList()
      ..sort((a, b) => a.pick.position.compareTo(b.pick.position));
    final bench = players.where((player) => !player.isStarter).toList()
      ..sort((a, b) {
        final aIsGoalkeeper = a.projection.player.positionId == 1;
        final bIsGoalkeeper = b.projection.player.positionId == 1;
        if (aIsGoalkeeper != bIsGoalkeeper) {
          return aIsGoalkeeper ? -1 : 1;
        }
        return a.pick.position.compareTo(b.pick.position);
      });
    final orderedPlayers = [...starters, ...bench];
    final starterAverage = _averageRating(starters);
    final expectedStartingPoints = starters.fold(
      0.0,
      (total, player) =>
          total + player.expectedPoints * (player.pick.isCaptain ? 2 : 1),
    );
    final bestLineup = _bestLegalLineup(orderedPlayers);
    final bestLegalLineupPoints = bestLineup.$1;
    final selectionEfficiency = bestLegalLineupPoints <= 0
        ? 0
        : (expectedStartingPoints / bestLegalLineupPoints * 100)
              .clamp(0, 100)
              .round();
    final squadQuality = starterAverage.toDouble();
    final rating = starters.isEmpty
        ? 0
        : (squadQuality * 0.8 + selectionEfficiency * 0.2).round().clamp(
            0,
            100,
          );
    return SquadAnalysis(
      rating: rating,
      expectedStartingPoints: expectedStartingPoints,
      expectedBenchPoints: bench.fold(
        0,
        (total, player) => total + player.expectedPoints,
      ),
      averageStarterRating: starterAverage,
      bestLegalLineupPoints: bestLegalLineupPoints,
      selectionEfficiency: selectionEfficiency,
      players: orderedPlayers,
      currentSeasonCoverage: currentSeasonCoverage,
      previousSeasonPlayers: previousSeasonPlayers,
      suggestedStartingIds: bestLineup.$2,
    );
  }

  SquadAnalysis buildSuggestedLineup(SquadAnalysis analysis) {
    if (analysis.players.length != 15 ||
        analysis.suggestedStartingIds.length != 11) {
      return analysis;
    }
    final startingIds = analysis.suggestedStartingIds.toSet();
    final starters =
        analysis.players
            .where((p) => startingIds.contains(p.pick.elementId))
            .toList()
          ..sort(
            (a, b) => a.projection.player.positionId.compareTo(
              b.projection.player.positionId,
            ),
          );
    final bench =
        analysis.players
            .where((p) => !startingIds.contains(p.pick.elementId))
            .toList()
          ..sort((a, b) {
            final aKeeper = a.projection.player.positionId == 1;
            final bKeeper = b.projection.player.positionId == 1;
            return aKeeper != bKeeper
                ? (aKeeper ? -1 : 1)
                : b.expectedPoints.compareTo(a.expectedPoints);
          });
    final captains = starters.where((p) => p.expectedPoints > 0).toList()
      ..sort((a, b) => b.expectedPoints.compareTo(a.expectedPoints));
    final captainId = captains.firstOrNull?.pick.elementId;
    final viceId = captains.length > 1 ? captains[1].pick.elementId : null;
    final ordered = [...starters, ...bench];
    return buildSquadAnalysisForPreview(
      players: [
        for (var i = 0; i < ordered.length; i++)
          ordered[i].copyWith(
            pick: ordered[i].pick.copyWith(
              position: i + 1,
              isCaptain: ordered[i].pick.elementId == captainId,
              isViceCaptain: ordered[i].pick.elementId == viceId,
              multiplier: i >= 11
                  ? 0
                  : (ordered[i].pick.elementId == captainId ? 2 : 1),
            ),
          ),
      ],
      currentSeasonCoverage: analysis.currentSeasonCoverage,
      previousSeasonPlayers: analysis.previousSeasonPlayers,
    );
  }

  bool isLegalStartingLineup(Iterable<PlayerAnalysis> players) {
    final squad = players.toList(growable: false);
    final starters = squad.where((player) => player.isStarter).toList();
    if (squad.length < 11) {
      return starters
              .where((player) => player.projection.player.positionId == 1)
              .length <=
          1;
    }
    if (starters.length != 11) return false;

    final positionCounts = <int, int>{};
    for (final player in starters) {
      positionCounts.update(
        player.projection.player.positionId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    return _hasLegalPositionCounts(positionCounts);
  }

  PlayerAnalysis _analyzePlayer({
    required TeamPick pick,
    required PlayerProjection projection,
    required Iterable<PlayerProjection> allProjections,
    required FplPlayerSummary? summary,
    required List<FplFixture> fixtures,
    required int gameweekId,
    required FplScoring scoring,
  }) {
    final player = projection.player;
    final history = [...?summary?.history]
      ..sort((a, b) => a.round.compareTo(b.round));
    final recentPoints = _weightedRecentPoints(history);
    final previousSeasonPoints = summary?.historyPast.isEmpty ?? true
        ? null
        : summary!.historyPast.last.pointsPer90;
    final reliability = _reliability(player, history, gameweekId);
    final nextFixtures = fixtures
        .where(
          (fixture) =>
              fixture.gameweekId == gameweekId &&
              (fixture.homeTeamId == player.teamId ||
                  fixture.awayTeamId == player.teamId),
        )
        .toList(growable: false);
    final fixtureScore = _fixtureScore(projection.nextDifficulties);
    final expectedPoints = _expectedPoints(
      projection: projection,
      recentPoints: recentPoints,
      previousSeasonPoints: previousSeasonPoints,
      reliability: reliability,
      scoring: scoring,
    );
    final rating = _percentileRating(
      projection.nextPoints * 0.75 + expectedPoints * 0.25,
      allProjections
          .where(
            (candidate) =>
                candidate.player.positionId == player.positionId &&
                candidate.player.canSelect &&
                candidate.nextFixtureCount > 0,
          )
          .map((candidate) => candidate.nextPoints),
    );
    return PlayerAnalysis(
      pick: pick,
      projection: projection,
      rating: rating,
      expectedPoints: expectedPoints,
      recentPoints: recentPoints,
      seasonPoints: player.pointsPerGame,
      previousSeasonPoints: previousSeasonPoints,
      fixtureScore: fixtureScore,
      reliability: reliability,
      trend: _trend(history),
      nextOpponentTeamIds: nextFixtures
          .map(
            (fixture) => fixture.homeTeamId == player.teamId
                ? fixture.awayTeamId
                : fixture.homeTeamId,
          )
          .toList(growable: false),
      nextFixturesAtHome: nextFixtures
          .map((fixture) => fixture.homeTeamId == player.teamId)
          .toList(growable: false),
    );
  }

  double _weightedRecentPoints(List<FplPlayerHistory> history) {
    final recent = history.length <= 6
        ? history
        : history.sublist(history.length - 6);
    if (recent.isEmpty) return 0;
    var weightedPoints = 0.0;
    var totalWeight = 0.0;
    var weight = 1.0;
    for (var index = recent.length - 1; index >= 0; index--) {
      weightedPoints += recent[index].totalPoints * weight;
      totalWeight += weight;
      weight *= 0.75;
    }
    return weightedPoints / totalWeight;
  }

  double _reliability(
    FplPlayer player,
    List<FplPlayerHistory> history,
    int gameweekId,
  ) {
    if (history.isNotEmpty) {
      final minutes = history.fold<int>(
        0,
        (total, match) => total + match.minutes,
      );
      return (minutes / (history.length * 90)).clamp(0, 1);
    }
    return (player.starts / (gameweekId - 1).clamp(1, 38)).clamp(0, 1);
  }

  double _expectedPoints({
    required PlayerProjection projection,
    required double recentPoints,
    required double? previousSeasonPoints,
    required double reliability,
    required FplScoring scoring,
  }) {
    if (projection.nextFixtureCount == 0 || projection.availability == 0) {
      return 0;
    }
    var weighted = projection.nextPoints * 0.45;
    var weight = 0.45;
    if (recentPoints > 0) {
      weighted += recentPoints * 0.2;
      weight += 0.2;
    }
    if (projection.player.pointsPerGame > 0) {
      weighted += projection.player.pointsPerGame * 0.2;
      weight += 0.2;
    }
    final underlyingPoints = _underlyingPoints(projection.player, scoring);
    if (underlyingPoints > 0) {
      weighted += underlyingPoints * 0.1;
      weight += 0.1;
    }
    if (previousSeasonPoints != null && previousSeasonPoints > 0) {
      weighted += previousSeasonPoints * 0.05;
      weight += 0.05;
    }
    final availabilityFactor = 0.55 + projection.availability * 0.45;
    final reliabilityFactor = 0.8 + reliability * 0.2;
    return (weighted / weight * availabilityFactor * reliabilityFactor).clamp(
      0,
      20,
    );
  }

  int _fixtureScore(List<int> difficulties) {
    if (difficulties.isEmpty) return 0;
    final average = difficulties.reduce((a, b) => a + b) / difficulties.length;
    final base = 120 - average * 20;
    final doubleBonus = difficulties.length > 1 ? 10 : 0;
    return (base + doubleBonus).round().clamp(0, 100);
  }

  double _underlyingPoints(FplPlayer player, FplScoring scoring) {
    if (player.minutes <= 0) return 0;
    final position = player.positionId;
    final matches = player.minutes / 90;
    final expectedInvolvementsPer90 = player.expectedGoalInvolvements / matches;
    final attacking =
        expectedInvolvementsPer90 *
        ((scoring.goals[position] ?? 0) + (scoring.assists[position] ?? 0)) /
        2;
    final cleanSheets =
        player.cleanSheets / matches * (scoring.cleanSheets[position] ?? 0);
    final saves = position == 1
        ? player.saves / matches / 3 * scoring.saves
        : 0;
    return scoring.appearance + attacking + cleanSheets + saves;
  }

  PlayerTrend _trend(List<FplPlayerHistory> history) {
    if (history.length < 4) return PlayerTrend.steady;
    final recent = history.sublist(history.length - 2);
    final previous = history.sublist(
      (history.length - 4).clamp(0, history.length),
      history.length - 2,
    );
    final recentAverage =
        recent.fold<int>(0, (sum, match) => sum + match.totalPoints) /
        recent.length;
    final previousAverage =
        previous.fold<int>(0, (sum, match) => sum + match.totalPoints) /
        previous.length;
    if (recentAverage >= previousAverage + 1.5) return PlayerTrend.rising;
    if (recentAverage <= previousAverage - 1.5) return PlayerTrend.falling;
    return PlayerTrend.steady;
  }

  int _averageRating(List<PlayerAnalysis> players) {
    if (players.isEmpty) return 0;
    return (players.fold<int>(0, (sum, player) => sum + player.rating) /
            players.length)
        .round();
  }

  (double, List<int>) _bestLegalLineup(List<PlayerAnalysis> players) {
    if (players.length < 11) {
      final total = players.fold<double>(
        0,
        (sum, player) => sum + player.expectedPoints,
      );
      final captain = players.fold<double>(
        0,
        (best, player) =>
            player.expectedPoints > best ? player.expectedPoints : best,
      );
      return (total + captain, players.map((p) => p.pick.elementId).toList());
    }
    final current = players.where((p) => p.isStarter).toList();
    var best = isLegalStartingLineup(players)
        ? current.fold(0.0, (sum, p) => sum + p.expectedPoints) +
              current.fold(
                0.0,
                (top, p) => p.expectedPoints > top ? p.expectedPoints : top,
              )
        : -1.0;
    var bestIds = isLegalStartingLineup(players)
        ? current.map((p) => p.pick.elementId).toList()
        : <int>[];
    // ponytail: exhaustive search over 15 players; use formation combinations for larger squads.
    for (var mask = 0; mask < 1 << players.length; mask++) {
      var selected = 0;
      final positionCounts = <int, int>{};
      var points = 0.0;
      var captain = 0.0;
      for (var index = 0; index < players.length; index++) {
        if ((mask & (1 << index)) == 0) continue;
        selected++;
        final player = players[index];
        positionCounts.update(
          player.projection.player.positionId,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
        points += player.expectedPoints;
        if (player.expectedPoints > captain) captain = player.expectedPoints;
      }
      if (selected != 11 || !_hasLegalPositionCounts(positionCounts)) {
        continue;
      }
      final total = points + captain;
      if (total > best + 0.000001) {
        best = total;
        bestIds = [
          for (var i = 0; i < players.length; i++)
            if ((mask & (1 << i)) != 0) players[i].pick.elementId,
        ];
      }
    }
    return (best < 0 ? 0.0 : best, bestIds);
  }

  bool _hasLegalPositionCounts(Map<int, int> counts) {
    return counts[1] == 1 &&
        (counts[2] ?? 0) >= 3 &&
        (counts[2] ?? 0) <= 5 &&
        (counts[3] ?? 0) >= 2 &&
        (counts[3] ?? 0) <= 5 &&
        (counts[4] ?? 0) >= 1 &&
        (counts[4] ?? 0) <= 3;
  }

  int _percentileRating(double value, Iterable<double> comparisonValues) {
    final values = comparisonValues.toList()..sort();
    if (values.isEmpty) return 0;
    if (values.length == 1) return 100;
    final below = values.where((candidate) => candidate < value).length;
    final equal = values.where((candidate) => candidate == value).length;
    final rank = below + (equal > 0 ? (equal - 1) / 2 : 0);
    return (rank / (values.length - 1) * 100).round().clamp(0, 100);
  }

  PlayerProjection _project(
    FplPlayer player,
    List<FplFixture> fixtures,
    int gameweekId,
    _TeamStrengths? strengths,
    List<int>? recentMinutes,
    FplScoring scoring,
  ) {
    final availability = _availability(player);
    final reliability = _minutesShare(player, gameweekId, recentMinutes);
    // `form` averages over all of the club's recent matches, so absences are
    // already priced in; `points_per_game` only counts appearances.
    final formScore =
        player.form * 0.6 + player.pointsPerGame * reliability * 0.4;
    final underlying = _underlying(player, reliability, scoring);
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
      // An unavailable player scores nothing, even if ep_next is stale.
      final eventScore =
          offset == 0 && player.expectedPointsNext > 0 && availability > 0
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
    // Like buildTransferSuggestion, suggest nothing without the real bank.
    if (team.transfers.bank == null) return const [];
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
    final freeTransfers = _freeTransfers(team.transfers);
    if (freeTransfers == null) return const [];
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
    var bank = team.transfers.bank ?? 0;
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
          outProjection: best.outProjection,
          inProjection: best.inProjection,
          projectedGain: best.gain,
          hitCost: hitCost,
        ),
      );
      final outPlayer = best.outProjection.player;
      final inPlayer = best.inProjection.player;
      bank += best.sellingPrice - best.cost;
      outgoingIds.add(outPlayer.id);
      incomingIds.add(inPlayer.id);
      clubCounts[outPlayer.teamId] = (clubCounts[outPlayer.teamId] ?? 1) - 1;
      clubCounts[inPlayer.teamId] = (clubCounts[inPlayer.teamId] ?? 0) + 1;
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
    final sellingPrice = pick.sellingPrice;
    if (outgoing == null ||
        outgoingProjection == null ||
        sellingPrice == null) {
      return null;
    }

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
      outProjection: outgoingProjection,
      inProjection: best,
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
  double _minutesShare(
    FplPlayer player,
    int gameweekId,
    List<int>? recentMinutes,
  ) {
    final matches = (gameweekId - 1).clamp(1, 38);
    final minutesShare = player.minutes / (90 * matches);
    // Starting earns the full appearance points and keeps a clean sheet even
    // when subbed after 60 minutes, so the start rate counts as much as
    // minutes.
    final played =
        minutesShare * (1 - _startRateWeight) +
        (player.starts / matches).clamp(0.0, 1.0) * _startRateWeight;
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
  _Underlying? _underlying(
    FplPlayer player,
    double reliability,
    FplScoring scoring,
  ) {
    final minutes = player.minutes;
    final expectedConceded = player.expectedGoalsConceded;
    final involvements = player.expectedGoalInvolvements;
    // Missing expected stats parse as zero; after 270 minutes a genuine zero
    // for both is not realistic, so treat that as no data.
    if (minutes < _minUnderlyingMinutes ||
        (expectedConceded <= 0 && involvements <= 0)) {
      return null;
    }
    var expectedGoals = player.expectedGoals;
    var expectedAssists = player.expectedAssists;
    if (expectedGoals + expectedAssists <= 0 && involvements > 0) {
      // Without the split, assume involvements are half goals, half assists.
      expectedGoals = involvements / 2;
      expectedAssists = involvements / 2;
    }

    final position = player.positionId;
    final per90 = 90 / minutes;
    final attack =
        expectedGoals * per90 * (scoring.goals[position] ?? 0) +
        expectedAssists * per90 * (scoring.assists[position] ?? 0);

    final concededPer90 = expectedConceded * per90;
    final cleanSheet =
        math.exp(-concededPer90) * (scoring.cleanSheets[position] ?? 0);
    // Conceded points are scored per two goals and are zero or negative.
    final concededPenalty =
        -(scoring.goalsConceded[position] ?? 0) * concededPer90 / 2;
    // Floored at zero so the opponent-dependent share stays meaningful.
    final defence = math.max(0.0, cleanSheet - concededPenalty);

    final threshold = _defensiveContributionThreshold[position];
    final defensiveContribution = threshold == null
        ? 0.0
        : (scoring.defensiveContribution[position] ?? 0) *
              _poissonAtLeast(player.defensiveContribution * per90, threshold);
    final neutral =
        scoring.appearance +
        defensiveContribution +
        player.bonus * per90 +
        (position == 1 ? player.saves * per90 / 3 * scoring.saves : 0);

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
    if (!player.canSelect || player.isUnavailableNextRound) return 0;
    final chance = player.chanceOfPlayingNextRound;
    if (chance != null) return (chance / 100).clamp(0, 1);
    return player.isDoubtfulNextRound ? 0.75 : 1;
  }

  int? _freeTransfers(TeamTransferState transfers) {
    final limit = transfers.limit;
    final made = transfers.made;
    if (limit == null || made == null) return null;
    return (limit - made).clamp(0, 5);
  }
}

class _Upgrade {
  const _Upgrade({
    required this.outProjection,
    required this.inProjection,
    required this.gain,
    required this.cost,
    required this.sellingPrice,
  });

  final PlayerProjection outProjection;
  final PlayerProjection inProjection;
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
  static const _missingRating = 1000;
  static const _minFactor = 0.6;
  static const _maxFactor = 1.5;

  final Map<int, FplTeam> _teams;
  final double _averageAttack;
  final double _averageDefence;

  static _TeamStrengths? from(Map<int, FplTeam> teams) {
    // Missing ratings parse as 1000 for all four fields.
    final rated = {
      for (final team in teams.values)
        if ({
          team.strengthAttackHome,
          team.strengthAttackAway,
          team.strengthDefenceHome,
          team.strengthDefenceAway,
        }.any((rating) => rating != _missingRating))
          team.id: team,
    };
    final attack = rated.values.expand(
      (team) => [team.strengthAttackHome, team.strengthAttackAway],
    );
    final defence = rated.values.expand(
      (team) => [team.strengthDefenceHome, team.strengthDefenceAway],
    );
    if (rated.length < 2 ||
        (attack.toSet().length < 2 && defence.toSet().length < 2)) {
      return null;
    }
    double average(Iterable<int> values) =>
        values.fold(0, (total, value) => total + value) / values.length;
    // Pooled over both venues so home advantage is kept in the factors.
    return _TeamStrengths(rated, average(attack), average(defence));
  }

  /// (attack, defence) multipliers for [teamId] in [fixture], or null when
  /// either side has no rating.
  (double, double)? factors(int teamId, FplFixture fixture) {
    final isHome = teamId == fixture.homeTeamId;
    if (!_teams.containsKey(teamId)) return null;
    final opponent = _teams[isHome ? fixture.awayTeamId : fixture.homeTeamId];
    if (opponent == null) return null;
    final opponentAttack = isHome
        ? opponent.strengthAttackAway
        : opponent.strengthAttackHome;
    final opponentDefence = isHome
        ? opponent.strengthDefenceAway
        : opponent.strengthDefenceHome;
    double scale(double ratio) =>
        math.pow(ratio, _sensitivity).toDouble().clamp(_minFactor, _maxFactor);
    return (
      scale(_averageDefence / opponentDefence),
      scale(_averageAttack / opponentAttack),
    );
  }
}
