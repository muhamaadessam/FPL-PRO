import 'package:dio/dio.dart';

import '../../../../core/network/api_constance.dart';
import '../../../../core/network/dio_helper.dart';
import '../../../auth/domain/entities/official_session.dart';
import '../models/fpl_models.dart';
import '../../../team/data/models/team_models.dart';

const officialFplBaseUrl = ApiConstance.baseUrl;

class FplApiClient {
  FplApiClient({Dio? dio})
    : _dio = dio ?? DioHelper.instance,
      _ownsDio = dio != null;

  final Dio _dio;
  final bool _ownsDio;

  Future<FplBootstrap> getBootstrap() async {
    final json = await _getMap('/bootstrap-static/');
    return FplBootstrap.fromJson(json);
  }

  Future<List<FplFixture>> getFixtures({int? gameweekId}) async {
    final data = await _getList(
      '/fixtures/',
      queryParameters: {'event': ?gameweekId},
    );
    return data
        .whereType<Map<String, dynamic>>()
        .map(FplFixture.fromJson)
        .toList(growable: false);
  }

  Future<MyTeam> getMyTeam({
    required int entryId,
    required int gameweekId,
    required OfficialSession session,
  }) async {
    if (session.requestHeaders.isEmpty) {
      throw const FplApiException(
        kind: FplApiErrorKind.authentication,
        message: 'The session has no approved request credentials.',
      );
    }
    final json = await _getMap(
      '/my-team/$entryId/',
      queryParameters: {'event': gameweekId},
      session: session,
    );
    return MyTeam.fromJson(json);
  }

  Future<MyTeam> getPublicTeam({
    required int entryId,
    required int gameweekId,
  }) async {
    final json = await _getMap('/entry/$entryId/event/$gameweekId/picks/');
    return MyTeam.fromJson(json);
  }

  Future<Map<int, int>> getGameweekPoints(int gameweekId) async {
    final json = await _getMap('/event/$gameweekId/live/');
    return parseGameweekPoints(json);
  }

  Future<Map<int, int>> getEntryHistoryPoints(int entryId) async {
    final json = await _getMap('/entry/$entryId/history/');
    return parseEntryHistoryPoints(json);
  }

  Future<FplPlayerSummary> getPlayerSummary(int playerId) async {
    final json = await _getMap('/element-summary/$playerId/');
    return FplPlayerSummary.fromJson(json);
  }

  Future<void> makeTransfer({
    required OfficialSession session,
    required int entryId,
    required int gameweekId,
    required int elementIn,
    required int elementOut,
    required int purchasePrice,
    required int sellingPrice,
  }) async {
    await _post(
      '/transfers/',
      session: session,
      data: {
        'chip': null,
        'entry': entryId,
        'event': gameweekId,
        'transfers': [
          {
            'element_in': elementIn,
            'element_out': elementOut,
            'purchase_price': purchasePrice,
            'selling_price': sellingPrice,
          },
        ],
      },
    );
  }

  Future<void> saveMyTeam({
    required OfficialSession session,
    required int entryId,
    required String? chip,
    required List<TeamPick> picks,
  }) async {
    await _post(
      '/my-team/$entryId/',
      session: session,
      data: {
        'chip': chip,
        'picks': [
          for (final pick in picks)
            {
              'element': pick.elementId,
              'position': pick.position,
              'is_captain': pick.isCaptain,
              'is_vice_captain': pick.isViceCaptain,
            },
        ],
      },
    );
  }

  Future<void> _post(
    String path, {
    required OfficialSession session,
    required Map<String, dynamic> data,
  }) async {
    final csrfToken = session.csrfToken;
    final cookieHeader = session.cookieHeader;
    if (session.requestHeaders.isEmpty ||
        csrfToken == null ||
        csrfToken.isEmpty ||
        cookieHeader == null ||
        cookieHeader.isEmpty) {
      throw const FplApiException(
        kind: FplApiErrorKind.authentication,
        message: 'The session has no approved write credentials.',
      );
    }
    try {
      await _dio.post<dynamic>(
        path,
        data: data,
        options: Options(
          headers: {
            ...session.requestHeaders,
            'X-API-Language': 'en',
            'X-CSRFToken': csrfToken,
            'Cookie': cookieHeader,
          },
        ),
      );
    } on DioException catch (error, stackTrace) {
      Error.throwWithStackTrace(_toApiException(error), stackTrace);
    }
  }

  Future<Map<String, dynamic>> _getMap(
    String path, {
    Map<String, dynamic>? queryParameters,
    OfficialSession? session,
  }) async {
    final data = await _get(
      path,
      queryParameters: queryParameters,
      session: session,
    );
    if (data is! Map<String, dynamic>) {
      throw const FplApiException(
        kind: FplApiErrorKind.invalidResponse,
        message: 'Expected a JSON object.',
      );
    }
    return data;
  }

  Future<List<dynamic>> _getList(
    String path, {
    Map<String, dynamic>? queryParameters,
    OfficialSession? session,
  }) async {
    final data = await _get(
      path,
      queryParameters: queryParameters,
      session: session,
    );
    if (data is! List<dynamic>) {
      throw const FplApiException(
        kind: FplApiErrorKind.invalidResponse,
        message: 'Expected a JSON array.',
      );
    }
    return data;
  }

  Future<dynamic> _get(
    String path, {
    Map<String, dynamic>? queryParameters,
    OfficialSession? session,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
        options: Options(headers: session?.requestHeaders),
      );
      return response.data;
    } on DioException catch (error, stackTrace) {
      Error.throwWithStackTrace(_toApiException(error), stackTrace);
    }
  }

  FplApiException _toApiException(DioException error) {
    final status = error.response?.statusCode;
    final kind = switch (status) {
      401 || 403 => FplApiErrorKind.authentication,
      429 => FplApiErrorKind.rateLimited,
      _
          when error.type == DioExceptionType.connectionError ||
              error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout =>
        FplApiErrorKind.network,
      _ => FplApiErrorKind.unknown,
    };
    return FplApiException(
      kind: kind,
      statusCode: status,
      message: error.message ?? 'The official API request failed.',
    );
  }

  void dispose() {
    if (_ownsDio) _dio.close(force: true);
  }
}

int? _intValue(dynamic value) => value is int ? value : int.tryParse('$value');

Map<int, int> parseGameweekPoints(Map<String, dynamic> json) {
  final elements = json['elements'];
  if (elements is! List) return const {};
  return {
    for (final element in elements.whereType<Map>())
      if (_intValue(element['id']) != null && element['stats'] is Map)
        _intValue(element['id'])!:
            _intValue((element['stats'] as Map)['total_points']) ?? 0,
  };
}

Map<int, int> parseEntryHistoryPoints(Map<String, dynamic> json) {
  final current = json['current'];
  if (current is! List) return const {};
  return {
    for (final event in current.whereType<Map>())
      if (_intValue(event['event']) != null && event['points'] != null)
        _intValue(event['event'])!: _intValue(event['points']) ?? 0,
  };
}

enum FplApiErrorKind {
  authentication,
  network,
  rateLimited,
  invalidResponse,
  unknown,
}

class FplApiException implements Exception {
  const FplApiException({
    required this.kind,
    required this.message,
    this.statusCode,
  });

  final FplApiErrorKind kind;
  final int? statusCode;
  final String message;

  @override
  String toString() => 'FplApiException($statusCode, $kind): $message';
}
