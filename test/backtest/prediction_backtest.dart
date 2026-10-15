// Dev-only backtest of the match predictor (FixturePredictionEngine and
// TeamRatings). Not a unit test: `flutter test` ignores it because the file
// name has no `_test` suffix, and it needs the network on first run.
//
//   dart run test/backtest/prediction_backtest.dart            # report
//   dart run test/backtest/prediction_backtest.dart --tune     # + grid search
//   dart run test/backtest/prediction_backtest.dart --refresh  # re-download
//
// For every finished gameweek N it rebuilds TeamRatings from fixtures that
// kicked off before N, rebuilds each player's stats from their per-fixture
// history before N (so nothing from N or later leaks in), predicts N and
// scores the result. Seasons:
//
// * live: this season from the FPL API (bootstrap-static, fixtures and
//   element-summary/{id} for every player). Official team strengths are 0,
//   so the model runs without a prior, as it does in the app today.
// * 2025-26: last season from github.com/vaastav/Fantasy-Premier-League,
//   with the official strengths it published before GW1.
// * 2025-26-noprior: the same season with the strengths removed, to mirror
//   this season's missing ratings over 380 matches instead of ~60.
//
// Remaining leaks and gaps:
// * Availability (injuries, suspensions, chance of playing) has no history,
//   so every player counts as available and _absenceImpact cannot be tested.
// * FDR values are whatever the fixture feed shows now; FPL revises them
//   during the season, which can only flatter the FDR baseline.
// * Positions come from the current player list. Players who left the league
//   mid-season are missing from the live data, so a team's summed xG before N
//   can be slightly low.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:fantasy_pl/features/fixtures/data/models/fpl_models.dart';
import 'package:fantasy_pl/features/fixtures/domain/usecases/predict_fixtures.dart';
import 'package:fantasy_pl/features/fixtures/domain/usecases/team_ratings.dart';

const _cacheRoot = '.dart_tool/fpl_backtest';
const _fplApi = 'https://fantasy.premierleague.com/api';
const _vaastav =
    'https://raw.githubusercontent.com/vaastav/Fantasy-Premier-League/master/data';

Future<void> main(List<String> args) async {
  final refresh = args.contains('--refresh');
  final tune = args.contains('--tune');
  final live = await _loadLive(refresh: refresh);
  final last = await _loadVaastav('2025-26', refresh: refresh);
  final seasons = [live, last, last.withoutStrengths()];

  const defaults = FixturePredictionEngine();
  for (final season in seasons) {
    final fdr = _backtest(season, defaults, fdrOnly: true);
    final model = _backtest(season, defaults);
    stdout.writeln(
      '\n=== ${season.name}: ${model.matches} matches, '
      'GW${season.gameweeks.first}-${season.gameweeks.last} ===',
    );
    _printTable({'FDR only': fdr, 'Model': model});
    _printDelta('Model vs FDR', fdr, model);
    _printEarlyLate(season, fdr, model, 8);
    _printCleanSheetCalibration(model);
  }

  if (tune) _tune(seasons);
}

// ---------------------------------------------------------------------------
// Data

class _Appearance {
  const _Appearance({
    required this.element,
    required this.fixtureId,
    required this.teamId,
    required this.minutes,
    required this.starts,
    required this.goals,
    required this.assists,
    required this.expectedGoals,
    required this.expectedAssists,
    required this.expectedGoalsConceded,
    required this.value,
  });

  final int element;
  final int fixtureId;
  final int teamId;
  final int minutes;
  final int starts;
  final int goals;
  final int assists;
  final double expectedGoals;
  final double expectedAssists;
  final double expectedGoalsConceded;
  final int value;
}

class _Season {
  _Season({
    required this.name,
    required this.teams,
    required this.fixtures,
    required this.positions,
    required this.names,
    required this.appearances,
  }) {
    final byGameweek = <int, List<FplFixture>>{};
    for (final fixture in fixtures) {
      if (fixture.gameweekId == null) continue;
      byGameweek.putIfAbsent(fixture.gameweekId!, () => []).add(fixture);
    }
    gameweeks =
        byGameweek.entries
            .where((entry) => entry.value.every(_hasResult))
            .map((entry) => entry.key)
            .toList()
          ..sort();
    for (final row in appearances) {
      byFixture.putIfAbsent(row.fixtureId, () => []).add(row);
    }
  }

