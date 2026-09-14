import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/fpl_models.dart';
import '../../../core/network/fpl_api_client.dart';
import '../../../core/security/session_store.dart';
import '../../auth/application/auth_controller.dart';

final teamRepositoryProvider = Provider<TeamRepository>((ref) {
  return TeamRepository(ref.read(fplApiClientProvider));
});

final myTeamProvider = FutureProvider.autoDispose.family<MyTeam, int>((
  ref,
  gameweekId,
) async {
  final session = ref.watch(authControllerProvider).value;
  if (session == null || session.entryId == null) {
    throw const TeamAccessException(TeamAccessError.entryIdMissing);
  }

  final bootstrap = await ref.watch(bootstrapProvider.future);
  return ref
      .read(teamRepositoryProvider)
      .getTeamForGameweek(
        session: session,
        entryId: session.entryId!,
        gameweekId: gameweekId,
        currentGameweekId: bootstrap.currentGameweekId,
      );
});

typedef PublicTeamQuery = ({int entryId, int gameweekId});

final publicTeamProvider = FutureProvider.autoDispose
    .family<MyTeam, PublicTeamQuery>((ref, query) async {
      return ref
          .read(teamRepositoryProvider)
          .getPublicTeam(entryId: query.entryId, gameweekId: query.gameweekId);
    });

final recommendationTeamProvider = FutureProvider.autoDispose
    .family<MyTeam, int>((ref, gameweekId) async {
      final session = ref.watch(authControllerProvider).value;
      if (session == null || session.entryId == null) {
        throw const TeamAccessException(TeamAccessError.entryIdMissing);
      }
      return ref
          .read(teamRepositoryProvider)
          .getMyTeam(
            session: session,
            entryId: session.entryId!,
            gameweekId: gameweekId,
          );
    });

class TeamRepository {
  const TeamRepository(this._apiClient);

  final FplApiClient _apiClient;

  Future<MyTeam> getMyTeam({
    required OfficialSession session,
    required int entryId,
    required int gameweekId,
  }) {
    return _apiClient.getMyTeam(
      session: session,
      entryId: entryId,
      gameweekId: gameweekId,
    );
  }

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

  Future<MyTeam> getPublicTeam({
    required int entryId,
    required int gameweekId,
  }) {
    return _apiClient.getPublicTeam(entryId: entryId, gameweekId: gameweekId);
  }
}

enum TeamAccessError { entryIdMissing }

class TeamAccessException implements Exception {
  const TeamAccessException(this.error);

  final TeamAccessError error;
}
