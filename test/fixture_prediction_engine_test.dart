import 'package:fantasy_pl/features/fixtures/data/models/fpl_models.dart';
import 'package:fantasy_pl/features/fixtures/domain/usecases/predict_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = FixturePredictionEngine();
  const teams = {
    1: FplTeam(
      id: 1,
      name: 'Home',
      shortName: 'HOM',
      strengthAttackHome: 1180,
      strengthDefenceHome: 1120,
    ),
    2: FplTeam(
      id: 2,
      name: 'Away',
      shortName: 'AWY',
      strengthAttackAway: 1050,
      strengthDefenceAway: 980,
    ),
  };
  const players = {
    1: FplPlayer(
      id: 1,
      webName: 'Finisher',
      teamId: 1,
      positionId: 4,
      minutes: 900,
      starts: 10,
      goalsScored: 7,
      expectedGoals: 8,
      expectedAssists: 2,
      form: 8,
      pointsPerGame: 7,
    ),
    2: FplPlayer(
      id: 2,
      webName: 'Support',
      teamId: 1,
      positionId: 3,
      minutes: 850,
      starts: 10,
      goalsScored: 1,
      assists: 2,
      expectedGoals: 1.2,
      expectedAssists: 2.5,
      form: 4,
      pointsPerGame: 4,
    ),
    3: FplPlayer(
      id: 3,
      webName: 'Creator',
      teamId: 2,
      positionId: 3,
      minutes: 880,
      starts: 10,
      goalsScored: 2,
      assists: 6,
      expectedGoals: 2,
      expectedAssists: 7,
      form: 7,
      pointsPerGame: 6,
    ),
  };

  test('predicts every unplayed fixture in the next three gameweeks', () {
    final predictions = engine.predictNextGameweeks(
      fixtures: [
        _fixture(1, 5),
        _fixture(2, 6),
        _fixture(3, 7),
        _fixture(4, 8),
        _fixture(5, 5, started: true),
        _fixture(6, 4),
      ],
      teams: teams,
      players: players,
      fromGameweekId: 5,
    );

    expect(predictions.keys, containsAll([1, 2, 3]));
    expect(predictions, hasLength(3));
    expect(predictions, isNot(contains(4)));
    expect(predictions, isNot(contains(5)));
    expect(predictions, isNot(contains(6)));
  });

  test('uses official attacking data to rank scorer and assist candidates', () {
    final prediction = engine.predict(
      fixture: _fixture(1, 5),
      teams: teams,
      players: players,
    );

    expect(prediction.scorers.first.player.webName, 'Finisher');
    expect(prediction.assists.first.player.webName, 'Creator');
    expect(prediction.confidence, inInclusiveRange(40, 85));
    expect(prediction.homeCleanSheetChance, inInclusiveRange(5, 75));
  });
}

FplFixture _fixture(int id, int gameweek, {bool started = false}) {
  return FplFixture(
    id: id,
    gameweekId: gameweek,
    homeTeamId: 1,
    awayTeamId: 2,
    kickoffTime: DateTime(2026, 9, gameweek),
    finished: false,
    started: started,
    homeDifficulty: 2,
    awayDifficulty: 4,
  );
}
