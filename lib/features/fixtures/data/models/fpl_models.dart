class Gameweek {
  const Gameweek({
    required this.id,
    required this.name,
    required this.deadlineTime,
    required this.finished,
    required this.isCurrent,
    required this.isNext,
    this.averageEntryScore,
    this.highestScore,
    this.highestScoringEntry,
  });

  final int id;
  final String name;
  final DateTime? deadlineTime;
  final bool finished;
  final bool isCurrent;
  final bool isNext;
  final int? averageEntryScore;
  final int? highestScore;
  final int? highestScoringEntry;

  factory Gameweek.fromJson(Map<String, dynamic> json) {
    return Gameweek(
      id: _int(json['id']),
      name: json['name'] as String? ?? 'Gameweek ${json['id']}',
      deadlineTime: _date(json['deadline_time']),
      finished: json['finished'] as bool? ?? false,
      isCurrent: json['is_current'] as bool? ?? false,
      isNext: json['is_next'] as bool? ?? false,
      averageEntryScore: _nullableInt(json['average_entry_score']),
      highestScore: _nullableInt(json['highest_score']),
      highestScoringEntry: _nullableInt(json['highest_scoring_entry']),
    );
  }
}

class FplTeam {
  const FplTeam({
    required this.id,
    required this.name,
    required this.shortName,
    this.code,
    this.strengthAttackHome = 1000,
    this.strengthAttackAway = 1000,
    this.strengthDefenceHome = 1000,
    this.strengthDefenceAway = 1000,
  });

  final int id;
  final String name;
  final String shortName;
  final int? code;
  final int strengthAttackHome;
  final int strengthAttackAway;
  final int strengthDefenceHome;
  final int strengthDefenceAway;

  factory FplTeam.fromJson(Map<String, dynamic> json) {
    return FplTeam(
      id: _int(json['id']),
      name: json['name'] as String? ?? 'Team ${json['id']}',
      shortName: json['short_name'] as String? ?? '',
      code: _nullableInt(json['code']),
      strengthAttackHome: _int(json['strength_attack_home'], fallback: 1000),
      strengthAttackAway: _int(json['strength_attack_away'], fallback: 1000),
      strengthDefenceHome: _int(json['strength_defence_home'], fallback: 1000),
      strengthDefenceAway: _int(json['strength_defence_away'], fallback: 1000),
    );
  }
}

class FplPlayer {
  const FplPlayer({
    required this.id,
    required this.webName,
    required this.teamId,
    required this.positionId,
    this.firstName,
    this.secondName,
    this.totalPoints = 0,
    this.nowCost,
    this.status = 'a',
    this.news = '',
    this.chanceOfPlayingThisRound,
    this.chanceOfPlayingNextRound,
    this.canSelect = true,
    this.form = 0,
    this.pointsPerGame = 0,
    this.expectedPointsNext = 0,
    this.selectedByPercent = 0,
    this.minutes = 0,
    this.starts = 0,
    this.goalsScored = 0,
    this.assists = 0,
    this.expectedGoals = 0,
    this.expectedAssists = 0,
    this.expectedGoalInvolvements = 0,
    this.expectedGoalsConceded = 0,
    this.defensiveContribution = 0,
    this.cleanSheets = 0,
    this.saves = 0,
  });

  final int id;
  final String webName;
  final int teamId;
  final int positionId;
  final String? firstName;
  final String? secondName;
  final int totalPoints;
  final int? nowCost;
  final String status;
  final String news;
  final int? chanceOfPlayingThisRound;
  final int? chanceOfPlayingNextRound;
  final bool canSelect;
  final double form;
  final double pointsPerGame;
  final double expectedPointsNext;
  final double selectedByPercent;
  final int minutes;
  final int starts;
  final int goalsScored;
  final int assists;
  final double expectedGoals;
  final double expectedAssists;
  final double expectedGoalInvolvements;
  final double expectedGoalsConceded;
  final int defensiveContribution;
  final int cleanSheets;
  final int saves;

  int? get effectiveChanceOfPlaying {
    final thisRound = chanceOfPlayingThisRound;
    final nextRound = chanceOfPlayingNextRound;
    if (thisRound != null && thisRound < 100) return thisRound;
    if (nextRound != null && nextRound < 100) return nextRound;
    return thisRound ?? nextRound;
  }

  int? get nextRoundChanceOfPlaying => chanceOfPlayingNextRound;

