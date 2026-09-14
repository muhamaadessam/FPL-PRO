import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../../../core/network/fpl_api_client.dart';
import '../../../core/network/dio_helper.dart';
import '../../../core/security/session_store.dart';

const officialOidcAuthority = 'https://account.premierleague.com/as';
const officialOidcClientId = String.fromEnvironment(
  'FPL_OIDC_CLIENT_ID',
  defaultValue: 'bfcbaf69-aade-4c1b-8f00-c1cb8a193030',
);
const officialOidcCallbackScheme = 'fantasypl';
const officialOidcRedirectUri = String.fromEnvironment(
  'FPL_OIDC_REDIRECT_URI',
  defaultValue: '',
);
const officialOidcWebRedirectUri = 'https://fantasy.premierleague.com/';
const officialUserAgent = 'FantasyPL/1.0 (Flutter)';

class OfficialAuthClient {
  OfficialAuthClient(this._sessionStore, {Dio? dio})
    : _dio =
          dio ??
          DioHelper.createDio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 15),
              headers: const {
                'Accept': 'application/json',
                'User-Agent': officialUserAgent,
              },
            ),
          );

  final SessionStore _sessionStore;
  final Dio _dio;

  Future<OfficialSession?> restoreSession() async {
    final stored = await _sessionStore.read();
    if (stored == null || !stored.isExpired) return stored;
    if (stored.refreshToken == null) {
      await _sessionStore.clear();
      return null;
    }

    try {
      final refreshed = await _refresh(stored.refreshToken!);
      final session = refreshed.copyWith(entryId: stored.entryId);
      await _sessionStore.write(session);
      return session;
    } on Object {
      await _sessionStore.clear();
      return null;
    }
  }

  Future<OfficialSession> startOfficialLogin({
    Future<String> Function(Uri authorizationUri)? authenticate,
  }) async {
    final redirectUri = authenticate == null
        ? officialOidcRedirectUri
        : officialOidcWebRedirectUri;
    if (redirectUri.isEmpty) {
      throw const OfficialAuthException(
        OfficialAuthError.configurationRequired,
      );
    }

    final state = _randomUrlSafe(32);
    final verifier = _randomUrlSafe(64);
    final authorizeUri = Uri.parse('$officialOidcAuthority/authorize').replace(
      queryParameters: {
        'client_id': officialOidcClientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': 'openid profile email offline_access',
        'code_challenge': pkceCodeChallenge(verifier),
        'code_challenge_method': 'S256',
        'state': state,
      },
    );

    try {
      final callback = authenticate != null
          ? await authenticate(authorizeUri)
          : await FlutterWebAuth2.authenticate(
              url: authorizeUri.toString(),
              callbackUrlScheme: officialOidcCallbackScheme,
            );
      final callbackUri = Uri.tryParse(callback);
      if (callbackUri == null ||
          callbackUri.queryParameters['state'] != state) {
        throw const OfficialAuthException(OfficialAuthError.invalidCallback);
      }
      if (callbackUri.queryParameters['error'] != null) {
        throw const OfficialAuthException(OfficialAuthError.providerRejected);
      }

      final code = callbackUri.queryParameters['code'];
      if (code == null || code.isEmpty) {
        throw const OfficialAuthException(OfficialAuthError.invalidCallback);
      }

      final tokenSession = await _exchangeCode(
        code: code,
        verifier: verifier,
        redirectUri: redirectUri,
      );
      final entryId = await _resolveEntryId(tokenSession);
      if (entryId == null) {
        throw const OfficialAuthException(OfficialAuthError.entryIdMissing);
      }

      final session = tokenSession.copyWith(entryId: entryId);
      await _sessionStore.write(session);
      return session;
    } on OfficialAuthException {
      rethrow;
    } on PlatformException catch (error, stackTrace) {
      final exception = error.code == 'CANCELED'
          ? const OfficialAuthException(OfficialAuthError.cancelled)
          : const OfficialAuthException(OfficialAuthError.network);
      Error.throwWithStackTrace(exception, stackTrace);
    } on DioException catch (error, stackTrace) {
      final status = error.response?.statusCode;
      final exception = status == 401 || status == 403
          ? const OfficialAuthException(OfficialAuthError.sessionMissing)
          : status != null && status >= 400
          ? const OfficialAuthException(OfficialAuthError.tokenExchangeFailed)
          : const OfficialAuthException(OfficialAuthError.network);
      Error.throwWithStackTrace(exception, stackTrace);
    }
  }

  Future<OfficialSession> _exchangeCode({
    required String code,
    required String verifier,
    required String redirectUri,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        '$officialOidcAuthority/token',
        data: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUri,
          'client_id': officialOidcClientId,
          'code_verifier': verifier,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      return _sessionFromTokenResponse(response.data);
    } on DioException catch (_, stackTrace) {
      Error.throwWithStackTrace(
        const OfficialAuthException(OfficialAuthError.tokenExchangeFailed),
        stackTrace,
      );
    }
  }

  Future<OfficialSession> _refresh(String refreshToken) async {
    try {
      final response = await _dio.post<dynamic>(
        '$officialOidcAuthority/token',
        data: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'client_id': officialOidcClientId,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      return _sessionFromTokenResponse(response.data);
    } on DioException catch (_, stackTrace) {
      Error.throwWithStackTrace(
        const OfficialAuthException(OfficialAuthError.sessionMissing),
        stackTrace,
      );
    }
  }

  OfficialSession _sessionFromTokenResponse(dynamic data) {
    if (data is! Map<String, dynamic>) {
      throw const OfficialAuthException(OfficialAuthError.invalidResponse);
    }
    final accessToken = data['access_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw const OfficialAuthException(OfficialAuthError.sessionMissing);
    }
    final expiresIn = int.tryParse('${data['expires_in'] ?? ''}') ?? 3600;
    return OfficialSession(
      accessToken: accessToken,
      refreshToken: data['refresh_token'] as String?,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }

  Future<int?> _resolveEntryId(OfficialSession session) async {
    final response = await _dio.get<dynamic>(
      '$officialFplBaseUrl/me/',
      options: Options(
        headers: {
          ...session.requestHeaders,
          'User-Agent': officialUserAgent,
          'Accept': 'application/json',
        },
      ),
    );
    return findEntryId(response.data);
  }

  Future<void> logout() async {
    await _sessionStore.clear();
  }
}

String pkceCodeChallenge(String verifier) {
  final digest = sha256.convert(utf8.encode(verifier));
  return base64UrlEncode(digest.bytes).replaceAll('=', '');
}

String _randomUrlSafe(int byteCount) {
  final random = Random.secure();
  final bytes = List<int>.generate(byteCount, (_) => random.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}

int? findEntryId(dynamic value, {bool includeTopLevelId = true}) {
  if (value is Map) {
    for (final key in ['entry_id', 'entryId']) {
      final id = _asInt(value[key]);
      if (id != null) return id;
    }
    final entry = value['entry'];
    final entryId = entry is Map ? _asInt(entry['id']) : _asInt(entry);
    if (entryId != null) return entryId;
    if (includeTopLevelId) {
      final topLevelId = _asInt(value['id']);
      if (topLevelId != null) return topLevelId;
    }
    for (final child in value.values) {
      final id = findEntryId(child, includeTopLevelId: false);
      if (id != null) return id;
    }
  } else if (value is Iterable) {
    for (final child in value) {
      final id = findEntryId(child, includeTopLevelId: false);
      if (id != null) return id;
    }
  }
  return null;
}

int? _asInt(dynamic value) => value is int ? value : int.tryParse('$value');

enum OfficialAuthError {
  configurationRequired,
  cancelled,
  invalidCallback,
  providerRejected,
  tokenExchangeFailed,
  invalidResponse,
  entryIdMissing,
  sessionMissing,
  network,
  invalidCredentials,
  credentialsRequired,
  rateLimited,
}

class OfficialAuthException implements Exception {
  const OfficialAuthException(this.error, [this.message]);

  final OfficialAuthError error;
  final String? message;

  @override
  String toString() => message != null
      ? 'OfficialAuthException($error: $message)'
      : 'OfficialAuthException($error)';
}
