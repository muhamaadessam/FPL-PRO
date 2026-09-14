import '../../../fixtures/data/models/fpl_models.dart';
import '../../../team/data/models/team_models.dart';

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
}

class RecommendationEngine {
  const RecommendationEngine();

  RecommendationResult build({
    required FplBootstrap bootstrap,
    required List<FplFixture> fixtures,
    required MyTeam team,
    required int gameweekId,
    Map<int, FplPlayerSummary> playerSummaries = const {},
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
    final squadAnalysis = _analyzeSquad(
      team: team,
      projections: projections,
      fixtures: fixtures,
      gameweekId: gameweekId,
      playerSummaries: playerSummaries,
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
      squadAnalysis: squadAnalysis,
    );
  }

  SquadAnalysis _analyzeSquad({
    required MyTeam team,
    required Map<int, PlayerProjection> projections,
    required List<FplFixture> fixtures,
    required int gameweekId,
    required Map<int, FplPlayerSummary> playerSummaries,
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
        ),
      );
    }
    players.sort((a, b) => a.pick.position.compareTo(b.pick.position));
    final starters = players.where((player) => player.isStarter).toList();
    final bench = players.where((player) => !player.isStarter).toList();
    final starterAverage = _averageRating(starters);
    final benchAverage = _averageRating(bench);
    final expectedStartingPoints = starters.fold(
      0.0,
      (total, player) =>
          total + player.expectedPoints * (player.pick.isCaptain ? 2 : 1),
    );
    final bestLegalLineupPoints = _bestLegalLineupPoints(players);
    final selectionEfficiency = bestLegalLineupPoints <= 0
        ? 0
        : (expectedStartingPoints / bestLegalLineupPoints * 100)
              .clamp(0, 100)
              .round();
    final squadQuality = starterAverage * 0.85 + benchAverage * 0.15;
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
      players: players,
      currentSeasonCoverage: players
          .where(
            (player) =>
                playerSummaries[player.projection.player.id]
                    ?.history
                    .isNotEmpty ??
                false,
          )
          .length,
      previousSeasonPlayers: players
          .where(
            (player) =>
                playerSummaries[player.projection.player.id]
                    ?.historyPast
                    .isNotEmpty ??
                false,
          )
          .length,
    );
  }

  PlayerAnalysis _analyzePlayer({
    required TeamPick pick,
    required PlayerProjection projection,
    required Iterable<PlayerProjection> allProjections,
    required FplPlayerSummary? summary,
    required List<FplFixture> fixtures,
    required int gameweekId,
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
  }) {
    if (projection.nextFixtureCount == 0) return 0;
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
    final underlyingPoints = _underlyingPoints(projection.player);
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

  double _underlyingPoints(FplPlayer player) {
    if (player.minutes <= 0) return 0;
    final matches = player.minutes / 90;
    final expectedInvolvementsPer90 = player.expectedGoalInvolvements / matches;
    final goalPoints = switch (player.positionId) {
      1 => 10,
      2 => 6,
      3 => 5,
      _ => 4,
    };
    final attacking = expectedInvolvementsPer90 * (goalPoints + 3) / 2;
    final cleanSheetPoints = switch (player.positionId) {
      1 || 2 => 4,
      3 => 1,
      _ => 0,
    };
    final cleanSheets = player.cleanSheets / matches * cleanSheetPoints;
    final saves = player.positionId == 1 ? player.saves / matches / 3 : 0;
    return 2 + attacking + cleanSheets + saves;
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

  double _bestLegalLineupPoints(List<PlayerAnalysis> players) {
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
      return total + captain;
    }
    var best = 0.0;
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
      if (selected != 11 ||
          positionCounts[1] != 1 ||
          (positionCounts[2] ?? 0) < 3 ||
          (positionCounts[2] ?? 0) > 5 ||
          (positionCounts[3] ?? 0) < 2 ||
          (positionCounts[3] ?? 0) > 5 ||
          (positionCounts[4] ?? 0) < 1 ||
          (positionCounts[4] ?? 0) > 3) {
        continue;
      }
      final total = points + captain;
      if (total > best) best = total;
    }
    return best;
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
          outProjection: outgoingProjection,
          inProjection: best,
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