  bool get isUnavailableNextRound {
    final s = status.toLowerCase();
    return s == 'i' ||
        s == 's' ||
        s == 'u' ||
        s == 'n' ||
        nextRoundChanceOfPlaying == 0;
  }

  bool get isDoubtfulNextRound {
    if (isUnavailableNextRound) return false;
    final s = status.toLowerCase();
    final c = nextRoundChanceOfPlaying;
    return s == 'd' || (c != null && c > 0 && c < 100);
  }

  bool get isUnavailable {
    final s = status.toLowerCase();
    final c = effectiveChanceOfPlaying;
    return s == 'i' ||
        s == 's' ||
        s == 'u' ||
        s == 'n' ||
        (c != null && c == 0);
  }

  bool get isDoubtful {
    if (isUnavailable) return false;
    final s = status.toLowerCase();
    final c = effectiveChanceOfPlaying;
    return s == 'd' || (c != null && c > 0 && c < 100);
  }

  factory FplPlayer.fromJson(Map<String, dynamic> json) {
    return FplPlayer(
      id: _int(json['id']),
      webName: json['web_name'] as String? ?? 'Player ${json['id']}',
      teamId: _int(json['team']),
      positionId: _int(json['element_type']),
      firstName: json['first_name'] as String?,
      secondName: json['second_name'] as String?,
      totalPoints: _int(json['total_points']),
      nowCost: _nullableInt(json['now_cost']),
      status: json['status'] as String? ?? 'a',
      news: json['news'] as String? ?? '',
      chanceOfPlayingThisRound: _nullableInt(
        json['chance_of_playing_this_round'],
      ),
      chanceOfPlayingNextRound: _nullableInt(
        json['chance_of_playing_next_round'],
      ),
      canSelect: json['can_select'] as bool? ?? true,
      form: _double(json['form']),
      pointsPerGame: _double(json['points_per_game']),
      expectedPointsNext: _double(json['ep_next']),
      selectedByPercent: _double(json['selected_by_percent']),
      minutes: _int(json['minutes']),
      starts: _int(json['starts']),
      goalsScored: _int(json['goals_scored']),
      assists: _int(json['assists']),
      expectedGoals: _double(json['expected_goals']),
      expectedAssists: _double(json['expected_assists']),
      expectedGoalInvolvements: _double(json['expected_goal_involvements']),
      expectedGoalsConceded: _double(json['expected_goals_conceded']),
      defensiveContribution: _int(json['defensive_contribution']),
      cleanSheets: _int(json['clean_sheets']),
      saves: _int(json['saves']),
    );
  }
}

class FplBootstrap {
  const FplBootstrap({
    required this.gameweeks,
    required this.teams,
    required this.players,
  });

  final List<Gameweek> gameweeks;
  final Map<int, FplTeam> teams;
  final Map<int, FplPlayer> players;

  int get currentGameweekId {
    for (final gameweek in gameweeks) {
      if (gameweek.isCurrent) return gameweek.id;
    }
    for (final gameweek in gameweeks) {
      if (gameweek.isNext) return gameweek.id;
    }
    return gameweeks.isEmpty ? 1 : gameweeks.last.id;
  }

