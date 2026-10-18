// Precomputes match predictions and general player projections from the FPL
// API and writes them as JSON for the app (see PublishedFixturePredictions
// and PublishedPlayerProjections). Run on a schedule by
// .github/workflows/deploy_site.yml, which serves the files from the site at
// /data/v1/.
//
//   dart run bin/publish_predictions.dart --out build/data
//   dart run bin/publish_predictions.dart --input ../../data/tips --out /tmp/x
//   dart run bin/publish_predictions.dart --out build/data --news-snapshot /tmp/news.json
//
// --input reads bootstrap-static.json, fixtures.json and any
// event-{id}-live.json from a folder instead of the network.
//
// --news-snapshot also writes every player's FPL availability news as it
// stands now, which the deploy keeps on the fpl-news-snapshots branch so
// later Gameweeks can be scored against what FPL said before kickoff.
import 'dart:convert';
import 'dart:io';

import 'package:fpl_engine/fpl_engine.dart';

const _fplApi = 'https://fantasy.premierleague.com/api';

/// Live minutes from this many finished Gameweeks, as the app loads them.
const _recentGameweeks = 5;

Future<void> main(List<String> args) async {
  final out = _option(args, '--out') ?? 'build/data';
  final input = _option(args, '--input');
  final newsSnapshot = _option(args, '--news-snapshot');
  final source = input == null ? _NetworkSource() : _FolderSource(input);
  try {
    await _publish(source, Directory(out), newsSnapshot: newsSnapshot);
  } finally {
    source.close();
  }
}

Future<void> _publish(
  _Source source,
  Directory out, {
  String? newsSnapshot,
}) async {
  final bootstrapJson =
      await source.json('bootstrap-static/') as Map<String, dynamic>;
  final bootstrap = FplBootstrap.fromJson(bootstrapJson);
  final fixtures = (await source.json('fixtures/') as List)
      .map((item) => FplFixture.fromJson(item as Map<String, dynamic>))
      .toList(growable: false);
  final finished =
      bootstrap.gameweeks
          .where((gameweek) => gameweek.finished)
          .map((gameweek) => gameweek.id)
          .toList()
        ..sort();
  final recentMinutes = <int, Map<int, int>>{};
  for (final id in finished.reversed.take(_recentGameweeks)) {
    final live = await source.optionalJson('event/$id/live/');
    final minutes = live is Map ? _minutes(live) : const <int, int>{};
    if (minutes.isNotEmpty) recentMinutes[id] = minutes;
  }

  final generatedAt = DateTime.now().toUtc();
  final currentGameweekId = bootstrap.currentGameweekId;
  final gameweekId = projectionGameweekId(bootstrap);
  final predictions = PublishedFixturePredictions(
    generatedAt: generatedAt,
    fromGameweekId: currentGameweekId,
    predictions: const FixturePredictionEngine().predictNextGameweeks(
      fixtures: fixtures,
      teams: bootstrap.teams,
      players: bootstrap.players,
      fromGameweekId: currentGameweekId,
    ),
  );
  final projections = PublishedPlayerProjections(
    generatedAt: generatedAt,
    gameweekId: gameweekId,
    projections: const RecommendationEngine().buildPlayerProjections(
      bootstrap: bootstrap,
      fixtures: fixtures,
      gameweekId: gameweekId,
      recentGameweekMinutes: recentMinutes,
    ),
  );
  _validate(bootstrap, predictions, projections);

  final folder = Directory('${out.path}/v$publishedSchemaVersion')
    ..createSync(recursive: true);
  File(
    '${folder.path}/fixture-predictions.json',
  ).writeAsStringSync(jsonEncode(predictions.toJson()));
  File(
    '${folder.path}/player-projections.json',
  ).writeAsStringSync(jsonEncode(projections.toJson()));
  if (newsSnapshot != null) {
    _writeNewsSnapshot(
      File(newsSnapshot),
      bootstrapJson,
      bootstrap,
      generatedAt,
    );
  }
  stdout.writeln(
    'Wrote ${predictions.predictions.length} match predictions from '
    'GW$currentGameweekId and ${projections.projections.length} player '
    'projections for GW$gameweekId (live minutes from '
    '${recentMinutes.length} Gameweeks) to ${folder.path}',
  );
}

