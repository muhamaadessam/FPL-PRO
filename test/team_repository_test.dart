import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fantasy_pl/features/fixtures/data/datasources/fpl_api_client.dart';
import 'package:fantasy_pl/features/auth/domain/entities/official_session.dart';
import 'package:fantasy_pl/features/team/data/models/team_models.dart';
import 'package:fantasy_pl/features/team/data/repositories/team_repository.dart';

void main() {
  test(
    'uses public picks for played gameweeks and private picks for future',
    () async {
      final api = _FakeFplApiClient();
      final repository = TeamRepositoryImpl(api);
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

      expect(api.privateRequests, [5]);
      expect(api.publicRequests, [4, 3]);
    },
  );

  test('delegates getEntry to api client', () async {
    final api = _FakeFplApiClient();
    final repository = TeamRepositoryImpl(api);

    final entry = await repository.getEntry(267022);
    expect(entry.id, 267022);
    expect(entry.name, 'Test FC');
    expect(api.entryRequests, [267022]);
  });

  test('parses classic and head-to-head league ranks from an entry', () {
    final entry = FplEntry.fromJson({
      'id': 42,
      'name': 'Test FC',
      'leagues': {
        'classic': [
          {
            'id': 1,
            'name': 'Overall',
            'league_type': 's',
            'scoring': 'c',
            'entry_rank': 12,
            'entry_last_rank': 18,
          },
        ],
        'h2h': [
          {
            'id': 2,
            'name': 'Rivals',
            'league_type': 'x',
            'scoring': 'h',
            'entry_rank': 2,
            'entry_last_rank': 3,
          },
        ],
      },
    });

    expect(entry.leagues, hasLength(2));
    expect(entry.leagues.first.currentRank, 12);
    expect(entry.leagues.last.isHeadToHead, isTrue);
    expect(entry.leagues.last.lastRank, 3);
  });
}

class _FakeFplApiClient extends FplApiClient {
  _FakeFplApiClient() : super(dio: Dio());

  final privateRequests = <int>[];
  final publicRequests = <int>[];
  final entryRequests = <int>[];

  @override
  Future<FplEntry> getEntry(int entryId) async {
    entryRequests.add(entryId);
    return FplEntry(id: entryId, name: 'Test FC');
  }

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
  Future<void> makeTransfer({
    required OfficialSession session,
    required int entryId,
    required int gameweekId,
    required int elementIn,
    required int elementOut,
    required int purchasePrice,
    required int sellingPrice,
  }) async {}

  @override
  Future<void> saveMyTeam({
    required OfficialSession session,
    required int entryId,
    required String? chip,
    required List<TeamPick> picks,
  }) async {}

  @override
  void dispose() {}
}
