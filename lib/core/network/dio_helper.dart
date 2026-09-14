import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import 'api_constance.dart';

class DioHelper {
  DioHelper._();

  static Dio? dio;

  static void init({BaseOptions? options}) {
    dio = createDio(
      options ??
          BaseOptions(
            baseUrl: ApiConstance.baseUrl,
            receiveDataWhenStatusError: true,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          ),
    );
  }

  static Dio get instance => dio ??= createDio(
    BaseOptions(
      baseUrl: ApiConstance.baseUrl,
      receiveDataWhenStatusError: true,
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  static Dio createDio(BaseOptions options) {
    final client = Dio(options);
    if (kDebugMode) {
      client.interceptors.add(
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseBody: true,
          responseHeader: false,
          error: true,
          compact: true,
          maxWidth: 89,
          enabled: true,
          logPrint: (object) => debugPrint('$object'),
          filter: (options, args) {
            if (options.path.contains('/posts')) return false;
            if (_isSensitivePath(options.path)) return false;
            if (args.isResponse && _isLargeEndpoint(options.path)) {
              return false;
            }
            return !args.isResponse || !args.hasUint8ListData;
          },
        ),
      );
      client.interceptors.add(
        InterceptorsWrapper(
          onResponse: (response, handler) {
            if (_isLargeEndpoint(response.requestOptions.path)) {
              debugPrint(
                '[Dio] ${response.requestOptions.method} '
                '${response.requestOptions.uri} → ${response.statusCode}',
              );
            }
            handler.next(response);
          },
          onError: (error, handler) {
            if (_isLargeEndpoint(error.requestOptions.path)) {
              debugPrint(
                '[Dio] ${error.requestOptions.method} '
                '${error.requestOptions.uri} → '
                '${error.response?.statusCode ?? error.type}',
              );
            }
            handler.next(error);
          },
        ),
      );
    }
    return client;
  }

  static Future<Response<T>> getData<T>({
    required String endPoint,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
  }) {
    return instance.get<T>(
      endPoint,
      queryParameters: query,
      options: _requestOptions(headers),
    );
  }

  static Future<Response<T>> patchData<T>({
    required String endPoint,
    required dynamic data,
    Map<String, dynamic>? headers,
  }) {
    return instance.patch<T>(
      endPoint,
      data: data,
      options: _requestOptions(headers),
    );
  }

  static Future<Response<T>> postData<T>({
    required String endPoint,
    dynamic data,
    Map<String, dynamic>? headers,
  }) {
    return instance.post<T>(
      endPoint,
      data: data,
      options: _requestOptions(headers),
    );
  }

  static Future<Response<T>> putData<T>({
    required String endPoint,
    dynamic data,
    Map<String, dynamic>? headers,
  }) {
    return instance.put<T>(
      endPoint,
      data: data,
      options: _requestOptions(headers),
    );
  }

  static Future<Response<T>> deleteData<T>({
    required String endPoint,
    dynamic data,
    Map<String, dynamic>? headers,
  }) {
    return instance.delete<T>(
      endPoint,
      data: data,
      options: _requestOptions(headers),
    );
  }

  static Options? _requestOptions(Map<String, dynamic>? headers) {
    return headers == null ? null : Options(headers: headers);
  }

  static bool _isSensitivePath(String path) {
    return path.contains('/token') ||
        path.contains('/api/me/') ||
        path.contains('/my-team/');
  }

  static bool _isLargeEndpoint(String path) {
    final normalizedPath = path.split('?').first;
    return normalizedPath.endsWith('/bootstrap-static/') ||
        RegExp(r'/event/\d+/live/?$').hasMatch(normalizedPath);
  }
}
