import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fantasy_pl/features/fixtures/data/models/fpl_models.dart';
import 'package:fantasy_pl/features/recommendations/domain/usecases/recommendation_engine.dart';
import 'package:fantasy_pl/features/recommendations/domain/entities/recommendation_data.dart';
import 'package:fantasy_pl/features/recommendations/presentation/screens/next_gameweek_analysis_page.dart';
import 'package:fantasy_pl/features/team/presentation/widgets/pitch_view.dart';
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

  testWidgets('swaps player from bench to pitch and shows risk alert', (
    tester,
  ) async {
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
          'web_name': 'Saka', // Starter
          'team': 1,
          'element_type': 3,
          'status': 'a',
        },
        {
          'id': 2,
          'web_name': 'Martinelli', // Bench, doubtful
          'team': 1,
          'element_type': 3,
          'status': 'd',
          'chance_of_playing_next_round': 75,
          'news': 'Knock',
        },
      ],
    });

    final team = MyTeam.fromJson({
      'picks': [
        {'element': 1, 'position': 1, 'element_type': 3}, // Starter
        {'element': 2, 'position': 12, 'element_type': 3}, // Bench
      ],
    });

    final data = const RecommendationEngine().build(
      bootstrap: bootstrap,
      fixtures: [],
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

    final benchPlayerDrag = find.descendant(
      of: find.byType(PitchView),
      matching: find.text('Martinelli'),
    );
    final starterTarget = find.descendant(
      of: find.byType(PitchView),
      matching: find.text('Saka'),
    );

    expect(benchPlayerDrag, findsOneWidget);
    expect(starterTarget, findsOneWidget);

    await tester.ensureVisible(starterTarget);
    await tester.pumpAndSettle();
    final targetCenter = tester.getCenter(starterTarget);

    await tester.ensureVisible(benchPlayerDrag);
    await tester.pumpAndSettle();
    final dragCenter = tester.getCenter(benchPlayerDrag);

    final dragGesture = await tester.startGesture(dragCenter);
    await tester.pump(const Duration(seconds: 1)); // Wait for long press
    await dragGesture.moveTo(targetCenter);
    await tester.pump();
    await dragGesture.up();
    await tester.pumpAndSettle();

    // The dialog should be shown
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Martinelli'), findsWidgets); // Title
    expect(find.text('Availability: 75%'), findsOneWidget);
    expect(find.text('News: Knock'), findsOneWidget);

    // Dismiss dialog
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Verify it's dismissed
    expect(find.byType(AlertDialog), findsNothing);
  });
}
