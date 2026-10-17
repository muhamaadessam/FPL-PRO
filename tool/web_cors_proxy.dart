// Local CORS proxy for running the web build against the FPL API.
//
//   dart run tool/web_cors_proxy.dart [port]
//
// Forwards http://localhost:<port>/api/* to https://fantasy.premierleague.com/api/*
// and adds the CORS headers the official API leaves out.
import 'dart:io';

const _upstream = 'https://fantasy.premierleague.com';

Future<void> main(List<String> args) async {
  final port = args.isEmpty ? 8787 : int.parse(args.first);
  final client = HttpClient();
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln('FPL CORS proxy on http://localhost:$port/api');

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
    if (!request.uri.path.startsWith('/api/')) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      continue;
    }

    try {
      final upstream = await client.openUrl(
        request.method,
        Uri.parse('$_upstream${request.uri}'),
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
