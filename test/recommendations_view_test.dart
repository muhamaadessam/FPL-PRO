import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fantasy_pl/core/models/fpl_models.dart';
import 'package:fantasy_pl/features/recommendations/domain/recommendation_engine.dart';
import 'package:fantasy_pl/features/recommendations/presentation/recommendations_view.dart';
import 'package:fantasy_pl/l10n/app_localizations.dart';

void main() {
  testWidgets('recommendations fit a narrow Arabic screen', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bootstrap = FplBootstrap.fromJson({
      'events': [
        {'id': 38, 'name': 'Gameweek 38', 'is_next': true},
      ],
      'teams': const [],
      'elements': const [],
    });
    final data = RecommendationData(
      bootstrap: bootstrap,
      gameweek: bootstrap.gameweeks.single,
      result: const RecommendationResult(
        gameweekId: 38,
        captain: null,
        viceCaptain: null,
        transfers: [],
        topByPosition: {},
        chip: SuggestedChip.none,
        chipReason: ChipReason.hold,
        benchProjectedPoints: 0,
        freeTransfers: 5,
        bank: 125,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [recommendationsProvider.overrideWith((ref) async => data)],
        child: MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: RecommendationsView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
