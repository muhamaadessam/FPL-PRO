import '../../../auth/domain/entities/official_session.dart';
import '../../data/models/team_models.dart';
import '../repositories/team_repository.dart';

class GetTeamForGameweek {
  const GetTeamForGameweek(this._repository);

  final TeamRepository _repository;

  Future<MyTeam> call({
    required OfficialSession session,
    required int entryId,
    required int gameweekId,
    required int currentGameweekId,
  }) {
    return _repository.getTeamForGameweek(
      session: session,
      entryId: entryId,
      gameweekId: gameweekId,
      currentGameweekId: currentGameweekId,
    );
  }
}