  final String name;
  final Map<int, FplTeam> teams;
  final List<FplFixture> fixtures;
  final Map<int, int> positions;
  final Map<int, String> names;
  final List<_Appearance> appearances;
  late final List<int> gameweeks;
  final Map<int, List<_Appearance>> byFixture = {};

  _Season withoutStrengths() => _Season(
    name: '$name-noprior',
    teams: {
      for (final team in teams.values)
        team.id: FplTeam(
          id: team.id,
          name: team.name,
          shortName: team.shortName,
          strengthAttackHome: 0,
          strengthAttackAway: 0,
          strengthDefenceHome: 0,
          strengthDefenceAway: 0,
        ),
    },
    fixtures: fixtures,
    positions: positions,
    names: names,
    appearances: appearances,
  );
}

bool _hasResult(FplFixture fixture) =>
    fixture.isFinished &&
    fixture.homeScore != null &&
    fixture.awayScore != null;

Future<String> _cached(String path, String url, {required bool refresh}) async {
  final file = File('$_cacheRoot/$path');
  if (!refresh && file.existsSync()) return file.readAsString();
  final client = HttpClient()..userAgent = 'fantasy_pl-backtest';
  try {
    for (var attempt = 1; ; attempt++) {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode == 200) {
        await file.parent.create(recursive: true);
        await file.writeAsString(body);
        return body;
      }
      if (attempt >= 4) {
        throw HttpException('${response.statusCode} for $url');
      }
      await Future<void>.delayed(Duration(seconds: attempt * 2));
    }
  } finally {
    client.close();
  }
}

Future<_Season> _loadLive({required bool refresh}) async {
  final bootstrap =
      jsonDecode(
            await _cached(
              'live/bootstrap.json',
              '$_fplApi/bootstrap-static/',
              refresh: refresh,
            ),
          )
          as Map<String, dynamic>;
  final teams = {
    for (final json
        in (bootstrap['teams'] as List).cast<Map<String, dynamic>>())
      json['id'] as int: FplTeam.fromJson(json),
  };
  final elements = (bootstrap['elements'] as List).cast<Map<String, dynamic>>();
  final fixtures =
      (jsonDecode(
                await _cached(
                  'live/fixtures.json',
                  '$_fplApi/fixtures/',
                  refresh: refresh,
                ),
              )
              as List)
          .cast<Map<String, dynamic>>()
          .map(FplFixture.fromJson)
          .toList(growable: false);
  final fixtureById = {for (final fixture in fixtures) fixture.id: fixture};

  stderr.write('live: loading ${elements.length} player histories');
  final appearances = <_Appearance>[];
  const batch = 8;
  for (var start = 0; start < elements.length; start += batch) {
    final chunk = elements.skip(start).take(batch);
    final bodies = await Future.wait(
      chunk.map(
        (element) => _cached(
          'live/elements/${element['id']}.json',
          '$_fplApi/element-summary/${element['id']}/',
          refresh: refresh,
        ),
      ),
    );
    for (final body in bodies) {
      final history = (jsonDecode(body) as Map<String, dynamic>)['history'];
      for (final row in (history as List).cast<Map<String, dynamic>>()) {
        final fixture = fixtureById[row['fixture']];
        if (fixture == null) continue;
        appearances.add(
          _Appearance(
            element: row['element'] as int,
            fixtureId: fixture.id,
            teamId: row['was_home'] == true
                ? fixture.homeTeamId
                : fixture.awayTeamId,
            minutes: _int(row['minutes']),
            starts: _int(row['starts']),
            goals: _int(row['goals_scored']),
            assists: _int(row['assists']),
            expectedGoals: _double(row['expected_goals']),
            expectedAssists: _double(row['expected_assists']),
            expectedGoalsConceded: _double(row['expected_goals_conceded']),
            value: _int(row['value']),
          ),
        );
      }
    }
    if (start % 160 == 0) stderr.write('.');
  }
  stderr.writeln();
  return _Season(
    name: 'live',
    teams: teams,
    fixtures: fixtures,
    positions: {
      for (final json in elements)
        json['id'] as int: json['element_type'] as int,
    },
    names: {
      for (final json in elements)
        json['id'] as int: json['web_name'] as String,
    },
    appearances: appearances,
  );
}