  factory FplBootstrap.fromJson(Map<String, dynamic> json) {
    final rawEvents = (json['events'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Gameweek.fromJson)
        .toList(growable: false);
    final rawTeams = (json['teams'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(FplTeam.fromJson);
    final rawPlayers = (json['elements'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(FplPlayer.fromJson);

    return FplBootstrap(
      gameweeks: rawEvents,
      teams: {for (final team in rawTeams) team.id: team},
      players: {for (final player in rawPlayers) player.id: player},
    );
  }
}

class FplFixtureStatEntry {
  const FplFixtureStatEntry({required this.elementId, required this.value});

  final int elementId;
  final int value;

  factory FplFixtureStatEntry.fromJson(Map<String, dynamic> json) {
    return FplFixtureStatEntry(
      elementId: _int(json['element']),
      value: _int(json['value']),
    );
  }
}

class FplFixtureStat {
  const FplFixtureStat({
    required this.identifier,
    required this.home,
    required this.away,
  });

  final String identifier;
  final List<FplFixtureStatEntry> home;
  final List<FplFixtureStatEntry> away;

  factory FplFixtureStat.fromJson(Map<String, dynamic> json) {
    return FplFixtureStat(
      identifier: json['identifier'] as String? ?? '',
      home: _fixtureStatEntries(json['h']),
      away: _fixtureStatEntries(json['a']),
    );
  }
}

List<FplFixtureStatEntry> _fixtureStatEntries(dynamic value) {
  return (value as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(FplFixtureStatEntry.fromJson)
      .toList(growable: false);
}

class FplFixture {
  const FplFixture({
    required this.id,
    required this.gameweekId,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.kickoffTime,
    required this.finished,
    required this.started,
    this.finishedProvisional = false,
    this.homeScore,
    this.awayScore,
    this.homeDifficulty,
    this.awayDifficulty,
    this.stats = const [],
  });

  final int id;
  final int? gameweekId;
  final int homeTeamId;
  final int awayTeamId;
  final DateTime? kickoffTime;
  final bool finished;
  final bool started;
  final bool finishedProvisional;
  final int? homeScore;
  final int? awayScore;
  final int? homeDifficulty;
  final int? awayDifficulty;
  final List<FplFixtureStat> stats;

  bool get isFinished => finished || finishedProvisional;
  bool get isLive => started && !isFinished;

  List<FplFixtureStatEntry> entriesFor(
    String identifier, {
    required bool home,
  }) {
    for (final stat in stats) {
      if (stat.identifier == identifier) {
        return home ? stat.home : stat.away;
      }
    }
    return const [];
  }

  factory FplFixture.fromJson(Map<String, dynamic> json) {
    return FplFixture(
      id: _int(json['id']),
      gameweekId: _nullableInt(json['event']),
      homeTeamId: _int(json['team_h']),
      awayTeamId: _int(json['team_a']),
      kickoffTime: _date(json['kickoff_time']),
      finished: json['finished'] as bool? ?? false,
      started: json['started'] as bool? ?? false,
      finishedProvisional: json['finished_provisional'] as bool? ?? false,
      homeScore: _nullableInt(json['team_h_score']),
      awayScore: _nullableInt(json['team_a_score']),
      homeDifficulty: _nullableInt(json['team_h_difficulty']),
      awayDifficulty: _nullableInt(json['team_a_difficulty']),
      stats: (json['stats'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(FplFixtureStat.fromJson)
          .toList(growable: false),
    );
  }
}

class FplPlayerHistory {
  const FplPlayerHistory({
    required this.round,
    required this.minutes,
    required this.starts,
    required this.totalPoints,
    required this.expectedGoalInvolvements,
  });

  final int round;
  final int minutes;
  final int starts;
  final int totalPoints;
  final double expectedGoalInvolvements;

  factory FplPlayerHistory.fromJson(Map<String, dynamic> json) {
    return FplPlayerHistory(
      round: _int(json['round']),
      minutes: _int(json['minutes']),
      starts: _int(json['starts']),
      totalPoints: _int(json['total_points']),
      expectedGoalInvolvements: _double(json['expected_goal_involvements']),
    );
  }
}

class FplPastSeason {
  const FplPastSeason({
    required this.seasonName,
    required this.totalPoints,
    required this.minutes,
    required this.starts,
    required this.expectedGoalInvolvements,
  });

  final String seasonName;
  final int totalPoints;
  final int minutes;
  final int starts;
  final double expectedGoalInvolvements;

  double get pointsPer90 {
    if (minutes <= 0) return 0;
    return totalPoints / minutes * 90;
  }

  factory FplPastSeason.fromJson(Map<String, dynamic> json) {
    return FplPastSeason(
      seasonName: json['season_name'] as String? ?? '',
      totalPoints: _int(json['total_points']),
      minutes: _int(json['minutes']),
      starts: _int(json['starts']),
      expectedGoalInvolvements: _double(json['expected_goal_involvements']),
    );
  }
}

class FplPlayerSummary {
  const FplPlayerSummary({
    this.history = const [],
    this.historyPast = const [],
  });

  final List<FplPlayerHistory> history;
  final List<FplPastSeason> historyPast;

  factory FplPlayerSummary.fromJson(Map<String, dynamic> json) {
    return FplPlayerSummary(
      history: (json['history'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(FplPlayerHistory.fromJson)
          .toList(growable: false),
      historyPast: (json['history_past'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(FplPastSeason.fromJson)
          .toList(growable: false),
    );
  }
}

int _int(dynamic value, {int fallback = 0}) =>
    value is int ? value : int.tryParse('$value') ?? fallback;

double _double(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

int? _nullableInt(dynamic value) {
  if (value == null) return null;
  return _int(value);
}

DateTime? _date(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
