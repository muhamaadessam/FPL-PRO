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
    'uses private picks only for the gameweek still open for changes',
    () async {
      final api = _FakeFplApiClient();
      final repository = TeamRepositoryImpl(api);
      const session = OfficialSession(accessToken: 'test-token');

      await repository.getTeamForGameweek(
        session: session,
        entryId: 123,
        gameweekId: 4,
        editableGameweekId: 5,
      );
      await repository.getTeamForGameweek(
        session: session,
        entryId: 123,
        gameweekId: 5,
        editableGameweekId: 5,
      );
      await repository.getTeamForGameweek(
        session: session,
        entryId: 123,
        gameweekId: 3,
        editableGameweekId: 5,
      );

      expect(api.privateRequests, [5]);
      expect(api.publicRequests, [4, 3]);
    },
  );

  test('a team-ID session reads the latest published picks', () async {
    final api = _FakeFplApiClient()..missingPublicGameweeks.add(6);
    final repository = TeamRepositoryImpl(api);
    const session = OfficialSession.guest(123);

    await repository.getMyTeam(session: session, entryId: 123, gameweekId: 6);
    await repository.getTeamForGameweek(
      session: session,
      entryId: 123,
      gameweekId: 5,
      editableGameweekId: 5,
    );

    expect(api.privateRequests, isEmpty);
    // Gameweek 6 has no picks before its deadline, so gameweek 5 is used.
    expect(api.publicRequests, [6, 5, 5]);
  });

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

  group('a manager whose first gameweek has not started', () {
    // Shapes taken from the live API for an entry that joined in GW7 while
    // GW6 was the current gameweek.
    const entryJson = <String, dynamic>{
      'id': 11089273,
      'joined_time': '2026-10-15T08:09:44.052338Z',
      'started_event': 7,
      'player_first_name': 'New',
      'player_last_name': 'Manager',
      'name': null,
      'years_active': 0,
      'summary_overall_points': null,
      'summary_overall_rank': null,
      'summary_event_points': null,
      'summary_event_rank': null,
      'current_event': 6,
      'leagues': {
        'classic': [
          {
            'id': 15,
            'name': 'Man City',
            'short_name': 'team-15',
            'rank': null,
            'max_entries': null,
            'league_type': 's',
            'scoring': 'c',
            'admin_entry': null,
            'rank_count': 714759,
            'entry_percentile_rank': null,
            'entry_rank': 0,
            'entry_last_rank': 0,
          },
        ],
        'h2h': [],
        'cup': {'matches': [], 'status': {}},
        'cup_matches': [],
      },
    };

    test('parses the entry with null summary and zero league ranks', () {
      final entry = FplEntry.fromJson(entryJson);

      expect(entry.id, 11089273);
      expect(entry.name, isEmpty);
      expect(entry.playerFullName, 'New Manager');
      expect(entry.summaryOverallPoints, isNull);
      expect(entry.summaryOverallRank, isNull);
      expect(entry.summaryEventPoints, isNull);
      expect(entry.startedEvent, 7);
      expect(entry.hasStartedBy(6), isFalse);
      expect(entry.hasStartedBy(7), isTrue);
      expect(entry.leagues.single.currentRank, isNull);
      expect(entry.leagues.single.lastRank, isNull);
      expect(entry.leagues.single.rankCount, 714759);
    });

    test('treats an entry without started_event as already playing', () {
      final entry = FplEntry.fromJson(const {'id': 1, 'started_event': null});

      expect(entry.startedEvent, isNull);
      expect(entry.hasStartedBy(1), isTrue);
    });

    test('parses my-team without entry history or a transfer limit', () {
      final team = MyTeam.fromJson({
        'picks': [
          {
            'element': 10,
            'position': 1,
            'selling_price': 55,
            'multiplier': 1,
            'purchase_price': 55,
            'is_captain': false,
            'is_vice_captain': false,
            'element_type': 1,
          },
        ],
        'chips': [
          {
            'id': 1,
            'status_for_entry': 'available',
            'played_by_entry': [],
            'name': 'wildcard',
            'number': 1,
            'start_event': 2,
            'stop_event': 19,
            'chip_type': 'transfer',
          },
        ],
        'transfers': {
          'cost': 4,
          'status': 'unlimited',
          'limit': null,
          'made': 0,
          'bank': 0,
          'value': 1000,
        },
      });

      expect(team.picks.single.elementId, 10);
      expect(team.summary.gameweekId, 0);
      expect(team.summary.points, 0);
      expect(team.summary.overallRank, isNull);
      expect(team.transfers.limit, isNull);
      expect(team.transfers.bank, 0);
      expect(team.activeChip, isNull);
    });

    test('parses empty history as no points', () {
      expect(
        parseEntryHistoryPoints(const {'current': [], 'past': [], 'chips': []}),
        isEmpty,
      );
    });

    test('surfaces 404 picks for the current gameweek', () async {
      final dio = Dio()
        ..httpClientAdapter = _FakeAdapter(
          (_) => ResponseBody.fromString(
            jsonEncode({'detail': 'Not found.'}),
            404,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          ),
        );

      await expectLater(
        TeamRepositoryImpl(
          FplApiClient(dio: dio),
        ).getPublicTeam(entryId: 11089273, gameweekId: 6),
        throwsA(
          isA<FplApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            404,
          ),
        ),
      );
    });
  });

  test(
    'returns the first standings page without waiting for the rest',
    () async {
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

      expect(pages, [1]);
      expect(details.page, 1);
      expect(details.hasNext, isTrue);
      expect(details.standings, hasLength(1));
      expect(details.standings.first.gameweekPoints, 61);
      expect(details.standings.first.totalPoints, 201);
    },
  );
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
  final missingPublicGameweeks = <int>{};

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
    if (missingPublicGameweeks.contains(gameweekId)) {
      throw const FplApiException(
        kind: FplApiErrorKind.unknown,
        message: 'Not found.',
        statusCode: 404,
      );
    }
    return MyTeam.fromJson(const {'entry_history': {}});
  }

  @override
  Future<void> makeTransfers({
    required OfficialSession session,
    required int entryId,
    required int gameweekId,
    required List<TransferRequest> transfers,
    String? chip,
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
