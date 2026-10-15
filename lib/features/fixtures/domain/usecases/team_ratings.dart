import 'dart:math' as math;

import '../../data/models/fpl_models.dart';

/// Venue-neutral attack and defence ratings per team, as multipliers of the
/// league scoring rate: 1.0 is average, attack above 1 scores more and
/// defence above 1 concedes more.
///
/// The prior comes from the official `strength_*` ratings. This season's
/// finished fixtures (goals, plus team xG and xGC summed from players) are
/// opponent-adjusted and blended in with a Gamma-Poisson update, so the data
/// takes over as matches are played.
class TeamRatings {
  const TeamRatings._({
    required this.homeGoals,
    required this.awayGoals,
    required this._attack,
    required this._defence,
    required this._matchesPlayed,
  });

  /// Long-run Premier League goals per match by venue.
  static const _priorHomeGoals = 1.55;
  static const _priorAwayGoals = 1.25;

  /// Matches the league scoring prior is worth against this season's data.
  static const _leaguePriorMatches = 60.0;

  /// Matches a team's prior rating is worth against its own results.
  static const _teamPriorMatches = 6.0;

  /// Exponent that widens the official ratings' narrow spread.
  static const _strengthSensitivity = 2.0;
  static const _missingRating = 1000;

  /// xG is a steadier signal of quality than goals over a few matches.
  static const _expectedGoalsWeight = 0.65;
  static const _iterations = 5;
  static const _minRating = 0.4;
  static const _maxRating = 2.5;

  /// Goals per match scored by home and away sides.
  final double homeGoals;
  final double awayGoals;
  final Map<int, double> _attack;
  final Map<int, double> _defence;
  final Map<int, int> _matchesPlayed;

  static const empty = TeamRatings._(
    homeGoals: _priorHomeGoals,
    awayGoals: _priorAwayGoals,
    attack: {},
    defence: {},
    matchesPlayed: {},
  );

  double get averageGoals => (homeGoals + awayGoals) / 2;

  double attack(int teamId) => _attack[teamId] ?? 1.0;
  double defence(int teamId) => _defence[teamId] ?? 1.0;

  /// Finished league matches this season.
  int matchesPlayed(int teamId) => _matchesPlayed[teamId] ?? 0;

  /// Whether the team has an official rating or results to judge it by.
  bool isRated(int teamId) => _attack.containsKey(teamId);

  /// Expected goals for (home, away) in [fixture].
  (double, double) expectedGoals(FplFixture fixture) => (
    homeGoals * attack(fixture.homeTeamId) * defence(fixture.awayTeamId),
    awayGoals * attack(fixture.awayTeamId) * defence(fixture.homeTeamId),
  );

