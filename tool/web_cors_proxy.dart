// Local CORS proxy for running the web build against the FPL API and images.
//
//   dart run tool/web_cors_proxy.dart [port]
//
// Mirrors the routes of the production site Worker (site/src/worker.js) and
// adds the CORS headers the official servers leave out.
import 'dart:io';

/// Local path prefix -> upstream origin plus path prefix.
const _routes = {
  '/api/': 'https://fantasy.premierleague.com/api/',
  '/fpl/dist/img/': 'https://fantasy.premierleague.com/dist/img/',
  '/pl-resources/premierleague/badges/':
      'https://resources.premierleague.com/premierleague/badges/',
};

Future<void> main(List<String> args) async {
  final port = args.isEmpty ? 8787 : int.parse(args.first);
  final client = HttpClient();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('FPL CORS proxy on http://localhost:$port');

  await for (final request in server) {
    final response = request.response;
    final origin = request.headers.value('origin') ?? '*';
    response.headers
      ..set('Access-Control-Allow-Origin', origin)
      ..set('Access-Control-Allow-Credentials', 'true')
      ..set(
        'Access-Control-Allow-Methods',
        'GET, POST, PUT, PATCH, DELETE, OPTIONS',
      )
      ..set(
        'Access-Control-Allow-Headers',
        request.headers.value('access-control-request-headers') ?? '*',
      )
      ..set('Vary', 'Origin');

    if (request.method == 'OPTIONS') {
      response.statusCode = HttpStatus.noContent;
      await response.close();
      continue;
    }
    final path = request.uri.path;
    final prefix = _routes.keys
        .where((prefix) => path.startsWith(prefix))
        .firstOrNull;
    if (prefix == null) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      continue;
    }

    try {
      final upstream = await client.openUrl(
        request.method,
        Uri.parse(
          _routes[prefix]! +
              path.substring(prefix.length) +
              (request.uri.hasQuery ? '?${request.uri.query}' : ''),
        ),
      );
      for (final name in const [
        'accept',
        'content-type',
        'authorization',
        'x-api-authorization',
      ]) {
        final value = request.headers.value(name);
        if (value != null) upstream.headers.set(name, value);
      }
      await upstream.addStream(request);
      final reply = await upstream.close();
      response.statusCode = reply.statusCode;
      final contentType = reply.headers.contentType;
      if (contentType != null) response.headers.contentType = contentType;
      await response.addStream(reply);
    } catch (error) {
      response.statusCode = HttpStatus.badGateway;
      response.write('Proxy error: $error');
    }
    await response.close();
  }
}
