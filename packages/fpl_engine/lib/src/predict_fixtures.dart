import 'dart:math' as math;

import 'models/fpl_models.dart';
import 'team_ratings.dart';

class PlayerEventPrediction {
  const PlayerEventPrediction({required this.player, required this.chance});

  final FplPlayer player;
  final int chance;
}

class FixturePrediction {
  const FixturePrediction({
    required this.homeGoals,
    required this.awayGoals,
    required this.homeCleanSheetChance,
    required this.awayCleanSheetChance,
    required this.confidence,
    required this.scorers,
    required this.assists,
    this.homeExpectedGoals = 0,
    this.awayExpectedGoals = 0,
    this.homeWinChance = 0,
    this.drawChance = 0,
    this.awayWinChance = 0,
    this.homeScorers = const [],
    this.awayScorers = const [],
    this.homeAssists = const [],
    this.awayAssists = const [],
  });

  /// The likeliest scoreline within the likeliest result, so the score never
  /// contradicts the win/draw/loss split.
  final int homeGoals;
  final int awayGoals;
  final int homeCleanSheetChance;
  final int awayCleanSheetChance;

  /// Probability of the predicted result (home win, draw or away win).
  final int confidence;
  final List<PlayerEventPrediction> scorers;
  final List<PlayerEventPrediction> assists;
  final double homeExpectedGoals;
  final double awayExpectedGoals;
  final int homeWinChance;
  final int drawChance;
  final int awayWinChance;
  final List<PlayerEventPrediction> homeScorers;
  final List<PlayerEventPrediction> awayScorers;
  final List<PlayerEventPrediction> homeAssists;
  final List<PlayerEventPrediction> awayAssists;
}

/// Dixon-Coles match model: each side's goals are Poisson with a rate from
/// [TeamRatings], corrected for the extra draws seen in low-scoring games.
/// Player events split the team's expected goals by each player's
/// shrunk xG (or xA) rate and expected share of the minutes.
class FixturePredictionEngine {
  /// The defaults are the tuned values; overrides exist for the backtest in
  /// test/backtest/.
  const FixturePredictionEngine({
    this.rho = defaultRho,
    this.priorMinutes = defaultPriorMinutes,
    this.absenceImpact = defaultAbsenceImpact,
    this.ratedTeamPriorMatches = TeamRatings.defaultRatedTeamPriorMatches,
    this.teamPriorMatches = TeamRatings.defaultTeamPriorMatches,
    this.expectedGoalsWeight = TeamRatings.defaultExpectedGoalsWeight,
  });

  /// Dixon-Coles low-score dependence; negative raises 0-0 and 1-1.
  static const defaultRho = -0.08;
  static const _maxGoals = 10;

  /// Share of goals that are own goals, and that earn an FPL assist.
  static const _ownGoalShare = 0.03;
  static const _assistedShare = 0.8;

  /// Minutes of position-average output added to each player's record, so a
  /// lucky 90 minutes does not outrank a season of evidence.
  static const defaultPriorMinutes = 450.0;

  /// Position-average xG and xA per 90, by position id.
  static const _goalPrior = {1: 0.005, 2: 0.05, 3: 0.13, 4: 0.33};
  static const _assistPrior = {1: 0.01, 2: 0.07, 3: 0.15, 4: 0.12};

  /// Actual goals carry some finishing skill that xG misses.
  static const _goalsWeight = 0.2;

  /// Part of a missing player's threat the rest of the side cannot replace.
  static const defaultAbsenceImpact = 0.6;

  final double rho;
  final double priorMinutes;
  final double absenceImpact;

  /// See [TeamRatings.from].
  final double ratedTeamPriorMatches;
  final double teamPriorMatches;
  final double expectedGoalsWeight;

  Map<int, FixturePrediction> predictNextGameweeks({
    required List<FplFixture> fixtures,
    required Map<int, FplTeam> teams,
    required Map<int, FplPlayer> players,
    required int fromGameweekId,
    int gameweekCount = 3,
  }) {
    final upcoming = fixtures
        .where(
          (fixture) =>
              !fixture.started &&
              !fixture.isFinished &&
              fixture.gameweekId != null &&
              fixture.gameweekId! >= fromGameweekId,
        )
        .toList(growable: false);
    final gameweeks = upcoming.map((fixture) => fixture.gameweekId!).toSet()
      ..removeWhere((gameweek) => gameweek <= 0);
    final selectedGameweeks = gameweeks.toList()..sort();
    final horizon = selectedGameweeks.take(gameweekCount).toSet();
    final ratings = TeamRatings.from(
      teams: teams,
      fixtures: fixtures,
      players: players,
      ratedTeamPriorMatches: ratedTeamPriorMatches,
      teamPriorMatches: teamPriorMatches,
      expectedGoalsWeight: expectedGoalsWeight,
    );

    return Map.unmodifiable({
      for (final fixture in upcoming)
        if (horizon.contains(fixture.gameweekId))
          fixture.id: predict(
            fixture: fixture,
            teams: teams,
            players: players,
            ratings: ratings,
          ),
    });
  }

