import 'package:flutter/foundation.dart';

class ApiConstance {
  const ApiConstance._();

  static const _fantasyOrigin = 'https://fantasy.premierleague.com';
  static const _resourcesOrigin = 'https://resources.premierleague.com';

  /// FPL sends no CORS headers for its API or images, so web builds load both
  /// through a same-origin proxy: the site Worker in production
  /// (`site/src/worker.js`) or `tool/web_cors_proxy.dart` locally. Override
  /// with `--dart-define=WEB_PROXY_ORIGIN=...` when deploying.
  static const _webProxyOrigin = String.fromEnvironment(
    'WEB_PROXY_ORIGIN',
    defaultValue: 'http://localhost:8787',
  );

  static const baseUrl = kIsWeb
      ? '$_webProxyOrigin/api'
      : '$_fantasyOrigin/api';

  static const shirtsBaseUrl = kIsWeb
      ? '$_webProxyOrigin/fpl/dist/img/shirts/standard'
      : '$_fantasyOrigin/dist/img/shirts/standard';

  static const badgesBaseUrl = kIsWeb
      ? '$_webProxyOrigin/pl-resources/premierleague/badges/70'
      : '$_resourcesOrigin/premierleague/badges/70';
}
