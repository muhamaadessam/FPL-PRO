import '../../../auth/domain/entities/official_session.dart';
import '../../data/models/team_models.dart';

abstract interface class TeamRepository {
  Future<FplEntry> getEntry(int entryId);

  Future<FplLeagueDetails> getLeagueStandings({
    required FplLeague league,
    int page = 1,
  });

  Future<MyTeam> getMyTeam({
    required OfficialSession session,
    required int entryId,
    required int gameweekId,
  });

  Future<MyTeam> getTeamForGameweek({
    required OfficialSession session,
    required int entryId,
    required int gameweekId,
    required int currentGameweekId,
  });

  Future<MyTeam> getPublicTeam({required int entryId, required int gameweekId});

  Future<void> makeTransfers({
    required OfficialSession session,
    required int entryId,
    required int gameweekId,
    required List<TransferRequest> transfers,
    String? chip,
  });

  Future<void> saveMyTeam({
    required OfficialSession session,
    required int entryId,
    required String? chip,
    required List<TeamPick> picks,
  });
}
