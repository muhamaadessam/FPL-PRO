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

int? _nullableInt(dynamic value) {
  if (value == null) return null;
  return _int(value);
}
