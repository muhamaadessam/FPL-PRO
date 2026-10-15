import 'package:fantasy_pl/features/fixtures/data/models/fpl_models.dart';
import 'package:fantasy_pl/features/fixtures/domain/usecases/team_ratings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const teams = {
    1: FplTeam(
      id: 1,
      name: 'One',
      shortName: 'ONE',
      strengthAttackHome: 1200,
      strengthAttackAway: 1200,
      strengthDefenceHome: 1200,
      strengthDefenceAway: 1200,
    ),
    2: FplTeam(
      id: 2,
      name: 'Two',
      shortName: 'TWO',
      strengthAttackHome: 1200,
      strengthAttackAway: 1200,
      strengthDefenceHome: 1200,
      strengthDefenceAway: 1200,
    ),
    3: FplTeam(
      id: 3,
      name: 'Three',
      shortName: 'THR',
      strengthAttackHome: 1200,
      strengthAttackAway: 1200,
      strengthDefenceHome: 1200,
      strengthDefenceAway: 1200,
    ),
  };

  test('falls back to the official ratings before any results', () {
    final ratings = TeamRatings.from(teams: teams, fixtures: const []);

    expect(ratings.attack(1), closeTo(1, 0.001));
    expect(ratings.matchesPlayed(1), 0);
    final (home, away) = ratings.expectedGoals(_result(1, 2));
    expect(home, greaterThan(away));
  });

  test('moves towards this season results, adjusted for opponents', () {
    final ratings = TeamRatings.from(
      teams: teams,
      fixtures: [
        for (var round = 1; round <= 6; round++) ...[
          _result(1, 2, home: 3, away: 0, round: round),
          _result(3, 1, home: 0, away: 2, round: round),
        ],
      ],
    );

    expect(ratings.matchesPlayed(1), 12);
    expect(ratings.attack(1), greaterThan(ratings.attack(2)));
    expect(ratings.defence(1), lessThan(ratings.defence(3)));
    expect(ratings.isRated(2), isTrue);
  });

  test('stays empty without ratings or results', () {
    final ratings = TeamRatings.from(
      teams: const {1: FplTeam(id: 1, name: 'One', shortName: 'ONE')},
      fixtures: const [],
    );

    expect(identical(ratings, TeamRatings.empty), isTrue);
    expect(ratings.isRated(1), isFalse);
  });
}

FplFixture _result(
  int homeTeam,
  int awayTeam, {
  int? home,
  int? away,
  int round = 1,
}) {
  return FplFixture(
    id: round * 100 + homeTeam * 10 + awayTeam,
    gameweekId: round,
    homeTeamId: homeTeam,
    awayTeamId: awayTeam,
    kickoffTime: DateTime(2026, 8, round),
    finished: home != null,
    started: home != null,
    homeScore: home,
    awayScore: away,
  );
}