Future<_Season> _loadVaastav(String season, {required bool refresh}) async {
  Future<List<Map<String, String>>> csv(String path) async => _parseCsv(
    await _cached(
      '$season/${path.replaceAll('/', '_')}',
      '$_vaastav/$season/$path',
      refresh: refresh,
    ),
  );

  final teams = {
    for (final row in await csv('teams.csv'))
      int.parse(row['id']!): FplTeam.fromJson(row),
  };
  final fixtures = [
    for (final row in await csv('fixtures.csv'))
      FplFixture(
        id: int.parse(row['id']!),
        gameweekId: int.tryParse(row['event'] ?? ''),
        homeTeamId: int.parse(row['team_h']!),
        awayTeamId: int.parse(row['team_a']!),
        kickoffTime: DateTime.tryParse(row['kickoff_time'] ?? ''),
        finished: row['finished'] == 'True',
        started: row['started'] == 'True',
        homeScore: int.tryParse(row['team_h_score'] ?? ''),
        awayScore: int.tryParse(row['team_a_score'] ?? ''),
        homeDifficulty: int.tryParse(row['team_h_difficulty'] ?? ''),
        awayDifficulty: int.tryParse(row['team_a_difficulty'] ?? ''),
      ),
  ];
  final fixtureById = {for (final fixture in fixtures) fixture.id: fixture};
  const positionIds = {'GK': 1, 'GKP': 1, 'DEF': 2, 'MID': 3, 'FWD': 4};
  final positions = <int, int>{};
  final names = <int, String>{};
  final appearances = <_Appearance>[];
  for (final row in await csv('gws/merged_gw.csv')) {
    final element = int.parse(row['element']!);
    final position = positionIds[row['position']];
    final fixture = fixtureById[int.tryParse(row['fixture'] ?? '')];
    if (position == null || fixture == null) continue;
    positions[element] = position;
    names[element] = row['name'] ?? '$element';
    appearances.add(
      _Appearance(
        element: element,
        fixtureId: fixture.id,
        teamId: row['was_home'] == 'True'
            ? fixture.homeTeamId
            : fixture.awayTeamId,
        minutes: _int(row['minutes']),
        starts: _int(row['starts']),
        goals: _int(row['goals_scored']),
        assists: _int(row['assists']),
        expectedGoals: _double(row['expected_goals']),
        expectedAssists: _double(row['expected_assists']),
        expectedGoalsConceded: _double(row['expected_goals_conceded']),
        value: _int(row['value']),
      ),
    );
  }
  return _Season(
    name: season,
    teams: teams,
    fixtures: fixtures,
    positions: positions,
    names: names,
    appearances: appearances,
  );
}

int _int(Object? value) => value is int ? value : int.tryParse('$value') ?? 0;

