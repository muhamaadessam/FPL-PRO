import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fantasy_pl/features/auth/domain/entities/official_session.dart';
import 'package:fantasy_pl/features/fixtures/data/datasources/fpl_api_client.dart';
import 'package:fantasy_pl/features/team/data/models/team_models.dart';

const _session = OfficialSession(
  accessToken: 'token',
  cookieHeader: 'csrftoken=abc; sessionid=xyz',
  csrfToken: 'abc',
);

void main() {
  late List<RequestOptions> requests;
  late FplApiClient client;

  setUp(() {
    requests = [];
    final dio = Dio(BaseOptions(baseUrl: officialFplBaseUrl))
      ..httpClientAdapter = _RecordingAdapter(requests);
    client = FplApiClient(dio: dio);
  });

  test('posts several transfers with a wildcard in one request', () async {
    await client.makeTransfers(
      session: _session,
      entryId: 42,
      gameweekId: 7,
      chip: FplChipName.wildcard,
      transfers: const [
        TransferRequest(
          elementIn: 1,
          elementOut: 2,
          purchasePrice: 55,
          sellingPrice: 60,
        ),
        TransferRequest(
          elementIn: 3,
          elementOut: 4,
          purchasePrice: 70,
          sellingPrice: 65,
        ),
      ],
    );

    final request = requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/transfers/');
    expect(request.headers['X-CSRFToken'], 'abc');
    expect(request.headers['X-API-Authorization'], 'Bearer token');
    expect(request.data, {
      'chip': 'wildcard',
      'entry': 42,
      'event': 7,
      'transfers': [
        {
          'element_in': 1,
          'element_out': 2,
          'purchase_price': 55,
          'selling_price': 60,
        },
        {
          'element_in': 3,
          'element_out': 4,
          'purchase_price': 70,
          'selling_price': 65,
        },
      ],
    });
  });

  test('saves the lineup with a triple captain chip', () async {
    await client.saveMyTeam(
      session: _session,
      entryId: 42,
      chip: FplChipName.tripleCaptain,
      picks: const [
        TeamPick(
          elementId: 9,
          position: 1,
          multiplier: 3,
          isCaptain: true,
          isViceCaptain: false,
          elementType: 4,
        ),
      ],
    );

    final request = requests.single;
    expect(request.path, '/my-team/42/');
    expect(request.data, {
      'chip': '3xc',
      'picks': [
        {
          'element': 9,
          'position': 1,
          'is_captain': true,
          'is_vice_captain': false,
        },
      ],
    });
  });

  test('refuses to write without session cookies', () async {
    await expectLater(
      client.makeTransfers(
        session: const OfficialSession(accessToken: 'token'),
        entryId: 42,
        gameweekId: 7,
        transfers: const [
          TransferRequest(
            elementIn: 1,
            elementOut: 2,
            purchasePrice: 55,
            sellingPrice: 60,
          ),
        ],
      ),
      throwsA(
        isA<FplApiException>().having(
          (e) => e.kind,
          'kind',
          FplApiErrorKind.authentication,
        ),
      ),
    );
    expect(requests, isEmpty);
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.requests);

  final List<RequestOptions> requests;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
