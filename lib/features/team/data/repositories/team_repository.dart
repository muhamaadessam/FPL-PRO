import '../../../auth/domain/entities/official_session.dart';
import '../../../fixtures/data/datasources/fpl_api_client.dart';
import '../../domain/repositories/team_repository.dart';
import '../models/team_models.dart';

class TeamRepositoryImpl implements TeamRepository {
  const TeamRepositoryImpl(this._dataSource);

  final FplApiClient _dataSource;

  @override
  Future<FplEntry> getEntry(int entryId) {
    return _dataSource.getEntry(entryId);
  }

  @override
  Future<FplLeagueDetails> getLeagueStandings({required FplLeague league}) {
    return _dataSource.getLeagueStandings(league: league);
  }

  @override
  Future<MyTeam> getMyTeam({
    required OfficialSession session,
    required int entryId,
    required int gameweekId,
  }) {
    return _dataSource.getMyTeam(
      session: session,
      entryId: entryId,
      gameweekId: gameweekId,
    );
  }

  @override
  Future<MyTeam> getTeamForGameweek({
    required OfficialSession session,
    required int entryId,
    required int gameweekId,
    required int currentGameweekId,
  }) {
    if (gameweekId > currentGameweekId) {
      return getMyTeam(
        session: session,
        entryId: entryId,
        gameweekId: gameweekId,
      );
    }
    return getPublicTeam(entryId: entryId, gameweekId: gameweekId);
  }

  @override
  Future<MyTeam> getPublicTeam({
    required int entryId,
    required int gameweekId,
  }) {
    return _dataSource.getPublicTeam(entryId: entryId, gameweekId: gameweekId);
  }

  @override
  Future<void> makeTransfer({
    required OfficialSession session,
    required int entryId,
    required int gameweekId,
    required int elementIn,
    required int elementOut,
    required int purchasePrice,
    required int sellingPrice,
  }) {
    return _dataSource.makeTransfer(
      session: session,
      entryId: entryId,
      gameweekId: gameweekId,
      elementIn: elementIn,
      elementOut: elementOut,
      purchasePrice: purchasePrice,
      sellingPrice: sellingPrice,
    );
  }

  @override
  Future<void> saveMyTeam({
    required OfficialSession session,
    required int entryId,
    required String? chip,
    required List<TeamPick> picks,
  }) {
    return _dataSource.saveMyTeam(
      session: session,
      entryId: entryId,
      chip: chip,
      picks: picks,
    );
  }
}

enum TeamAccessError { entryIdMissing }

class TeamAccessException implements Exception {
  const TeamAccessException(this.error);

  final TeamAccessError error;
}
