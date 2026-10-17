import '../../domain/repositories/fixtures_repository.dart';
import '../datasources/fpl_api_client.dart';
import '../datasources/published_predictions_client.dart';
import 'package:fpl_engine/fpl_engine.dart';

class FixturesRepositoryImpl implements FixturesRepository {
  /// Without [published] the app always computes predictions on device.
  const FixturesRepositoryImpl(this._dataSource, {this._published});

  final FplApiClient _dataSource;
  final PublishedPredictionsClient? _published;

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
  Future<Map<int, int>> getGameweekMinutes(int gameweekId) {
    return _dataSource.getGameweekMinutes(gameweekId);
  }

  @override
  Future<Map<int, int>> getEntryHistoryPoints(int entryId) {
    return _dataSource.getEntryHistoryPoints(entryId);
  }

  @override
  Future<FplPlayerSummary> getPlayerSummary(int playerId) {
    return _dataSource.getPlayerSummary(playerId);
  }

  @override
  Future<PublishedFixturePredictions?> getPublishedFixturePredictions(
    Map<int, FplPlayer> players,
  ) async {
    final published = _published;
    if (published == null) return null;
    return PublishedFixturePredictions.fromJson(
      await published.fixturePredictions(),
      players,
    );
  }

  @override
  Future<PublishedPlayerProjections?> getPublishedPlayerProjections(
    Map<int, FplPlayer> players,
  ) async {
    final published = _published;
    if (published == null) return null;
    return PublishedPlayerProjections.fromJson(
      await published.playerProjections(),
      players,
    );
  }
}
