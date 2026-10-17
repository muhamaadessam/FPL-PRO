import 'package:fpl_engine/fpl_engine.dart';

abstract interface class FixturesRepository {
  Future<FplBootstrap> getBootstrap();

  Future<List<FplFixture>> getFixtures({int? gameweekId});

  Future<Map<int, int>> getGameweekPoints(int gameweekId);

  /// Minutes played by every player in a Gameweek.
  Future<Map<int, int>> getGameweekMinutes(int gameweekId);

  Future<Map<int, int>> getEntryHistoryPoints(int entryId);

  Future<FplPlayerSummary> getPlayerSummary(int playerId);
}