  FixturePrediction predict({
    required FplFixture fixture,
    required Map<int, FplTeam> teams,
    required Map<int, FplPlayer> players,
    TeamRatings? ratings,
  }) {
    final teamRatings =
        ratings ??
        TeamRatings.from(
          teams: teams,
          fixtures: const [],
          ratedTeamPriorMatches: ratedTeamPriorMatches,
          teamPriorMatches: teamPriorMatches,
          expectedGoalsWeight: expectedGoalsWeight,
        );
    final (homeRate, awayRate) = _teamRates(fixture, teamRatings);
    final priceAverages = _averagePriceByPosition(players);
    final home = _squad(
      teamId: fixture.homeTeamId,
      players: players,
      matchesPlayed: teamRatings.matchesPlayed(fixture.homeTeamId),
      priceAverages: priceAverages,
    );
    final away = _squad(
      teamId: fixture.awayTeamId,
      players: players,
      matchesPlayed: teamRatings.matchesPlayed(fixture.awayTeamId),
      priceAverages: priceAverages,
    );
    final homeLambda = (homeRate * home.absenceFactor).clamp(0.2, 4.5);
    final awayLambda = (awayRate * away.absenceFactor).clamp(0.2, 4.5);

    final matrix = _scoreMatrix(homeLambda, awayLambda);
    var homeWin = 0.0;
    var draw = 0.0;
    var awayWin = 0.0;
    var homeCleanSheet = 0.0;
    var awayCleanSheet = 0.0;
    for (var h = 0; h <= _maxGoals; h++) {
      for (var a = 0; a <= _maxGoals; a++) {
        final p = matrix[h][a];
        if (h > a) {
          homeWin += p;
        } else if (h == a) {
          draw += p;
        } else {
          awayWin += p;
        }
        if (a == 0) homeCleanSheet += p;
        if (h == 0) awayCleanSheet += p;
      }
    }
    final outcome = homeWin >= draw && homeWin >= awayWin
        ? 1
        : (awayWin > draw ? -1 : 0);
    var bestScore = (0, 0);
    var bestProbability = -1.0;
    for (var h = 0; h <= _maxGoals; h++) {
      for (var a = 0; a <= _maxGoals; a++) {
        if ((h - a).sign != outcome) continue;
        if (matrix[h][a] > bestProbability) {
          bestProbability = matrix[h][a];
          bestScore = (h, a);
        }
      }
    }

    final homeScorers = home.events(homeLambda * (1 - _ownGoalShare), true);
    final awayScorers = away.events(awayLambda * (1 - _ownGoalShare), true);
    final homeAssists = home.events(homeLambda * _assistedShare, false);
    final awayAssists = away.events(awayLambda * _assistedShare, false);
    final scorers = [...homeScorers, ...awayScorers]
      ..sort((a, b) => b.chance.compareTo(a.chance));
    final assists = [...homeAssists, ...awayAssists]
      ..sort((a, b) => b.chance.compareTo(a.chance));

    return FixturePrediction(
      homeGoals: bestScore.$1,
      awayGoals: bestScore.$2,
      homeExpectedGoals: homeLambda,
      awayExpectedGoals: awayLambda,
      homeWinChance: _percent(homeWin),
      drawChance: _percent(draw),
      awayWinChance: _percent(awayWin),
      homeCleanSheetChance: _percent(homeCleanSheet),
      awayCleanSheetChance: _percent(awayCleanSheet),
      confidence: _percent(math.max(homeWin, math.max(draw, awayWin))),
      scorers: List.unmodifiable(scorers.take(3)),
      assists: List.unmodifiable(assists.take(3)),
      homeScorers: List.unmodifiable(homeScorers),
      awayScorers: List.unmodifiable(awayScorers),
      homeAssists: List.unmodifiable(homeAssists),
      awayAssists: List.unmodifiable(awayAssists),
    );
  }

  /// Expected goals per side; without ratings the official FDR is used.
  (double, double) _teamRates(FplFixture fixture, TeamRatings ratings) {
    if (ratings.isRated(fixture.homeTeamId) &&
        ratings.isRated(fixture.awayTeamId)) {
      return ratings.expectedGoals(fixture);
    }
    double fdr(int? difficulty) => 1.24 - (difficulty ?? 3).clamp(1, 5) * 0.08;
    return (
      ratings.homeGoals * fdr(fixture.homeDifficulty),
      ratings.awayGoals * fdr(fixture.awayDifficulty),
    );
  }

  List<List<double>> _scoreMatrix(double homeLambda, double awayLambda) {
    final home = _poisson(homeLambda);
    final away = _poisson(awayLambda);
    double tau(int h, int a) => switch ((h, a)) {
      (0, 0) => 1 - homeLambda * awayLambda * rho,
      (0, 1) => 1 + homeLambda * rho,
      (1, 0) => 1 + awayLambda * rho,
      (1, 1) => 1 - rho,
      _ => 1.0,
    };
    final matrix = [
      for (var h = 0; h <= _maxGoals; h++)
        [
          for (var a = 0; a <= _maxGoals; a++)
            math.max(0.0, home[h] * away[a] * tau(h, a)),
        ],
    ];
    final total = matrix.fold(
      0.0,
      (sum, row) => sum + row.fold(0.0, (rowSum, p) => rowSum + p),
    );
    return [
      for (final row in matrix) [for (final p in row) p / total],
    ];
  }

