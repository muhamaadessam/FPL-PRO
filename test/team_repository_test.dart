import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fantasy_pl/core/models/fpl_models.dart';
import 'package:fantasy_pl/core/network/fpl_api_client.dart';
import 'package:fantasy_pl/core/security/session_store.dart';
import 'package:fantasy_pl/features/team/data/team_repository.dart';

void main() {
  test('uses private picks for current and future gameweeks', () async {
    final api = _FakeFplApiClient();
    final repository = TeamRepository(api);
    const session = OfficialSession(accessToken: 'test-token');

    await repository.getTeamForGameweek(
      session: session,
      entryId: 123,
      gameweekId: 4,
      currentGameweekId: 4,
    );
    await repository.getTeamForGameweek(
      session: session,
      entryId: 123,
      gameweekId: 5,
      currentGameweekId: 4,
    );
    await repository.getTeamForGameweek(
      session: session,
      entryId: 123,
      gameweekId: 3,
      currentGameweekId: 4,
    );

    expect(api.privateRequests, [4, 5]);
    expect(api.publicRequests, [3]);
  });
}

class _FakeFplApiClient extends FplApiClient {
  _FakeFplApiClient() : super(dio: Dio());

  final privateRequests = <int>[];
  final publicRequests = <int>[];

  @override
  Future<MyTeam> getMyTeam({
    required int entryId,
    required int gameweekId,
    required OfficialSession session,
  }) async {
    privateRequests.add(gameweekId);
    return MyTeam.fromJson(const {'entry_history': {}});
  }

  @override
  Future<MyTeam> getPublicTeam({
    required int entryId,
    required int gameweekId,
  }) async {
    publicRequests.add(gameweekId);
    return MyTeam.fromJson(const {'entry_history': {}});
  }

  @override
  void dispose() {}
}
