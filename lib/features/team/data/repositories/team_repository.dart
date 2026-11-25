import '../../../auth/domain/entities/official_session.dart';
import '../../../fixtures/data/datasources/fpl_api_client.dart';
import '../../domain/repositories/team_repository.dart';
import 'package:fpl_engine/fpl_engine.dart';

class TeamRepositoryImpl implements TeamRepository {
  const TeamRepositoryImpl(this._dataSource);

  final FplApiClient _dataSource;

  @override
  Future<FplEntry> getEntry(int entryId) {
    return _dataSource.getEntry(entryId);
  }

  @override
  Future<FplLeagueDetails> getLeagueStandings({
    required FplLeague league,
    int page = 1,
  }) {
    return _dataSource.getLeagueStandings(league: league, page: page);
  }

  @override
  Future<MyTeam> getMyTeam({
    required OfficialSession session,
    required int entryId,
    required int gameweekId,
  }) {
    if (session.isGuest) {
      return _getLatestPublicTeam(entryId: entryId, gameweekId: gameweekId);
    }
    return _dataSource.getMyTeam(
      session: session,
      entryId: entryId,
      gameweekId: gameweekId,
    );
  }

  /// Without a sign-in the upcoming squad is private, so a team-ID session
  /// uses the picks published at the last deadline instead.
  Future<MyTeam> _getLatestPublicTeam({
    required int entryId,
    required int gameweekId,
  }) async {
    try {
      return await getPublicTeam(entryId: entryId, gameweekId: gameweekId);
    } on FplApiException catch (error) {
      if (error.statusCode != 404 || gameweekId <= 1) rethrow;
      final team = await getPublicTeam(
        entryId: entryId,
        gameweekId: gameweekId - 1,
      );
      // A Free Hit lasts one Gameweek, then the squad before it comes back.
      if (team.activeChip != FplChipName.freeHit || gameweekId <= 2) {
        return team;
      }
      return getPublicTeam(entryId: entryId, gameweekId: gameweekId - 2);
    }
  }

  @override
  Future<MyTeam> withPublicTransfers({
    required MyTeam team,
    required int entryId,
    required FplBootstrap bootstrap,
  }) async {
    final (history, transfers) = await (
      _dataSource.getEntryHistory(entryId),
      _dataSource.getEntryTransfers(entryId),
    ).wait;
    return withPublicTransferState(
      team: team,
      bootstrap: bootstrap,
      history: history,
      transfers: transfers,
    );
  }

  @override
  Future<MyTeam> getTeamForGameweek({
    required OfficialSession session,
    required int entryId,
    required int gameweekId,
    required int editableGameweekId,
  }) {
    // Only the gameweek still open for changes comes from the private squad
    // endpoint; once a deadline has passed the official picks are final.
    if (gameweekId >= editableGameweekId) {
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
  Future<void> makeTransfers({
    required OfficialSession session,
    required int entryId,
    required int gameweekId,
    required List<TransferRequest> transfers,
    String? chip,
  }) {
    return _dataSource.makeTransfers(
      session: session,
      entryId: entryId,
      gameweekId: gameweekId,
      transfers: transfers,
      chip: chip,
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
