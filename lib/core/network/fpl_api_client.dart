import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/fpl_models.dart';
import '../security/session_store.dart';
import 'api_constance.dart';
import 'dio_helper.dart';

const officialFplBaseUrl = ApiConstance.baseUrl;

final fplApiClientProvider = Provider<FplApiClient>((ref) {
  final client = FplApiClient();
  ref.onDispose(client.dispose);
  return client;
});

final bootstrapProvider = FutureProvider<FplBootstrap>((ref) {
  return ref.read(fplApiClientProvider).getBootstrap();
});

final fixturesProvider = FutureProvider.autoDispose
    .family<List<FplFixture>, int>((ref, gameweekId) {
      return ref.read(fplApiClientProvider).getFixtures(gameweekId: gameweekId);
    });

final allFixturesProvider = FutureProvider.autoDispose<List<FplFixture>>((ref) {
  return ref.read(fplApiClientProvider).getFixtures();
});

final gameweekPointsProvider = FutureProvider.autoDispose
    .family<Map<int, int>, int>((ref, gameweekId) {
      return ref.read(fplApiClientProvider).getGameweekPoints(gameweekId);
    });

final entryHistoryPointsProvider = FutureProvider.autoDispose
    .family<Map<int, int>, int>((ref, entryId) {
      return ref.read(fplApiClientProvider).getEntryHistoryPoints(entryId);
    });

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
      Error.throwWithStackTrace(
        FplApiException(
          kind: kind,
          statusCode: status,
          message: error.message ?? 'The official API request failed.',
        ),
        stackTrace,
      );
    }
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
