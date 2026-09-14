import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fantasy_pl/core/models/fpl_models.dart';
import 'package:fantasy_pl/core/network/fpl_api_client.dart';
import 'package:fantasy_pl/features/team/presentation/team_view.dart';
import 'package:fantasy_pl/features/team/presentation/pitch_view.dart';
import 'package:fantasy_pl/l10n/app_localizations.dart';

void main() {
  testWidgets('applies captain multiplier to player points', (tester) async {
    final bootstrap = FplBootstrap.fromJson({
      'teams': [
        {'id': 1, 'name': 'Test FC', 'short_name': 'TST'},
      ],
      'elements': [
        {'id': 10, 'web_name': 'Captain', 'team': 1, 'element_type': 4},
        {'id': 11, 'web_name': 'Bench', 'team': 1, 'element_type': 4},
      ],
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PitchView(
            starting: [
              TeamPick.fromJson({
                'element': 10,
                'position': 1,
                'multiplier': 2,
                'is_captain': true,
                'element_type': 4,
              }),
            ],
            bench: [
              TeamPick.fromJson({
                'element': 11,
                'position': 12,
                'multiplier': 0,
                'element_type': 4,
              }),
            ],
            bootstrap: bootstrap,
            gameweekPoints: const {10: 2, 11: 17},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('4'), findsOneWidget);
    expect(find.text('2'), findsNothing);
    expect(find.text('17'), findsOneWidget);
  });

  testWidgets('reloads team and player points for the selected gameweek', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _FakeFplApiClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [fplApiClientProvider.overrideWithValue(api)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: TeamView(entryId: 123)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('team-gameweek-filter')), findsOneWidget);
    expect(api.teamRequests, [4]);
    expect(api.pointsRequests, [4]);
    expect(find.text('GW4 Player'), findsOneWidget);
    expect(find.text('60'), findsOneWidget);
    expect(find.text('130'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('team-gameweek-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GW 5').last);
    await tester.pumpAndSettle();

    expect(api.teamRequests.last, 5);
    expect(api.pointsRequests.last, 5);
    expect(find.text('GW4 Player'), findsNothing);
    expect(find.text('GW5 Player'), findsOneWidget);
  });

  testWidgets('team layout bounds in Arabic at 320px', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _FakeFplApiClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [fplApiClientProvider.overrideWithValue(api)],
        child: MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: TeamView(entryId: 123)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('المتوسط'), findsOneWidget);
    expect(find.text('الأعلى'), findsOneWidget);
    expect(find.text('نقطة'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not use player live rows as the team gameweek total', (
    tester,
  ) async {
    final api = _FakeFplApiClient(useOfficialPoints: false);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [fplApiClientProvider.overrideWithValue(api)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: TeamView(entryId: 123)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('83'), findsNothing);
  });
}

class _FakeFplApiClient extends FplApiClient {
  _FakeFplApiClient({this.useOfficialPoints = true}) : super(dio: Dio());

  final bool useOfficialPoints;

  final teamRequests = <int>[];
  final pointsRequests = <int>[];

  @override
  Future<FplBootstrap> getBootstrap() async {
    return FplBootstrap.fromJson({
      'events': [
        {
          'id': 4,
          'name': 'Gameweek 4',
          'is_current': true,
          'is_next': false,
          'average_entry_score': 50,
          'highest_score': 130,
        },
        {'id': 5, 'name': 'Gameweek 5', 'is_current': false, 'is_next': true},
      ],
      'teams': [
        {'id': 1, 'name': 'Test FC', 'short_name': 'TST'},
      ],
      'elements': [
        {'id': 1, 'web_name': 'GW4 Player', 'team': 1, 'element_type': 4},
        {'id': 2, 'web_name': 'GW4 Player 2', 'team': 1, 'element_type': 4},
        {'id': 3, 'web_name': 'GW5 Player', 'team': 1, 'element_type': 4},
      ],
    });
  }

  @override
  Future<MyTeam> getPublicTeam({
    required int entryId,
    required int gameweekId,
  }) async {
    teamRequests.add(gameweekId);
    return MyTeam.fromJson({
      'picks': [
        {
          'element': gameweekId == 4 ? 1 : 3,
          'position': 1,
          'multiplier': 1,
          'element_type': 4,
        },
        if (gameweekId == 4)
          {'element': 2, 'position': 2, 'multiplier': 1, 'element_type': 4},
      ],
      'entry_history': {
        'event': gameweekId,
        'points': useOfficialPoints && gameweekId == 4 ? 60 : 0,
      },
    });
  }

  @override
  Future<Map<int, int>> getGameweekPoints(int gameweekId) async {
    pointsRequests.add(gameweekId);
    return gameweekId == 4 ? const {1: 40, 2: 43} : const {};
  }

  @override
  void dispose() {}
}