double _double(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

List<Map<String, String>> _parseCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (quoted) {
      if (char == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        field.write(char);
      }
    } else if (char == '"') {
      quoted = true;
    } else if (char == ',') {
      row.add(field.toString());
      field.clear();
    } else if (char == '\n' || char == '\r') {
      if (char == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <String>[];
    } else {
      field.write(char);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  final header = rows.first;
  return [
    for (final values in rows.skip(1))
      if (values.length == header.length)
        {for (var i = 0; i < header.length; i++) header[i]: values[i]},
  ];
}

// ---------------------------------------------------------------------------
// Backtest

/// Scores for one predicted match, kept per match so two models can be
/// compared pairwise.
class _MatchScore {
  _MatchScore({
    required this.fixtureId,
    required this.brier,
    required this.logLoss,
    required this.resultHit,
    required this.exactScore,
    required this.goalsLogLoss,
    required this.cleanSheets,
    required this.topScorerHits,
    required this.topScorerPicks,
    required this.sideScorers,
  });

  final int fixtureId;
  final double brier;
  final double logLoss;
  final bool resultHit;
  final bool exactScore;

  /// Poisson log-loss of each side's expected goals against its real goals.
  final double goalsLogLoss;

  /// (predicted chance, kept a clean sheet) for both sides.
  final List<(double, bool)> cleanSheets;
  final int topScorerHits;
  final int topScorerPicks;

  /// (predicted chance, scored) for every per-side scorer pick.
  final List<(double, bool)> sideScorers;

  double get cleanSheetBrier =>
      cleanSheets.fold(0.0, (sum, c) => sum + _sq(c.$1 - (c.$2 ? 1 : 0))) /
      cleanSheets.length;
}

class _Result {
  _Result(this.scores);

  final List<_MatchScore> scores;

  int get matches => scores.length;
  double _mean(double Function(_MatchScore) f) =>
      scores.isEmpty ? 0 : scores.fold(0.0, (s, m) => s + f(m)) / matches;
  double get brier => _mean((m) => m.brier);
  double get logLoss => _mean((m) => m.logLoss);
  double get resultAccuracy => _mean((m) => m.resultHit ? 1 : 0);
  double get exactScore => _mean((m) => m.exactScore ? 1 : 0);
  double get goalsLogLoss => _mean((m) => m.goalsLogLoss);
  double get cleanSheetBrier => _mean((m) => m.cleanSheetBrier);
  double get topScorerHitRate {
    final picks = scores.fold(0, (s, m) => s + m.topScorerPicks);
    return picks == 0
        ? 0
        : scores.fold(0, (s, m) => s + m.topScorerHits) / picks;
  }

  List<(double, bool)> get _sideScorers => [
    for (final m in scores) ...m.sideScorers,
  ];
  double get sideScorerBrier {
    final picks = _sideScorers;
    return picks.isEmpty
        ? 0
        : picks.fold(0.0, (s, p) => s + _sq(p.$1 - (p.$2 ? 1 : 0))) /
              picks.length;
  }

  double get sideScorerHitRate {
    final picks = _sideScorers;
    return picks.isEmpty ? 0 : picks.where((p) => p.$2).length / picks.length;
  }

  double get sideScorerMeanChance {
    final picks = _sideScorers;
    return picks.isEmpty
        ? 0
        : picks.fold(0.0, (s, p) => s + p.$1) / picks.length;
  }
}

double _sq(double x) => x * x;

_Result _backtest(
  _Season season,
  FixturePredictionEngine engine, {
  bool fdrOnly = false,
}) {
  final scores = <_MatchScore>[];
  for (final gameweek in season.gameweeks) {
    final targets = season.fixtures
        .where((fixture) => fixture.gameweekId == gameweek)
        .toList(growable: false);
    final cutoff = targets
        .map((fixture) => fixture.kickoffTime)
        .whereType<DateTime>()
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final before = season.fixtures
        .where(
          (fixture) =>
              _hasResult(fixture) &&
              fixture.gameweekId != gameweek &&
              fixture.kickoffTime != null &&
              fixture.kickoffTime!.isBefore(cutoff),
        )
        .toList(growable: false);
    final players = _playersBefore(season, before, targets);
    final ratings = fdrOnly
        ? TeamRatings.empty
        : TeamRatings.from(
            teams: season.teams,
            fixtures: before,
            players: players,
            ratedTeamPriorMatches: engine.ratedTeamPriorMatches,
            teamPriorMatches: engine.teamPriorMatches,
            expectedGoalsWeight: engine.expectedGoalsWeight,
          );
    for (final target in targets) {
      final prediction = engine.predict(
        fixture: FplFixture(
          id: target.id,
          gameweekId: target.gameweekId,
          homeTeamId: target.homeTeamId,
          awayTeamId: target.awayTeamId,
          kickoffTime: target.kickoffTime,
          finished: false,
          started: false,
          homeDifficulty: target.homeDifficulty,
          awayDifficulty: target.awayDifficulty,
        ),
        teams: season.teams,
        players: players,
        ratings: ratings,
      );
      scores.add(_score(season, target, prediction));
    }
  }
  return _Result(scores);
}

/// Each player's totals from fixtures in [before], on the team and at the
/// price they had for [targets].
Map<int, FplPlayer> _playersBefore(
  _Season season,
  List<FplFixture> before,
  List<FplFixture> targets,
) {
  final current = <int, _Appearance>{};
  for (final target in targets) {
    for (final row in season.byFixture[target.id] ?? const <_Appearance>[]) {
      current[row.element] = row;
    }
  }
  final totals = <int, List<_Appearance>>{};
  for (final fixture in before) {
    for (final row in season.byFixture[fixture.id] ?? const <_Appearance>[]) {
      if (current.containsKey(row.element)) {
        totals.putIfAbsent(row.element, () => []).add(row);
      }
    }
  }
  return {
    for (final MapEntry(key: id, value: now) in current.entries)
      if (season.positions[id] case final position?)
        id: () {
          final rows = totals[id] ?? const <_Appearance>[];
          double sum(double Function(_Appearance) f) =>
              rows.fold(0.0, (s, r) => s + f(r));
          return FplPlayer(
            id: id,
            webName: season.names[id] ?? '$id',
            teamId: now.teamId,
            positionId: position,
            nowCost: now.value > 0 ? now.value : null,
            minutes: sum((r) => r.minutes.toDouble()).round(),
            starts: sum((r) => r.starts.toDouble()).round(),
            goalsScored: sum((r) => r.goals.toDouble()).round(),
            assists: sum((r) => r.assists.toDouble()).round(),
            expectedGoals: sum((r) => r.expectedGoals),
            expectedAssists: sum((r) => r.expectedAssists),
            expectedGoalsConceded: sum((r) => r.expectedGoalsConceded),
          );
        }(),
  };
}

_MatchScore _score(
  _Season season,
  FplFixture fixture,
  FixturePrediction prediction,
) {
  final home = fixture.homeScore!;
  final away = fixture.awayScore!;
  final probabilities = [
    prediction.homeWinChance,
    prediction.drawChance,
    prediction.awayWinChance,
  ].map((p) => math.max(p, 0.5)).toList();
  final total = probabilities.fold(0.0, (s, p) => s + p);
  final outcome = home > away ? 0 : (home == away ? 1 : 2);
  var brier = 0.0;
  for (var i = 0; i < 3; i++) {
    brier += _sq(probabilities[i] / total - (i == outcome ? 1 : 0));
  }
  final predictedOutcome = prediction.homeGoals > prediction.awayGoals
      ? 0
      : (prediction.homeGoals == prediction.awayGoals ? 1 : 2);

  double poissonLogLoss(double lambda, int goals) {
    var logFactorial = 0.0;
    for (var k = 2; k <= goals; k++) {
      logFactorial += math.log(k);
    }
    return lambda - goals * math.log(lambda) + logFactorial;
  }

  final scored = {
    for (final row in season.byFixture[fixture.id] ?? const <_Appearance>[])
      if (row.goals > 0) row.element,
  };
  bool hit(PlayerEventPrediction pick) => scored.contains(pick.player.id);
  return _MatchScore(
    fixtureId: fixture.id,
    brier: brier,
    logLoss: -math.log(probabilities[outcome] / total),
    resultHit: predictedOutcome == outcome,
    exactScore: prediction.homeGoals == home && prediction.awayGoals == away,
    goalsLogLoss:
        (poissonLogLoss(prediction.homeExpectedGoals, home) +
            poissonLogLoss(prediction.awayExpectedGoals, away)) /
        2,
    cleanSheets: [
      (prediction.homeCleanSheetChance / 100, away == 0),
      (prediction.awayCleanSheetChance / 100, home == 0),
    ],
    topScorerHits: prediction.scorers.where(hit).length,
    topScorerPicks: prediction.scorers.length,
    sideScorers: [
      for (final pick in [...prediction.homeScorers, ...prediction.awayScorers])
        (pick.chance / 100, hit(pick)),
    ],
  );
}

// ---------------------------------------------------------------------------
// Reporting

String _f(double value, [int digits = 4]) => value.toStringAsFixed(digits);
String _pct(double value) => '${(value * 100).toStringAsFixed(1)}%';

void _printTable(Map<String, _Result> results) {
  final rows = <String, String Function(_Result)>{
    '1X2 Brier (lower better)': (r) => _f(r.brier),
    '1X2 log-loss (lower better)': (r) => _f(r.logLoss),
    'Result accuracy': (r) => _pct(r.resultAccuracy),
    'Exact score': (r) => _pct(r.exactScore),
    'Goals Poisson log-loss': (r) => _f(r.goalsLogLoss),
    'Clean-sheet Brier': (r) => _f(r.cleanSheetBrier),
    'Top-3 scorer picks that scored': (r) => _pct(r.topScorerHitRate),
    'Per-side scorer picks: hit / mean chance': (r) =>
        '${_pct(r.sideScorerHitRate)} / ${_pct(r.sideScorerMeanChance)}',
    'Per-side scorer Brier': (r) => _f(r.sideScorerBrier),
  };
  final width = rows.keys.map((k) => k.length).reduce(math.max) + 2;
  stdout.writeln(
    ''.padRight(width) + results.keys.map((k) => k.padLeft(16)).join(),
  );
  for (final MapEntry(key: label, value: format) in rows.entries) {
    stdout.writeln(
      label.padRight(width) +
          results.values.map((r) => format(r).padLeft(16)).join(),
    );
  }
}

/// Mean paired difference (b - a) and its standard error, per match.
(double, double) _pairedDelta(
  _Result a,
  _Result b,
  double Function(_MatchScore) metric,
) {
  final n = a.scores.length;
  final diffs = [
    for (var i = 0; i < n; i++) metric(b.scores[i]) - metric(a.scores[i]),
  ];
  final mean = diffs.fold(0.0, (s, d) => s + d) / n;
  final variance =
      diffs.fold(0.0, (s, d) => s + _sq(d - mean)) / math.max(1, n - 1);
  return (mean, math.sqrt(variance / n));
}

final _deltaMetrics = <(String, double Function(_MatchScore))>[
  ('Brier', (m) => m.brier),
  ('log-loss', (m) => m.logLoss),
  ('goals', (m) => m.goalsLogLoss),
  ('exact', (m) => m.exactScore ? 1 : 0),
  ('top3 hits', (m) => m.topScorerHits.toDouble()),
];

void _printDelta(String label, _Result a, _Result b) {
  String delta(double Function(_MatchScore) metric) {
    final (mean, se) = _pairedDelta(a, b, metric);
    final verdict = mean.abs() > 2 * se ? ' *' : '';
    return '${mean >= 0 ? '+' : ''}${_f(mean)} ± ${_f(2 * se)}$verdict';
  }

  stdout.writeln(
    '$label (paired per match, ±2 SE, * = clear):\n  '
    '${[for (final (name, metric) in _deltaMetrics) '$name ${delta(metric)}'].join(', ')}',
  );
}

/// The same comparison restricted to the first [gameweeks] gameweeks and the
/// rest, since early-season predictions lean hardest on the prior.
void _printEarlyLate(_Season season, _Result a, _Result b, int gameweeks) {
  final early = season.fixtures
      .where((f) => (f.gameweekId ?? 0) <= gameweeks)
      .map((f) => f.id)
      .toSet();
  _Result pick(_Result r, bool wantEarly) => _Result([
    for (var i = 0; i < r.scores.length; i++)
      if (early.contains(r.scores[i].fixtureId) == wantEarly) r.scores[i],
  ]);
  final earlyA = pick(a, true);
  if (earlyA.matches == 0 || earlyA.matches == a.matches) return;
  final lateA = pick(a, false);
  _printDelta(
    '  GW1-$gameweeks (${earlyA.matches} matches)',
    earlyA,
    pick(b, true),
  );
  _printDelta(
    '  GW${gameweeks + 1}+ (${lateA.matches} matches)',
    lateA,
    pick(b, false),
  );
}

void _printCleanSheetCalibration(_Result result) {
  final buckets = List.generate(5, (_) => [0.0, 0.0, 0.0]);
  for (final (chance, kept) in [
    for (final m in result.scores) ...m.cleanSheets,
  ]) {
    final bucket = buckets[(chance * 5).floor().clamp(0, 4)];
    bucket[0] += chance;
    bucket[1] += kept ? 1 : 0;
    bucket[2] += 1;
  }
  final parts = <String>[];
  for (var i = 0; i < 5; i++) {
    final (sum, kept, n) = (buckets[i][0], buckets[i][1], buckets[i][2]);
    if (n == 0) continue;
    parts.add(
      '${i * 20}-${i * 20 + 20}%: predicted ${_pct(sum / n)}, '
      'actual ${_pct(kept / n)} (n=${n.round()})',
    );
  }
  stdout.writeln('Clean-sheet calibration (model):\n  ${parts.join('\n  ')}');
}

// ---------------------------------------------------------------------------
// Tuning

/// Coordinate search over the tunable constants, scored on 2025-26 with and
/// without the official prior, and checked on the live season.
void _tune(List<_Season> seasons) {
  const base = FixturePredictionEngine();
  FixturePredictionEngine engineWith({
    double? ratedTeamPriorMatches,
    double? teamPriorMatches,
    double? expectedGoalsWeight,
    double? rho,
    double? priorMinutes,
  }) => FixturePredictionEngine(
    ratedTeamPriorMatches: ratedTeamPriorMatches ?? base.ratedTeamPriorMatches,
    teamPriorMatches: teamPriorMatches ?? base.teamPriorMatches,
    expectedGoalsWeight: expectedGoalsWeight ?? base.expectedGoalsWeight,
    rho: rho ?? base.rho,
    priorMinutes: priorMinutes ?? base.priorMinutes,
  );

  void sweep(
    String title,
    List<(String, FixturePredictionEngine)> variants,
    List<(String, double Function(_Result))> metrics,
  ) {
    stdout.writeln('\n--- $title ---');
    stdout.writeln(
      'variant'.padRight(22) +
          [
            for (final season in seasons)
              for (final (name, _) in metrics)
                '${season.name} $name'.padLeft(24),
          ].join(),
    );
    for (final (label, engine) in variants) {
      final cells = <String>[];
      for (final season in seasons) {
        final result = _backtest(season, engine);
        for (final (_, metric) in metrics) {
          cells.add(_f(metric(result)).padLeft(24));
        }
      }
      stdout.writeln(label.padRight(22) + cells.join());
    }
  }

  final teamMetrics = [
    ('logloss', (_Result r) => r.logLoss),
    ('goals', (_Result r) => r.goalsLogLoss),
  ];
  // Both prior weights move together here; only seasons with official
  // ratings (2025-26) use the rated one.
  sweep('team prior matches x expectedGoalsWeight', [
    for (final prior in [2.0, 4.0, 6.0, 9.0, 12.0, 18.0])
      for (final xg in [0.3, 0.5, 0.65, 0.8, 1.0])
        (
          'prior $prior xg $xg',
          engineWith(
            ratedTeamPriorMatches: prior,
            teamPriorMatches: prior,
            expectedGoalsWeight: xg,
          ),
        ),
  ], teamMetrics);
  sweep(
    'rho',
    [
      for (final rho in [-0.2, -0.15, -0.1, -0.08, -0.05, 0.0, 0.05])
        ('rho $rho', engineWith(rho: rho)),
    ],
    [('logloss', (r) => r.logLoss), ('exact', (r) => r.exactScore)],
  );
  sweep(
    'priorMinutes',
    [
      for (final minutes in [90.0, 180.0, 270.0, 450.0, 720.0, 1080.0, 1800.0])
        ('minutes $minutes', engineWith(priorMinutes: minutes)),
    ],
    [
      ('top3', (r) => r.topScorerHitRate),
      ('sideBrier', (r) => r.sideScorerBrier),
    ],
  );

  stdout.writeln('\n--- Candidates vs current defaults ---');
  final candidates = {
    'before tuning (rated prior 6)': engineWith(ratedTeamPriorMatches: 6),
    'ratedTeamPriorMatches 18': engineWith(ratedTeamPriorMatches: 18),
    'rho -0.15': engineWith(rho: -0.15),
    'rho -0.12': engineWith(rho: -0.12),
    'priorMinutes 1080': engineWith(priorMinutes: 1080),
    'teamPriorMatches 4': engineWith(teamPriorMatches: 4),
    'teamPriorMatches 12': engineWith(teamPriorMatches: 12),
    'teamPriorMatches 18': engineWith(teamPriorMatches: 18),
    'expectedGoalsWeight 0.8': engineWith(expectedGoalsWeight: 0.8),
  };
  for (final season in seasons) {
    stdout.writeln('${season.name}:');
    final current = _backtest(season, base);
    for (final MapEntry(key: label, value: engine) in candidates.entries) {
      _printDelta('  $label', current, _backtest(season, engine));
    }
  }
}
