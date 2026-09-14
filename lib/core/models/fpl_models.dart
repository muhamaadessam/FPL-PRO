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
  });

  final int id;
  final String name;
  final DateTime? deadlineTime;
  final bool finished;
  final bool isCurrent;
  final bool isNext;
  final int? averageEntryScore;
  final int? highestScore;

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
    );
  }
}

class FplTeam {
  const FplTeam({
    required this.id,
    required this.name,
    required this.shortName,
    this.code,
  });

  final int id;
  final String name;
  final String shortName;
  final int? code;

  factory FplTeam.fromJson(Map<String, dynamic> json) {
    return FplTeam(
      id: _int(json['id']),
      name: json['name'] as String? ?? 'Team ${json['id']}',
      shortName: json['short_name'] as String? ?? '',
      code: _nullableInt(json['code']),
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
    this.chanceOfPlayingNextRound,
    this.canSelect = true,
    this.form = 0,
    this.pointsPerGame = 0,
    this.expectedPointsNext = 0,
    this.selectedByPercent = 0,
    this.minutes = 0,
    this.starts = 0,
    this.expectedGoalInvolvements = 0,
    this.expectedGoalsConceded = 0,
    this.defensiveContribution = 0,
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
  final int? chanceOfPlayingNextRound;
  final bool canSelect;
  final double form;
  final double pointsPerGame;
  final double expectedPointsNext;
  final double selectedByPercent;
  final int minutes;
  final int starts;
  final double expectedGoalInvolvements;
  final double expectedGoalsConceded;
  final int defensiveContribution;

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
      expectedGoalInvolvements: _double(json['expected_goal_involvements']),
      expectedGoalsConceded: _double(json['expected_goals_conceded']),
      defensiveContribution: _int(json['defensive_contribution']),
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

class FplFixture {
  const FplFixture({
    required this.id,
    required this.gameweekId,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.kickoffTime,
    required this.finished,
    required this.started,
    this.homeScore,
    this.awayScore,
    this.homeDifficulty,
    this.awayDifficulty,
  });

  final int id;
  final int? gameweekId;
  final int homeTeamId;
  final int awayTeamId;
  final DateTime? kickoffTime;
  final bool finished;
  final bool started;
  final int? homeScore;
  final int? awayScore;
  final int? homeDifficulty;
  final int? awayDifficulty;

  factory FplFixture.fromJson(Map<String, dynamic> json) {
    return FplFixture(
      id: _int(json['id']),
      gameweekId: _nullableInt(json['event']),
      homeTeamId: _int(json['team_h']),
      awayTeamId: _int(json['team_a']),
      kickoffTime: _date(json['kickoff_time']),
      finished: json['finished'] as bool? ?? false,
      started: json['started'] as bool? ?? false,
      homeScore: _nullableInt(json['team_h_score']),
      awayScore: _nullableInt(json['team_a_score']),
      homeDifficulty: _nullableInt(json['team_h_difficulty']),
      awayDifficulty: _nullableInt(json['team_a_difficulty']),
    );
  }
}

class TeamPick {
  const TeamPick({
    required this.elementId,
    required this.position,
    required this.multiplier,
    required this.isCaptain,
    required this.isViceCaptain,
    required this.elementType,
    this.purchasePrice,
    this.sellingPrice,
  });

  final int elementId;
  final int position;
  final int multiplier;
  final bool isCaptain;
  final bool isViceCaptain;
  final int elementType;
  final int? purchasePrice;
  final int? sellingPrice;

  factory TeamPick.fromJson(Map<String, dynamic> json) {
    return TeamPick(
      elementId: _int(json['element']),
      position: _int(json['position']),
      multiplier: _int(json['multiplier']),
      isCaptain: json['is_captain'] as bool? ?? false,
      isViceCaptain: json['is_vice_captain'] as bool? ?? false,
      elementType: _int(json['element_type']),
      purchasePrice: _nullableInt(json['purchase_price']),
      sellingPrice: _nullableInt(json['selling_price']),
    );
  }
}

class TeamSummary {
  const TeamSummary({
    required this.gameweekId,
    required this.points,
    required this.totalPoints,
    required this.overallRank,
    required this.bank,
    required this.value,
    required this.pointsOnBench,
  });

  final int gameweekId;
  final int points;
  final int totalPoints;
  final int? overallRank;
  final int? bank;
  final int? value;
  final int? pointsOnBench;

  factory TeamSummary.fromJson(Map<String, dynamic> json) {
    return TeamSummary(
      gameweekId: _int(json['event']),
      points: _int(json['points']),
      totalPoints: _int(json['total_points']),
      overallRank: _nullableInt(json['overall_rank']),
      bank: _nullableInt(json['bank']),
      value: _nullableInt(json['value']),
      pointsOnBench: _nullableInt(json['points_on_bench']),
    );
  }
}

class TeamTransferState {
  const TeamTransferState({
    this.bank,
    this.value,
    this.limit,
    this.made,
    this.cost,
  });

  final int? bank;
  final int? value;
  final int? limit;
  final int? made;
  final int? cost;

  factory TeamTransferState.fromJson(Map<String, dynamic> json) {
    return TeamTransferState(
      bank: _nullableInt(json['bank']),
      value: _nullableInt(json['value']),
      limit: _nullableInt(json['limit']),
      made: _nullableInt(json['made']),
      cost: _nullableInt(json['cost']),
    );
  }
}

class FplChipState {
  const FplChipState({
    required this.name,
    this.statusForEntry,
    this.startEvent,
    this.stopEvent,
    this.playedEvents = const [],
  });

  final String name;
  final String? statusForEntry;
  final int? startEvent;
  final int? stopEvent;
  final List<int> playedEvents;

  bool isAvailableFor(int event) {
    return statusForEntry == 'available' &&
        (startEvent == null || event >= startEvent!) &&
        (stopEvent == null || event <= stopEvent!) &&
        !playedEvents.contains(event) &&
        !(name == 'freehit' && playedEvents.contains(event - 1));
  }

  factory FplChipState.fromJson(Map<String, dynamic> json) {
    return FplChipState(
      name: json['name'] as String? ?? '',
      statusForEntry: json['status_for_entry'] as String?,
      startEvent: _nullableInt(json['start_event']),
      stopEvent: _nullableInt(json['stop_event']),
      playedEvents: (json['played_by_entry'] as List<dynamic>? ?? const [])
          .map(
            (value) => value is Map
                ? _nullableInt(value['event'])
                : _nullableInt(value),
          )
          .whereType<int>()
          .toList(growable: false),
    );
  }
}

class MyTeam {
  const MyTeam({
    required this.picks,
    required this.summary,
    required this.transfers,
    required this.chips,
  });

  final List<TeamPick> picks;
  final TeamSummary summary;
  final TeamTransferState transfers;
  final List<FplChipState> chips;

  factory MyTeam.fromJson(Map<String, dynamic> json) {
    final history = json['entry_history'];
    return MyTeam(
      picks: (json['picks'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(TeamPick.fromJson)
          .toList(growable: false),
      summary: TeamSummary.fromJson(
        history is Map<String, dynamic> ? history : const {},
      ),
      transfers: TeamTransferState.fromJson(
        json['transfers'] is Map<String, dynamic>
            ? json['transfers'] as Map<String, dynamic>
            : const {},
      ),
      chips: (json['chips'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(FplChipState.fromJson)
          .toList(growable: false),
    );
  }
}

int _int(dynamic value) => value is int ? value : int.tryParse('$value') ?? 0;

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
