import 'models/fpl_models.dart';
import 'predict_fixtures.dart';
import 'recommendation_engine.dart';

/// JSON written by `bin/publish_predictions.dart` and read by the app, so
/// every user sees the same numbers and the model can change without an app
/// release. Players are stored by id and rehydrated from the reader's own
/// bootstrap, so names, prices and news stay live.
///
/// Bump [publishedSchemaVersion] (and the `/v1/` path) on breaking changes.
const publishedSchemaVersion = 1;

/// Older files are ignored and the app computes on device instead.
const publishedMaxAge = Duration(hours: 36);

/// The Gameweek player projections are for: the next deadline, or the last
/// Gameweek once the season is over.
int projectionGameweekId(FplBootstrap bootstrap) {
  if (bootstrap.gameweeks.isEmpty) return bootstrap.currentGameweekId;
  return bootstrap.gameweeks
      .firstWhere(
        (gameweek) => gameweek.isNext,
        orElse: () => bootstrap.gameweeks.firstWhere(
          (gameweek) => gameweek.id > bootstrap.currentGameweekId,
          orElse: () => bootstrap.gameweeks.last,
        ),
      )
      .id;
}

/// Match predictions for the Gameweeks from [fromGameweekId], as
/// [FixturePredictionEngine.predictNextGameweeks] returns them.
class PublishedFixturePredictions {
  const PublishedFixturePredictions({
    required this.generatedAt,
    required this.fromGameweekId,
    required this.predictions,
  });

  final DateTime generatedAt;
  final int fromGameweekId;
  final Map<int, FixturePrediction> predictions;

  Map<String, dynamic> toJson() => {
    'schemaVersion': publishedSchemaVersion,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'fromGameweekId': fromGameweekId,
    'predictions': [
      for (final entry in predictions.entries)
        {'fixtureId': entry.key, ..._predictionToJson(entry.value)},
    ],
  };

  /// Null when the JSON is malformed or from another schema version. Events
  /// for players missing from [players] are dropped.
  static PublishedFixturePredictions? fromJson(
    Object? json,
    Map<int, FplPlayer> players,
  ) {
    try {
      if (json is! Map || json['schemaVersion'] != publishedSchemaVersion) {
        return null;
      }
      return PublishedFixturePredictions(
        generatedAt: DateTime.parse(json['generatedAt'] as String),
        fromGameweekId: json['fromGameweekId'] as int,
        predictions: {
          for (final item in json['predictions'] as List)
            (item as Map)['fixtureId'] as int: _predictionFromJson(
              item,
              players,
            ),
        },
      );
    } on Object {
      return null;
    }
  }

  /// The predictions when they match what the reader sees now: the same
  /// current Gameweek and not older than [publishedMaxAge]. Fixtures that have
  /// kicked off since publishing are left out, as on device.
  Map<int, FixturePrediction>? usableFor({
    required FplBootstrap bootstrap,
    required List<FplFixture> fixtures,
    DateTime? now,
  }) {
    if (fromGameweekId != bootstrap.currentGameweekId ||
        _isStale(generatedAt, now)) {
      return null;
    }
    final upcoming = {
      for (final fixture in fixtures)
        if (!fixture.started && !fixture.isFinished) fixture.id,
    };
    return Map.unmodifiable({
      for (final entry in predictions.entries)
        if (upcoming.contains(entry.key)) entry.key: entry.value,
    });
  }
}

/// General (not squad-specific) projections for every player, as
/// [RecommendationEngine.buildPlayerProjections] returns them with live
/// recent minutes.
class PublishedPlayerProjections {
  const PublishedPlayerProjections({
    required this.generatedAt,
    required this.gameweekId,
    required this.projections,
  });

  final DateTime generatedAt;
  final int gameweekId;
  final List<PlayerProjection> projections;

  Map<String, dynamic> toJson() => {
    'schemaVersion': publishedSchemaVersion,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'gameweekId': gameweekId,
    'projections': [
      for (final projection in projections)
        {
          'playerId': projection.player.id,
          'nextPoints': _round(projection.nextPoints),
          'horizonPoints': _round(projection.horizonPoints),
          'availability': _round(projection.availability),
          'nextFixtureCount': projection.nextFixtureCount,
          'nextDifficulties': projection.nextDifficulties,
          'nextFixtureLoad': _round(projection.nextFixtureLoad),
          'availabilityOutlook': [
            for (final chance in projection.availabilityOutlook) _round(chance),
          ],
        },
    ],
  };

