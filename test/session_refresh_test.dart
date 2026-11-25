import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fantasy_pl/features/auth/data/datasources/official_auth_client.dart';
import 'package:fantasy_pl/features/auth/data/datasources/session_store.dart';
import 'package:fantasy_pl/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:fantasy_pl/features/auth/domain/entities/official_session.dart';
import 'package:fantasy_pl/features/auth/presentation/cubit/auth_cubit.dart';

void main() {
  final expired = OfficialSession(
    accessToken: 'old',
    refreshToken: 'refresh-1',
    expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
    entryId: 7,
    cookieHeader: 'cookie',
    csrfToken: 'csrf',
  );

  (AuthCubit, _Store, _Adapter) setUpCubit(_Adapter adapter) {
    final store = _Store()..stored = expired;
    final dio = Dio()..httpClientAdapter = adapter;
    final cubit = AuthCubit(
      AuthRepositoryImpl(OfficialAuthClient(store, dio: dio)),
      initialState: AuthAuthenticated(expired),
    );
    return (cubit, store, adapter);
  }

  test('renews an expired token once for concurrent loads', () async {
    final (cubit, store, adapter) = setUpCubit(
      _Adapter(200, {'access_token': 'new', 'expires_in': 3600}),
    );
    final sessions = await Future.wait([
      cubit.freshSession(),
      cubit.freshSession(),
    ]);

    expect(sessions.map((s) => s?.accessToken), ['new', 'new']);
    expect(adapter.calls, 1);
    expect(store.stored?.accessToken, 'new');
    expect(store.stored?.refreshToken, 'refresh-1');
    expect(store.stored?.entryId, 7);
    expect(store.stored?.csrfToken, 'csrf');
    expect(cubit.state.session?.accessToken, 'new');
  });

  test('signs out when the provider rejects the refresh token', () async {
    final (cubit, store, _) = setUpCubit(
      _Adapter(400, {'error': 'invalid_grant'}),
    );
    expect(await cubit.freshSession(), isNull);
    expect(cubit.state, isA<AuthUnauthenticated>());
    expect(store.stored, isNull);
  });

  test('stays signed in when the renewal fails on the network', () async {
    final (cubit, store, _) = setUpCubit(_Adapter(503, const {}));
    expect((await cubit.freshSession())?.entryId, 7);
    expect(cubit.state, isA<AuthAuthenticated>());
    expect(store.stored, isNotNull);

    await cubit.restoreSession();
    expect(cubit.state.session?.entryId, 7);
  });
}

class _Store extends SessionStore {
  OfficialSession? stored;

  @override
  Future<OfficialSession?> read() async => stored;

  @override
  Future<void> write(OfficialSession session) async => stored = session;

  @override
  Future<void> clear() async => stored = null;
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body);

  final int status;
  final Map<String, Object> body;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
