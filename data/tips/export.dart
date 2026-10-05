import 'dart:convert';
import 'dart:io';

import 'package:fantasy_pl/features/fixtures/data/models/fpl_models.dart';
import 'package:fantasy_pl/features/team/data/models/team_models.dart';
import 'package:fantasy_pl/features/recommendations/domain/usecases/recommendation_engine.dart';

void main() {
  final root = File.fromUri(Platform.script).parent;
  dynamic read(String name) =>
      jsonDecode(File('${root.path}/$name').readAsStringSync());
  final raw = read('bootstrap-static.json') as Map<String, dynamic>;
  final bootstrap = FplBootstrap.fromJson(raw);
  final fixtures = (read('fixtures.json') as List)
      .map((item) => FplFixture.fromJson(item as Map<String, dynamic>))
      .toList();
  final team = MyTeam.fromJson(read('picks.json') as Map<String, dynamic>);
  final entry = read('entry.json') as Map<String, dynamic>;
  final summaries = read('player-summaries.json') as Map<String, dynamic>;
  final gameweek = bootstrap.gameweeks.firstWhere(
    (g) => g.isNext,
    orElse: () => bootstrap.gameweeks.firstWhere(
      (g) => g.id > bootstrap.currentGameweekId,
      orElse: () => bootstrap.gameweeks.last,
    ),
  );
  if (team.picks.length != 15 ||
      team.picks.map((p) => p.elementId).toSet().length != 15 ||
      team.picks.any((p) => !bootstrap.players.containsKey(p.elementId)) ||
      bootstrap.players.length != (raw['elements'] as List).length ||
      summaries.length != team.picks.length) {
    throw StateError('Incomplete or duplicate source records.');
  }
  const engine = RecommendationEngine();
  final projections = engine.buildPlayerProjections(
    bootstrap: bootstrap,
    fixtures: fixtures,
    gameweekId: gameweek.id,
  );
  final result = engine.build(
    bootstrap: bootstrap,
    fixtures: fixtures,
    team: team,
    gameweekId: gameweek.id,
    playerSummaries: {
      for (final item in summaries.entries)
        int.parse(item.key): FplPlayerSummary.fromJson(
          item.value as Map<String, dynamic>,
        ),
    },
  );
  if (projections.length != bootstrap.players.length ||
      projections.any(
        (p) => !p.nextPoints.isFinite || !p.horizonPoints.isFinite,
      ) ||
      result.squadAnalysis.players.length != 15) {
    throw StateError('Projection validation failed.');
  }
  Map<String, dynamic> row(PlayerProjection p) => {
    'player_id': p.player.id,
    'name': p.player.webName,
    'team': bootstrap.teams[p.player.teamId]!.shortName,
    'position_id': p.player.positionId,
    'price_m': p.player.nowCost == null ? null : p.player.nowCost! / 10,
    'season_points': p.player.totalPoints,
    'form': p.player.form,
    'points_per_game': p.player.pointsPerGame,
    'status': p.player.status,
    'news': p.player.news,
    'selected_by_percent': p.player.selectedByPercent,
    'next_points': p.nextPoints,
    'weighted_three_gameweek_points': p.horizonPoints,
    'availability': p.availability,
    'next_fixture_count': p.nextFixtureCount,
    'next_difficulties': p.nextDifficulties,
  };
  final players = projections.map(row).toList();
  final output = {
    'entry_id': entry['id'],
    'team_name': entry['name'],
    'source_capture_utc': {
      for (final name in [
        'bootstrap-static.json',
        'fixtures.json',
        'entry.json',
        'picks.json',
        'player-summaries.json',
      ])
        name: File(
          '${root.path}/$name',
        ).statSync().modified.toUtc().toIso8601String(),
    },
    'projection_gameweek': gameweek.id,
    'deadline_utc': gameweek.deadlineTime?.toUtc().toIso8601String(),
    'team_snapshot_gameweek': team.summary.gameweekId,
    'scope':
        'Public data reconstruction; not an export of the authenticated Tips screen.',
    'caveats': [
      'Squad and captain calculations assume the published squad is unchanged for the next gameweek.',
      'Current bank, selling prices, free transfers and available chips are not verified; transfer and chip advice is omitted.',
      'Projected points are app estimates, not actual scores or guarantees.',
      'Three-gameweek points are weighted with 1.0, 0.65 and 0.4, not a plain sum.',
      'Source capture timestamps do not establish when FPL last updated the underlying records.',
    ],
    'suggested_captain_from_published_starters': result.captain == null
        ? null
        : row(result.captain!),
    'suggested_vice_captain_from_published_starters': result.viceCaptain == null
        ? null
        : row(result.viceCaptain!),
    'squad_rating': result.squadAnalysis.rating,
    'expected_starting_points_with_published_captain':
        result.squadAnalysis.expectedStartingPoints,
    'expected_bench_points': result.squadAnalysis.expectedBenchPoints,
    'top_by_position': {
      for (final item in result.topByPosition.entries)
        '${item.key}': item.value.map(row).toList(),
    },
    'squad': [
      for (final p in result.squadAnalysis.players)
        {
          ...row(p.projection),
          'published_slot': p.pick.position,
          'published_captain': p.pick.isCaptain,
          'published_vice_captain': p.pick.isViceCaptain,
          'rating': p.rating,
          'expected_points': p.expectedPoints,
          'recent_points': p.recentPoints,
          'previous_season_points_per_90': p.previousSeasonPoints,
          'fixture_score': p.fixtureScore,
          'reliability': p.reliability,
          'trend': p.trend.name,
        },
    ],
    'players': players,
  };
  File(
    '${root.path}/tips-snapshot.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(output));
  String cell(dynamic value) =>
      '"${(value is List ? jsonEncode(value) : value?.toString() ?? '').replaceAll('"', '""')}"';
  final columns = players.first.keys.toList();
  File('${root.path}/players.csv').writeAsStringSync(
    [
      columns.map(cell).join(','),
      for (final player in players)
        columns.map((key) => cell(player[key])).join(','),
    ].join('\n'),
  );
  stdout.writeln(
    jsonEncode({
      'players': players.length,
      'squad': result.squadAnalysis.players.length,
      'gameweek': gameweek.id,
      'captain': result.captain?.player.webName,
      'vice_captain': result.viceCaptain?.player.webName,
      'squad_rating': result.squadAnalysis.rating,
    }),
  );
}
