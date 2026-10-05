import '../../domain/repositories/fixtures_repository.dart';
import '../datasources/fpl_api_client.dart';
import '../models/fpl_models.dart';

class FixturesRepositoryImpl implements FixturesRepository {
  const FixturesRepositoryImpl(this._dataSource);

  final FplApiClient _dataSource;

  @override
  Future<FplBootstrap> getBootstrap() => _dataSource.getBootstrap();

  @override
  Future<List<FplFixture>> getFixtures({int? gameweekId}) {
    return _dataSource.getFixtures(gameweekId: gameweekId);
  }

  @override
  Future<Map<int, int>> getGameweekPoints(int gameweekId) {
    return _dataSource.getGameweekPoints(gameweekId);
  }

  @override
  Future<Map<int, int>> getEntryHistoryPoints(int entryId) {
    return _dataSource.getEntryHistoryPoints(entryId);
  }

  @override
  Future<FplPlayerSummary> getPlayerSummary(int playerId) {
    return _dataSource.getPlayerSummary(playerId);
  }
}
