import 'dart:convert';
import 'dart:typed_data';

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

  test('loads every page of league standings', () async {
    final pages = <int>[];
    final dio = Dio()
      ..httpClientAdapter = _FakeAdapter((options) {
        final page = int.parse(
          options.queryParameters['page_standings'].toString(),
        );
        pages.add(page);
        return ResponseBody.fromString(
          jsonEncode({
            'league': {
              'id': 1604868,
              'name': 'League',
              'league_type': 'x',
              'scoring': 'c',
            },
            'standings': {
              'has_next': page == 1,
              'page': page,
              'results': [
                {
                  'entry': page,
                  'player_name': 'Manager $page',
                  'entry_name': 'Team $page',
                  'rank': page,
                  'last_rank': page + 1,
                  'event_total': 60 + page,
                  'total': 200 + page,
                },
              ],
            },
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

    final details = await FplApiClient(dio: dio).getLeagueStandings(
      league: const FplLeague(
        id: 1604868,
        name: 'League',
        leagueType: 'x',
        scoring: 'c',
        isHeadToHead: false,
      ),
    );

    expect(pages, [1, 2]);
    expect(details.standings, hasLength(2));
    expect(details.standings.last.gameweekPoints, 62);
    expect(details.standings.last.totalPoints, 202);
  });
}

class _FakeAdapter implements HttpClientAdapter {
  const _FakeAdapter(this.handler);

  final ResponseBody Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
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
