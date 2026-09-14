import '../../data/models/fpl_models.dart';

abstract interface class FixturesRepository {
  Future<FplBootstrap> getBootstrap();

  Future<List<FplFixture>> getFixtures({int? gameweekId});

  Future<Map<int, int>> getGameweekPoints(int gameweekId);

  Future<Map<int, int>> getEntryHistoryPoints(int entryId);

  Future<FplPlayerSummary> getPlayerSummary(int playerId);
}
