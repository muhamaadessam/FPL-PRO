import 'dart:math' as math;

import '../../data/models/fpl_models.dart';

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
    this.homeScorers = const [],
    this.awayScorers = const [],
    this.homeAssists = const [],
    this.awayAssists = const [],
  });

  final int homeGoals;
  final int awayGoals;
  final int homeCleanSheetChance;
  final int awayCleanSheetChance;
  final int confidence;
  final List<PlayerEventPrediction> scorers;
  final List<PlayerEventPrediction> assists;
  final List<PlayerEventPrediction> homeScorers;
  final List<PlayerEventPrediction> awayScorers;
  final List<PlayerEventPrediction> homeAssists;
  final List<PlayerEventPrediction> awayAssists;
}

class FixturePredictionEngine {
  const FixturePredictionEngine();

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

    return Map.unmodifiable({
      for (final fixture in upcoming)
        if (horizon.contains(fixture.gameweekId))
          fixture.id: predict(fixture: fixture, teams: teams, players: players),
    });
  }

  FixturePrediction predict({
    required FplFixture fixture,
    required Map<int, FplTeam> teams,
    required Map<int, FplPlayer> players,
  }) {
    final home = _teamProjection(
      teamId: fixture.homeTeamId,
      opponentId: fixture.awayTeamId,
      isHome: true,
      difficulty: fixture.homeDifficulty ?? 3,
      teams: teams,
      players: players,
    );
    final away = _teamProjection(
      teamId: fixture.awayTeamId,
      opponentId: fixture.homeTeamId,
      isHome: false,
      difficulty: fixture.awayDifficulty ?? 3,
      teams: teams,
      players: players,
    );
    final scorers = [...home.scorers, ...away.scorers]
      ..sort((a, b) => b.chance.compareTo(a.chance));
    final assists = [...home.assists, ...away.assists]
      ..sort((a, b) => b.chance.compareTo(a.chance));
    final coverage = (home.dataCoverage + away.dataCoverage) / 2;
    final separation = (home.expectedGoals - away.expectedGoals).abs();

    return FixturePrediction(
      homeGoals: home.expectedGoals.round().clamp(0, 4).toInt(),
      awayGoals: away.expectedGoals.round().clamp(0, 4).toInt(),
      homeCleanSheetChance: _cleanSheetChance(away.expectedGoals),
      awayCleanSheetChance: _cleanSheetChance(home.expectedGoals),
      confidence: (45 + coverage * 32 + separation.clamp(0, 1) * 8)
          .round()
          .clamp(40, 85)
          .toInt(),
      scorers: List.unmodifiable(scorers.take(3)),
      assists: List.unmodifiable(assists.take(3)),
      homeScorers: List.unmodifiable(home.scorers),
      awayScorers: List.unmodifiable(away.scorers),
      homeAssists: List.unmodifiable(home.assists),
      awayAssists: List.unmodifiable(away.assists),
    );
  }

  _TeamProjection _teamProjection({
    required int teamId,
    required int opponentId,
    required bool isHome,
    required int difficulty,
    required Map<int, FplTeam> teams,
    required Map<int, FplPlayer> players,
  }) {
    final team = teams[teamId];
    final opponent = teams[opponentId];
    final teamPlayers = players.values
        .where(
          (player) =>
              player.teamId == teamId &&
              player.canSelect &&
              !player.isUnavailable,
        )
        .toList(growable: false);
    final maxStarts = teamPlayers.fold<int>(
      1,
      (maximum, player) => math.max(maximum, player.starts),
    );
    final attackStrength = _strength(
      isHome ? team?.strengthAttackHome : team?.strengthAttackAway,
    );
    final opponentDefence = _strength(
      isHome ? opponent?.strengthDefenceAway : opponent?.strengthDefenceHome,
    );
    final contextFactor =
        ((attackStrength / 1000).clamp(0.75, 1.35) *
                (1000 / opponentDefence).clamp(0.75, 1.35) *
                (1.28 - difficulty.clamp(1, 5) * 0.09) *
                (isHome ? 1.06 : 0.96))
            .toDouble();
    final metrics = teamPlayers
        .map(
          (player) => _playerMetrics(
            player,
            maxStarts: maxStarts,
            contextFactor: contextFactor,
          ),
        )
        .toList(growable: false);
    final likelyOutfield =
        metrics.where((metric) => metric.player.positionId != 1).toList()
          ..sort((a, b) => b.participation.compareTo(a.participation));
    final likelyTen = likelyOutfield.take(10).toList(growable: false);
    final measuredPlayers = likelyTen
        .where(
          (metric) =>
              metric.player.minutes > 0 &&
              (metric.player.expectedGoals > 0 ||
                  metric.player.goalsScored > 0),
        )
        .length;
    final dataCoverage = (measuredPlayers / 10).clamp(0.0, 1.0).toDouble();
    final measuredGoals = likelyTen.fold<double>(
      0,
      (total, metric) => total + metric.goalLambda,
    );
    final baselineGoals = 1.25 * contextFactor;
    final expectedGoals = (measuredGoals + baselineGoals * (1 - dataCoverage))
        .clamp(0.35, 3.4)
        .toDouble();
    final scorers =
        metrics
            .where((metric) => metric.player.positionId != 1)
            .map(
              (metric) => PlayerEventPrediction(
                player: metric.player,
                chance: _eventChance(metric.goalLambda),
              ),
            )
            .where((candidate) => candidate.chance >= 4)
            .toList()
          ..sort((a, b) => b.chance.compareTo(a.chance));
    final assists =
        metrics
            .where((metric) => metric.player.positionId != 1)
            .map(
              (metric) => PlayerEventPrediction(
                player: metric.player,
                chance: _eventChance(metric.assistLambda),
              ),
            )
            .where((candidate) => candidate.chance >= 4)
            .toList()
          ..sort((a, b) => b.chance.compareTo(a.chance));

    return _TeamProjection(
      expectedGoals: expectedGoals,
      dataCoverage: dataCoverage,
      scorers: scorers.take(3).toList(growable: false),
      assists: assists.take(3).toList(growable: false),
    );
  }

  _PlayerMetrics _playerMetrics(
    FplPlayer player, {
    required int maxStarts,
    required double contextFactor,
  }) {
    final matches = math.max(player.minutes / 90, 1.0);
    final startShare = (player.starts / maxStarts).clamp(0.0, 1.0);
    final minutesPerStart = player.starts == 0
        ? (player.minutes > 0 ? 0.45 : 0.35)
        : (player.minutes / player.starts / 90).clamp(0.35, 1.0);
    final participation = (0.45 + startShare * 0.35 + minutesPerStart * 0.2)
        .clamp(0.45, 1.0)
        .toDouble();
    final availability = ((player.effectiveChanceOfPlaying ?? 100) / 100)
        .clamp(0.0, 1.0)
        .toDouble();
    final goalBaseline = switch (player.positionId) {
      1 => 0.005,
      2 => 0.045,
      3 => 0.14,
      _ => 0.22,
    };
    final assistBaseline = switch (player.positionId) {
      1 => 0.005,
      2 => 0.06,
      3 => 0.16,
      _ => 0.11,
    };
    final formFactor = (0.75 + (player.form + player.pointsPerGame) / 24)
        .clamp(0.75, 1.35)
        .toDouble();
    final expectedGoalsPer90 = player.expectedGoals / matches;
    final goalsPer90 = player.goalsScored / matches;
    final expectedAssistsPer90 = player.expectedAssists / matches;
    final assistsPer90 = player.assists / matches;
    final goalRate = expectedGoalsPer90 > 0 || goalsPer90 > 0
        ? expectedGoalsPer90 * 0.72 + goalsPer90 * 0.2 + goalBaseline * 0.08
        : goalBaseline * formFactor;
    final assistRate = expectedAssistsPer90 > 0 || assistsPer90 > 0
        ? expectedAssistsPer90 * 0.72 +
              assistsPer90 * 0.2 +
              assistBaseline * 0.08
        : assistBaseline * formFactor;
    final playerFactor = participation * availability * contextFactor;

    return _PlayerMetrics(
      player: player,
      participation: participation,
      goalLambda: (goalRate * playerFactor).clamp(0.0, 1.4).toDouble(),
      assistLambda: (assistRate * playerFactor).clamp(0.0, 1.2).toDouble(),
    );
  }

  int _cleanSheetChance(double opponentExpectedGoals) =>
      (math.exp(-opponentExpectedGoals) * 100).round().clamp(5, 75).toInt();

  int _eventChance(double lambda) =>
      ((1 - math.exp(-lambda)) * 100).round().clamp(0, 85).toInt();

  double _strength(int? value) =>
      value == null || value <= 0 ? 1000 : value.toDouble();
}

class _TeamProjection {
  const _TeamProjection({
    required this.expectedGoals,
    required this.dataCoverage,
    required this.scorers,
    required this.assists,
  });

  final double expectedGoals;
  final double dataCoverage;
  final List<PlayerEventPrediction> scorers;
  final List<PlayerEventPrediction> assists;
}

class _PlayerMetrics {
  const _PlayerMetrics({
    required this.player,
    required this.participation,
    required this.goalLambda,
    required this.assistLambda,
  });

  final FplPlayer player;
  final double participation;
  final double goalLambda;
  final double assistLambda;
}