  List<double> _poisson(double lambda) {
    final probabilities = <double>[];
    var p = math.exp(-lambda);
    for (var k = 0; k <= _maxGoals; k++) {
      probabilities.add(p);
      p *= lambda / (k + 1);
    }
    return probabilities;
  }

  _Squad _squad({
    required int teamId,
    required Map<int, FplPlayer> players,
    required int matchesPlayed,
    required Map<int, double> priceAverages,
  }) {
    final members = <_Member>[];
    for (final player in players.values) {
      if (player.teamId != teamId || !player.canSelect) continue;
      final availability = player.isUnavailable
          ? 0.0
          : ((player.effectiveChanceOfPlaying ?? 100) / 100).clamp(0.0, 1.0);
      // Expected share of the team's minutes; with no matches yet, price is
      // the best guess at who plays.
      final minutesShare = matchesPlayed > 0
          ? (player.minutes / (90 * matchesPlayed)).clamp(0.0, 1.0)
          : (player.minutes > 0 ? 1.0 : 0.5);
      final priceFactor = _priceFactor(player, priceAverages);
      members.add(
        _Member(
          player: player,
          minutesShare: minutesShare.toDouble(),
          availability: availability.toDouble(),
          goalRate: _rate(
            player,
            player.expectedGoals,
            player.goalsScored,
            (_goalPrior[player.positionId] ?? 0) * priceFactor,
          ),
          assistRate: _rate(
            player,
            player.expectedAssists,
            player.assists,
            (_assistPrior[player.positionId] ?? 0) * priceFactor,
          ),
        ),
      );
    }
    return _Squad(members, absenceImpact);
  }

  /// Per-90 rate shrunk towards [prior] by [priorMinutes] of average output.
  double _rate(FplPlayer player, double expected, int actual, double prior) {
    final evidence = expected > 0 || actual > 0
        ? expected * (1 - _goalsWeight) + actual * _goalsWeight
        : 0.0;
    return (evidence + prior * priorMinutes / 90) /
        ((player.minutes + priorMinutes) / 90);
  }

  /// Pricier players carry more attacking threat than their position average.
  double _priceFactor(FplPlayer player, Map<int, double> averages) {
    final cost = player.nowCost;
    final average = averages[player.positionId];
    if (cost == null || average == null || average <= 0) return 1;
    return math.pow(cost / average, 1.5).toDouble().clamp(0.5, 2.5);
  }

  Map<int, double> _averagePriceByPosition(Map<int, FplPlayer> players) {
    final totals = <int, (double, int)>{};
    for (final player in players.values) {
      final cost = player.nowCost;
      if (cost == null) continue;
      final (sum, count) = totals[player.positionId] ?? (0.0, 0);
      totals[player.positionId] = (sum + cost, count + 1);
    }
    return {
      for (final entry in totals.entries)
        entry.key: entry.value.$1 / entry.value.$2,
    };
  }

  static int _percent(double probability) =>
      (probability * 100).round().clamp(0, 100).toInt();
}

class _Member {
  const _Member({
    required this.player,
    required this.minutesShare,
    required this.availability,
    required this.goalRate,
    required this.assistRate,
  });

  final FplPlayer player;
  final double minutesShare;
  final double availability;
  final double goalRate;
  final double assistRate;

  double weight(bool goals) => (goals ? goalRate : assistRate) * minutesShare;
}

class _Squad {
  const _Squad(this.members, this.absenceImpact);

  final List<_Member> members;
  final double absenceImpact;

  /// Share of the side's usual threat still available, softened because
  /// replacements cover part of an absence.
  double get absenceFactor {
    final full = members.fold(0.0, (sum, m) => sum + m.weight(true));
    if (full <= 0) return 1;
    final available = members.fold(
      0.0,
      (sum, m) => sum + m.weight(true) * m.availability,
    );
    return 1 - absenceImpact * (1 - (available / full).clamp(0.0, 1.0));
  }

  /// Top three outfield candidates to score ([goals]) or assist, splitting
  /// [teamLambda] by each player's expected contribution.
  List<PlayerEventPrediction> events(double teamLambda, bool goals) {
    final total = members.fold(
      0.0,
      (sum, m) => sum + m.weight(goals) * m.availability,
    );
    if (total <= 0) return const [];
    final candidates =
        members
            .where((m) => m.player.positionId != 1 && m.availability > 0)
            .map(
              (m) => PlayerEventPrediction(
                player: m.player,
                chance:
                    ((1 -
                                math.exp(
                                  -teamLambda *
                                      m.weight(goals) *
                                      m.availability /
                                      total,
                                )) *
                            100)
                        .round()
                        .clamp(0, 95)
                        .toInt(),
              ),
            )
            .where((candidate) => candidate.chance >= 4)
            .toList()
          ..sort((a, b) => b.chance.compareTo(a.chance));
    return candidates.take(3).toList(growable: false);
  }
}
