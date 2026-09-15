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

  TeamPick copyWith({
    int? elementId,
    int? position,
    int? multiplier,
    bool? isCaptain,
    bool? isViceCaptain,
    int? elementType,
    int? purchasePrice,
    int? sellingPrice,
  }) {
    return TeamPick(
      elementId: elementId ?? this.elementId,
      position: position ?? this.position,
      multiplier: multiplier ?? this.multiplier,
      isCaptain: isCaptain ?? this.isCaptain,
      isViceCaptain: isViceCaptain ?? this.isViceCaptain,
      elementType: elementType ?? this.elementType,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
    );
  }

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

class FplEntry {
  const FplEntry({
    required this.id,
    required this.name,
    this.playerFirstName = '',
    this.playerLastName = '',
    this.summaryOverallPoints,
    this.summaryOverallRank,
    this.summaryEventPoints,
    this.leagues = const [],
  });

  final int id;
  final String name;
  final String playerFirstName;
  final String playerLastName;
  final int? summaryOverallPoints;
  final int? summaryOverallRank;
  final int? summaryEventPoints;
  final List<FplLeague> leagues;

  String get playerFullName {
    final first = playerFirstName.trim();
    final last = playerLastName.trim();
    if (first.isEmpty) return last;
    if (last.isEmpty) return first;
    return '$first $last';
  }

  factory FplEntry.fromJson(Map<String, dynamic> json) {
    final leaguesJson = json['leagues'];
    final leagues = <FplLeague>[];
    if (leaguesJson is Map) {
      leagues.addAll(_parseLeagues(leaguesJson['classic']));
      leagues.addAll(_parseLeagues(leaguesJson['h2h'], isHeadToHead: true));
    }
    return FplEntry(
      id: _int(json['id']),
      name: json['name'] as String? ?? '',
      playerFirstName: json['player_first_name'] as String? ?? '',
      playerLastName: json['player_last_name'] as String? ?? '',
      summaryOverallPoints: _nullableInt(json['summary_overall_points']),
      summaryOverallRank: _nullableInt(json['summary_overall_rank']),
      summaryEventPoints: _nullableInt(json['summary_event_points']),
      leagues: leagues,
    );
  }
}

class FplLeague {
  const FplLeague({
    required this.id,
    required this.name,
    required this.leagueType,
    required this.scoring,
    required this.isHeadToHead,
    this.shortName,
    this.currentRank,
    this.lastRank,
    this.rankCount,
  });

  final int id;
  final String name;
  final String? shortName;
  final String leagueType;
  final String scoring;
  final bool isHeadToHead;
  final int? currentRank;
  final int? lastRank;
  final int? rankCount;

  factory FplLeague.fromJson(
    Map<String, dynamic> json, {
    bool isHeadToHead = false,
  }) {
    return FplLeague(
      id: _int(json['id']),
      name: json['name'] as String? ?? '',
      shortName: json['short_name'] as String?,
      leagueType: json['league_type'] as String? ?? '',
      scoring: json['scoring'] as String? ?? '',
      isHeadToHead: isHeadToHead,
      currentRank: _nullableInt(json['entry_rank']),
      lastRank: _nullableInt(json['entry_last_rank']),
      rankCount: _nullableInt(json['rank_count']),
    );
  }
}

class FplLeagueStanding {
  const FplLeagueStanding({
    required this.entryId,
    required this.managerName,
    required this.teamName,
    this.currentRank,
    this.lastRank,
    this.gameweekPoints,
    this.totalPoints,
    this.pointsFor,
    this.matchesPlayed,
    this.matchesWon,
    this.matchesDrawn,
    this.matchesLost,
  });

  final int entryId;
  final String managerName;
  final String teamName;
  final int? currentRank;
  final int? lastRank;
  final int? gameweekPoints;
  final int? totalPoints;
  final int? pointsFor;
  final int? matchesPlayed;
  final int? matchesWon;
  final int? matchesDrawn;
  final int? matchesLost;

  factory FplLeagueStanding.fromJson(Map<String, dynamic> json) {
    return FplLeagueStanding(
      entryId: _int(json['entry']),
      managerName: json['player_name'] as String? ?? '',
      teamName: json['entry_name'] as String? ?? '',
      currentRank: _nullableInt(json['rank'] ?? json['rank_sort']),
      lastRank: _nullableInt(json['last_rank']),
      gameweekPoints: _nullableInt(json['event_total']),
      totalPoints: _nullableInt(json['total']),
      pointsFor: _nullableInt(json['points_for']),
      matchesPlayed: _nullableInt(json['matches_played']),
      matchesWon: _nullableInt(json['matches_won']),
      matchesDrawn: _nullableInt(json['matches_drawn']),
      matchesLost: _nullableInt(json['matches_lost']),
    );
  }
}

class FplLeagueDetails {
  const FplLeagueDetails({required this.league, required this.standings});

  final FplLeague league;
  final List<FplLeagueStanding> standings;
}

List<FplLeague> _parseLeagues(dynamic value, {bool isHeadToHead = false}) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map(
        (item) => FplLeague.fromJson(
          Map<String, dynamic>.from(item),
          isHeadToHead: isHeadToHead,
        ),
      )
      .toList(growable: false);
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

int? _nullableInt(dynamic value) {
  if (value == null) return null;
  return _int(value);
}
