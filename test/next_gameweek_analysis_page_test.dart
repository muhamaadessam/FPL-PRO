import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fantasy_pl/features/fixtures/data/models/fpl_models.dart';
import 'package:fantasy_pl/features/recommendations/domain/usecases/recommendation_engine.dart';
import 'package:fantasy_pl/features/recommendations/domain/entities/recommendation_data.dart';
import 'package:fantasy_pl/features/recommendations/presentation/screens/next_gameweek_analysis_page.dart';
import 'package:fantasy_pl/features/team/data/models/team_models.dart';
import 'package:fantasy_pl/l10n/app_localizations.dart';

void main() {
  testWidgets('displays decimal expected points on the pitch', (tester) async {
    final bootstrap = FplBootstrap.fromJson({
      'events': [
        {'id': 1, 'name': 'Gameweek 1', 'is_next': true},
      ],
      'teams': [
        {'id': 1, 'name': 'Arsenal', 'short_name': 'ARS'},
      ],
      'elements': [
        {
          'id': 1,
          'web_name': 'Saka',
          'team': 1,
          'element_type': 3,
          'now_cost': 100,
          'can_select': true,
          'status': 'a',
          'form': '5.4',
          'points_per_game': '5.4',
          'ep_next': '5.4',
          'minutes': 90,
          'starts': 1,
        },
      ],
    });

    final team = MyTeam.fromJson({
      'picks': [
        {'element': 1, 'position': 1, 'element_type': 3},
      ],
    });

    final data = const RecommendationEngine().build(
      bootstrap: bootstrap,
      fixtures: [
        FplFixture.fromJson({
          'id': 1,
          'event': 1,
          'team_h': 1,
          'team_a': 2,
          'team_h_difficulty': 2,
          'team_a_difficulty': 4,
        }),
      ],
      team: team,
      gameweekId: 1,
    );

    final dataWrap = RecommendationData(
      result: data,
      gameweek: bootstrap.gameweeks.first,
      bootstrap: bootstrap,
      team: team,
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NextGameweekAnalysisPage(data: dataWrap),
      ),
    );
    await tester.pumpAndSettle();

    final expectedText = data.squadAnalysis.players.first.expectedPoints
        .toStringAsFixed(1);
    expect(find.byKey(const ValueKey('pitch-player-points-1')), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('pitch-player-points-1')))
          .data,
      expectedText,
    );
    expect(find.text('PTS'), findsWidgets);
  });
}