  factory TeamRatings.from({
    required Map<int, FplTeam> teams,
    required List<FplFixture> fixtures,
    Map<int, FplPlayer> players = const {},
  }) {
    final results = fixtures
        .where(
          (fixture) =>
              fixture.isFinished &&
              fixture.homeScore != null &&
              fixture.awayScore != null,
        )
        .toList(growable: false);
    final priors = _priors(teams);
    if (priors.isEmpty && results.isEmpty) return empty;

    var homeTotal = 0;
    var awayTotal = 0;
    final matches = <int, List<(int opponent, bool home)>>{};
    final goalsFor = <int, double>{};
    final goalsAgainst = <int, double>{};
    for (final fixture in results) {
      homeTotal += fixture.homeScore!;
      awayTotal += fixture.awayScore!;
      void add(int team, int opponent, bool home, int scored, int conceded) {
        matches.putIfAbsent(team, () => []).add((opponent, home));
        goalsFor[team] = (goalsFor[team] ?? 0) + scored;
        goalsAgainst[team] = (goalsAgainst[team] ?? 0) + conceded;
      }

      add(
        fixture.homeTeamId,
        fixture.awayTeamId,
        true,
        fixture.homeScore!,
        fixture.awayScore!,
      );
      add(
        fixture.awayTeamId,
        fixture.homeTeamId,
        false,
        fixture.awayScore!,
        fixture.homeScore!,
      );
    }
    final homeGoals =
        (homeTotal + _priorHomeGoals * _leaguePriorMatches) /
        (results.length + _leaguePriorMatches);
    final awayGoals =
        (awayTotal + _priorAwayGoals * _leaguePriorMatches) /
        (results.length + _leaguePriorMatches);
    final averageGoals = (homeGoals + awayGoals) / 2;

    // Team xG is the sum of its players' xG; every conceded chance is
    // shared by the eleven players on the pitch.
    final expectedFor = <int, double>{};
    final expectedAgainst = <int, double>{};
    for (final player in players.values) {
      expectedFor[player.teamId] =
          (expectedFor[player.teamId] ?? 0) + player.expectedGoals;
      expectedAgainst[player.teamId] =
          (expectedAgainst[player.teamId] ?? 0) +
          player.expectedGoalsConceded / 11;
    }
    // Season xG only describes a team whose matches are in [results].
    double observed(int teamId, double goals, double? expected) =>
        !matches.containsKey(teamId)
        ? 0
        : expected == null || expected <= 0
        ? goals
        : expected * _expectedGoalsWeight + goals * (1 - _expectedGoalsWeight);

    final ids = {...priors.keys, ...matches.keys};
    var attack = {for (final id in ids) id: priors[id]?.$1 ?? 1.0};
    var defence = {for (final id in ids) id: priors[id]?.$2 ?? 1.0};
    for (var iteration = 0; iteration < _iterations; iteration++) {
      final nextAttack = <int, double>{};
      final nextDefence = <int, double>{};
      for (final id in ids) {
        final played = matches[id] ?? const [];
        // Goals an average side would score and concede in these matches.
        var baselineFor = 0.0;
        var baselineAgainst = 0.0;
        for (final (opponent, home) in played) {
          baselineFor +=
              (home ? homeGoals : awayGoals) * (defence[opponent] ?? 1.0);
          baselineAgainst +=
              (home ? awayGoals : homeGoals) * (attack[opponent] ?? 1.0);
        }
        final prior = priors[id] ?? (1.0, 1.0);
        final weight = _teamPriorMatches * averageGoals;
        nextAttack[id] =
            ((observed(id, goalsFor[id] ?? 0, expectedFor[id]) +
                        prior.$1 * weight) /
                    (baselineFor + weight))
                .clamp(_minRating, _maxRating);
        nextDefence[id] =
            ((observed(id, goalsAgainst[id] ?? 0, expectedAgainst[id]) +
                        prior.$2 * weight) /
                    (baselineAgainst + weight))
                .clamp(_minRating, _maxRating);
      }
      attack = _normalized(nextAttack);
      defence = _normalized(nextDefence);
    }

    return TeamRatings._(
      homeGoals: homeGoals,
      awayGoals: awayGoals,
      attack: Map.unmodifiable(attack),
      defence: Map.unmodifiable(defence),
      matchesPlayed: Map.unmodifiable({
        for (final entry in matches.entries) entry.key: entry.value.length,
      }),
    );
  }

  /// (attack, defence) priors from the official ratings, averaged over both
  /// venues because home advantage is carried by [homeGoals].
  static Map<int, (double, double)> _priors(Map<int, FplTeam> teams) {
    final rated = teams.values
        .where((team) {
          final ratings = {
            team.strengthAttackHome,
            team.strengthAttackAway,
            team.strengthDefenceHome,
            team.strengthDefenceAway,
          };
          // The API can publish zeros before ratings are set.
          return ratings.every((rating) => rating > 0) &&
              ratings.any((rating) => rating != _missingRating);
        })
        .toList(growable: false);
    if (rated.length < 2) return const {};
    double attackOf(FplTeam team) =>
        (team.strengthAttackHome + team.strengthAttackAway) / 2;
    double defenceOf(FplTeam team) =>
        (team.strengthDefenceHome + team.strengthDefenceAway) / 2;
    final averageAttack =
        rated.fold(0.0, (total, team) => total + attackOf(team)) / rated.length;
    final averageDefence =
        rated.fold(0.0, (total, team) => total + defenceOf(team)) /
        rated.length;
    double scale(double ratio) =>
        math.pow(ratio, _strengthSensitivity).toDouble();
    return {
      for (final team in rated)
        team.id: (
          scale(attackOf(team) / averageAttack),
          // A stronger defence concedes less.
          scale(averageDefence / defenceOf(team)),
        ),
    };
  }

  /// Keeps the league average at 1.0 so ratings stay relative.
  static Map<int, double> _normalized(Map<int, double> ratings) {
    if (ratings.length < 2) return ratings;
    final mean =
        ratings.values.fold(0.0, (total, value) => total + value) /
        ratings.length;
    return {for (final entry in ratings.entries) entry.key: entry.value / mean};
  }
}