  /// Null when the JSON is malformed, from another schema version, or misses
  /// a player in [players] (a new signing since publishing), so the reader
  /// never works from a partial list.
  static PublishedPlayerProjections? fromJson(
    Object? json,
    Map<int, FplPlayer> players,
  ) {
    try {
      if (json is! Map || json['schemaVersion'] != publishedSchemaVersion) {
        return null;
      }
      final projections = <PlayerProjection>[];
      for (final item in (json['projections'] as List).cast<Map>()) {
        final player = players[item['playerId'] as int];
        if (player == null) continue;
        projections.add(
          PlayerProjection(
            player: player,
            nextPoints: _double(item['nextPoints']),
            horizonPoints: _double(item['horizonPoints']),
            availability: _double(item['availability']),
            nextFixtureCount: item['nextFixtureCount'] as int,
            nextDifficulties: List.unmodifiable(
              (item['nextDifficulties'] as List).cast<int>(),
            ),
            nextFixtureLoad: _double(item['nextFixtureLoad']),
            availabilityOutlook: List.unmodifiable(
              (item['availabilityOutlook'] as List).map(_double),
            ),
          ),
        );
      }
      if (projections.length != players.length) return null;
      return PublishedPlayerProjections(
        generatedAt: DateTime.parse(json['generatedAt'] as String),
        gameweekId: json['gameweekId'] as int,
        projections: List.unmodifiable(projections),
      );
    } on Object {
      return null;
    }
  }

  /// The projections when they are for [gameweekId] and not older than
  /// [publishedMaxAge].
  List<PlayerProjection>? usableFor(int gameweekId, {DateTime? now}) {
    if (this.gameweekId != gameweekId || _isStale(generatedAt, now)) {
      return null;
    }
    return projections;
  }
}

bool _isStale(DateTime generatedAt, DateTime? now) =>
    (now ?? DateTime.now()).difference(generatedAt) > publishedMaxAge;

Map<String, dynamic> _predictionToJson(FixturePrediction p) {
  List<Map<String, int>> events(List<PlayerEventPrediction> events) => [
    for (final event in events)
      {'playerId': event.player.id, 'chance': event.chance},
  ];
  return {
    'homeGoals': p.homeGoals,
    'awayGoals': p.awayGoals,
    'homeExpectedGoals': _round(p.homeExpectedGoals),
    'awayExpectedGoals': _round(p.awayExpectedGoals),
    'homeWinChance': p.homeWinChance,
    'drawChance': p.drawChance,
    'awayWinChance': p.awayWinChance,
    'homeCleanSheetChance': p.homeCleanSheetChance,
    'awayCleanSheetChance': p.awayCleanSheetChance,
    'confidence': p.confidence,
    'homeScorers': events(p.homeScorers),
    'awayScorers': events(p.awayScorers),
    'homeAssists': events(p.homeAssists),
    'awayAssists': events(p.awayAssists),
  };
}

FixturePrediction _predictionFromJson(
  Map<dynamic, dynamic> json,
  Map<int, FplPlayer> players,
) {
  List<PlayerEventPrediction> events(String key) => List.unmodifiable([
    for (final item in (json[key] as List).cast<Map>())
      if (players[item['playerId'] as int] case final player?)
        PlayerEventPrediction(player: player, chance: item['chance'] as int),
  ]);
  // The combined top three are rebuilt from each side's list, as the engine
  // builds them.
  List<PlayerEventPrediction> top(
    List<PlayerEventPrediction> home,
    List<PlayerEventPrediction> away,
  ) => List.unmodifiable(
    ([...home, ...away]..sort((a, b) => b.chance.compareTo(a.chance))).take(3),
  );
  final homeScorers = events('homeScorers');
  final awayScorers = events('awayScorers');
  final homeAssists = events('homeAssists');
  final awayAssists = events('awayAssists');
  return FixturePrediction(
    homeGoals: json['homeGoals'] as int,
    awayGoals: json['awayGoals'] as int,
    homeExpectedGoals: _double(json['homeExpectedGoals']),
    awayExpectedGoals: _double(json['awayExpectedGoals']),
    homeWinChance: json['homeWinChance'] as int,
    drawChance: json['drawChance'] as int,
    awayWinChance: json['awayWinChance'] as int,
    homeCleanSheetChance: json['homeCleanSheetChance'] as int,
    awayCleanSheetChance: json['awayCleanSheetChance'] as int,
    confidence: json['confidence'] as int,
    scorers: top(homeScorers, awayScorers),
    assists: top(homeAssists, awayAssists),
    homeScorers: homeScorers,
    awayScorers: awayScorers,
    homeAssists: homeAssists,
    awayAssists: awayAssists,
  );
}

double _double(Object? value) => (value as num).toDouble();

/// Three decimals keep the files small without changing any shown value.
double _round(double value) => (value * 1000).roundToDouble() / 1000;
