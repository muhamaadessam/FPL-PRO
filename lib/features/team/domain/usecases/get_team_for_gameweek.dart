import '../../../auth/domain/entities/official_session.dart';
import 'package:fpl_engine/fpl_engine.dart';
import '../repositories/team_repository.dart';

class GetTeamForGameweek {
  const GetTeamForGameweek(this._repository);

  final TeamRepository _repository;

  Future<MyTeam> call({
    required OfficialSession session,
    required int entryId,
    required int gameweekId,
    required int editableGameweekId,
  }) {
    return _repository.getTeamForGameweek(
      session: session,
      entryId: entryId,
      gameweekId: gameweekId,
      editableGameweekId: editableGameweekId,
    );
  }
}
