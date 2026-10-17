import 'package:fpl_engine/fpl_engine.dart';

abstract interface class FixturesRepository {
  Future<FplBootstrap> getBootstrap();

  Future<List<FplFixture>> getFixtures({int? gameweekId});

  Future<Map<int, int>> getGameweekPoints(int gameweekId);

  /// Minutes played by every player in a Gameweek.
  Future<Map<int, int>> getGameweekMinutes(int gameweekId);

  Future<Map<int, int>> getEntryHistoryPoints(int entryId);

  Future<FplPlayerSummary> getPlayerSummary(int playerId);

  /// Match predictions from the scheduled server job, with players taken from
  /// [players]; null when unavailable. Check them with
  /// [PublishedFixturePredictions.usableFor] before use.
  Future<PublishedFixturePredictions?> getPublishedFixturePredictions(
    Map<int, FplPlayer> players,
  );

  /// General player projections from the scheduled server job; null when
  /// unavailable or missing any of [players].
  Future<PublishedPlayerProjections?> getPublishedPlayerProjections(
    Map<int, FplPlayer> players,
  );
}
