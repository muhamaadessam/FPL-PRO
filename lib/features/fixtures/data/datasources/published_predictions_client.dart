import 'package:dio/dio.dart';

import '../../../../core/network/api_constance.dart';

/// Reads the predictions the scheduled job publishes on the site. Every
/// failure returns null, because the app can always compute them itself.
class PublishedPredictionsClient {
  PublishedPredictionsClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConstance.publishedPredictionsUrl,
              connectTimeout: const Duration(seconds: 4),
              receiveTimeout: const Duration(seconds: 6),
              responseType: ResponseType.json,
            ),
          );

  final Dio _dio;

  Future<Object?> fixturePredictions() => _get('/fixture-predictions.json');

  Future<Object?> playerProjections() => _get('/player-projections.json');

  Future<Object?> _get(String path) async {
    try {
      return (await _dio.get<Object?>(path)).data;
    } on Object {
      return null;
    }
  }
}