/// Every player's FPL status and news, as raw as the API gives them.
void _writeNewsSnapshot(
  File file,
  Map<String, dynamic> bootstrapJson,
  FplBootstrap bootstrap,
  DateTime takenAt,
) {
  final players = (bootstrapJson['elements'] as List? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(
        (player) => {
          'id': player['id'],
          'webName': player['web_name'],
          'team': player['team'],
          'status': player['status'],
          'news': player['news'],
          'newsAdded': player['news_added'],
          'chanceOfPlayingThisRound': player['chance_of_playing_this_round'],
          'chanceOfPlayingNextRound': player['chance_of_playing_next_round'],
        },
      )
      .toList(growable: false);
  if (players.isEmpty) throw StateError('Bootstrap has no players.');
  file.parent.createSync(recursive: true);
  // One player per line, so consecutive snapshots diff to a few lines.
  final header = jsonEncode({
    'schemaVersion': 1,
    'takenAt': takenAt.toIso8601String(),
    'currentGameweekId': bootstrap.currentGameweekId,
    'nextGameweekId': projectionGameweekId(bootstrap),
  });
  file.writeAsStringSync(
    '${header.substring(0, header.length - 1)},"players":[\n'
    '${players.map(jsonEncode).join(',\n')}\n]}\n',
  );
  stdout.writeln('Wrote news for ${players.length} players to ${file.path}');
}

/// Refuses to publish anything the app would show as nonsense.
void _validate(
  FplBootstrap bootstrap,
  PublishedFixturePredictions predictions,
  PublishedPlayerProjections projections,
) {
  if (bootstrap.players.isEmpty || bootstrap.teams.isEmpty) {
    throw StateError('Bootstrap has no players or teams.');
  }
  if (projections.projections.length != bootstrap.players.length ||
      projections.projections.any(
        (p) =>
            !p.nextPoints.isFinite ||
            !p.horizonPoints.isFinite ||
            !p.availability.isFinite,
      )) {
    throw StateError('Player projections are incomplete or not finite.');
  }
  for (final p in predictions.predictions.values) {
    final total = p.homeWinChance + p.drawChance + p.awayWinChance;
    if (!p.homeExpectedGoals.isFinite ||
        !p.awayExpectedGoals.isFinite ||
        total < 98 ||
        total > 102) {
      throw StateError('A match prediction is not a valid distribution.');
    }
  }
}

Map<int, int> _minutes(Map<dynamic, dynamic> live) {
  final elements = live['elements'];
  if (elements is! List) return const {};
  return {
    for (final element in elements.whereType<Map>())
      if (element['id'] is int && element['stats'] is Map)
        element['id'] as int: (element['stats'] as Map)['minutes'] as int? ?? 0,
  };
}

String? _option(List<String> args, String name) {
  final index = args.indexOf(name);
  return index >= 0 && index + 1 < args.length ? args[index + 1] : null;
}

abstract class _Source {
  /// [path] is relative to the FPL API root, e.g. `fixtures/`.
  Future<Object?> json(String path);

  Future<Object?> optionalJson(String path) async {
    try {
      return await json(path);
    } on Object catch (error) {
      stderr.writeln('Skipping $path: $error');
      return null;
    }
  }

  void close() {}
}

class _NetworkSource extends _Source {
  final _client = HttpClient()
    ..userAgent = 'fpl-pro-predictions (+https://fpl-pro.muhammadessam.me)';

  @override
  Future<Object?> json(String path) async {
    for (var attempt = 1; ; attempt++) {
      try {
        final request = await _client.getUrl(Uri.parse('$_fplApi/$path'));
        final response = await request.close().timeout(
          const Duration(seconds: 30),
        );
        final body = await response.transform(utf8.decoder).join();
        if (response.statusCode != 200) {
          throw HttpException('HTTP ${response.statusCode} for $path');
        }
        return jsonDecode(body);
      } on Object {
        if (attempt == 3) rethrow;
        await Future<void>.delayed(Duration(seconds: 5 * attempt));
      }
    }
  }

  @override
  void close() => _client.close(force: true);
}

class _FolderSource extends _Source {
  _FolderSource(this.root);

  final String root;

  @override
  Future<Object?> json(String path) async {
    final name = switch (path) {
      'bootstrap-static/' => 'bootstrap-static.json',
      'fixtures/' => 'fixtures.json',
      _ => '${path.substring(0, path.length - 1).replaceAll('/', '-')}.json',
    };
    return jsonDecode(await File('$root/$name').readAsString());
  }
}
