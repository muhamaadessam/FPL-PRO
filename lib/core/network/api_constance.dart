import 'package:flutter/foundation.dart';

class ApiConstance {
  const ApiConstance._();

  static const _officialBaseUrl = 'https://fantasy.premierleague.com/api';

  /// The FPL API sends no CORS headers, so web builds go through a proxy
  /// (see `tool/web_cors_proxy.dart`). Override with
  /// `--dart-define=API_BASE_URL=...` when deploying.
  static const baseUrl = kIsWeb
      ? String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'http://localhost:8787/api',
        )
      : _officialBaseUrl;
}
