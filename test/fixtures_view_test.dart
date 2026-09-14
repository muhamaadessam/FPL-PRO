import 'dart:io';
import 'package:fantasy_pl/core/models/fpl_models.dart';
import 'package:fantasy_pl/core/network/fpl_api_client.dart';
import 'package:fantasy_pl/features/fixtures/presentation/fixtures_view.dart';
import 'package:fantasy_pl/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeFplApiClient implements FplApiClient {
  bool shouldThrowError = false;

  @override
  Future<FplBootstrap> getBootstrap() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (shouldThrowError) {
      throw const FplApiException(
        kind: FplApiErrorKind.network,
        message: 'err',
      );
    }
    return FplBootstrap(
      gameweeks: [
        Gameweek(
          id: 1,
          name: 'Gameweek 1',
          deadlineTime: DateTime.now(),
          finished: false,
          isCurrent: true,
          isNext: false,
        ),
      ],
      teams: const {
        1: FplTeam(id: 1, name: 'Arsenal', shortName: 'ARS', code: 3),
        2: FplTeam(id: 2, name: 'Chelsea', shortName: 'CHE', code: 8),
      },
      players: const {
        99: FplPlayer(id: 99, webName: 'Scorer', teamId: 1, positionId: 4),
        100: FplPlayer(id: 100, webName: 'Booked', teamId: 2, positionId: 2),
      },
    );
  }

  @override
  Future<List<FplFixture>> getFixtures({int? gameweekId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (shouldThrowError) {
      throw const FplApiException(
        kind: FplApiErrorKind.network,
        message: 'err',
      );
    }
    return [
      FplFixture(
        id: 1,
        gameweekId: 1,
        homeTeamId: 1,
        awayTeamId: 2,
        kickoffTime: DateTime.now().add(const Duration(days: 1)),
        finished: false,
        started: false,
      ),
      FplFixture(
        id: 2,
        gameweekId: 1,
        homeTeamId: 2,
        awayTeamId: 1,
        kickoffTime: DateTime.now().subtract(const Duration(hours: 1)),
        finished: false,
        started: true,
        homeScore: 1,
        awayScore: 0,
      ),
      FplFixture.fromJson({
        'id': 3,
        'event': 1,
        'team_h': 1,
        'team_a': 2,
        'kickoff_time': DateTime.now()
            .subtract(const Duration(days: 1))
            .toIso8601String(),
        'finished': false,
        'finished_provisional': true,
        'started': true,
        'team_h_score': 2,
        'team_a_score': 2,
        'stats': [
          {
            'identifier': 'goals_scored',
            'h': [
              {'element': 99, 'value': 2},
            ],
            'a': [],
          },
          {
            'identifier': 'bonus',
            'h': [
              {'element': 99, 'value': 3},
            ],
            'a': [],
          },
          {
            'identifier': 'yellow_cards',
            'h': [],
            'a': [
              {'element': 100, 'value': 1},
            ],
          },
          {
            'identifier': 'saves',
            'h': [],
            'a': [
              {'element': 100, 'value': 2},
            ],
          },
        ],
      }),
      // Finished match with missing scores to test em dash logic
      FplFixture(
        id: 4,
        gameweekId: 1,
        homeTeamId: 1,
        awayTeamId: 2,
        kickoffTime: DateTime.now().subtract(const Duration(days: 1)),
        finished: true,
        started: true,
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeImageHttpClient extends Fake implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    throw const SocketException('Fake error');
  }
}

class FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return FakeImageHttpClient();
  }
}

void main() {
  setUpAll(() {
    HttpOverrides.global = FakeHttpOverrides();
  });

  Widget createWidgetUnderTest(
    FakeFplApiClient apiClient, {
    Locale locale = const Locale('en'),
  }) {
    return ProviderScope(
      overrides: [fplApiClientProvider.overrideWithValue(apiClient)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: const Scaffold(body: FixturesView()),
      ),
    );
  }

  testWidgets('renders shimmer while loading and no CircularProgressIndicator', (
    tester,
  ) async {
    final apiClient = FakeFplApiClient();
    await tester.pumpWidget(createWidgetUnderTest(apiClient));
    await tester.pump(); // Pump for localization

    // Assert no generic spinners and custom skeleton is present BEFORE future completes
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(ShaderMask), findsWidgets);

    await tester.pumpAndSettle(); // let it finish loading
  });

  testWidgets('renders error state and retries', (tester) async {
    final apiClient = FakeFplApiClient()..shouldThrowError = true;
    await tester.pumpWidget(createWidgetUnderTest(apiClient));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not reach the official data service.'),
      findsOneWidget,
    );

    apiClient.shouldThrowError = false;
    await tester.tap(find.text('Try again'));
    await tester.pump();

    await tester.pumpAndSettle();
    expect(find.text('Gameweek 1'), findsOneWidget);
  });

  testWidgets(
    'renders upcoming, live, and finished states correctly in English with em dash for null scores',
    (tester) async {
      final apiClient = FakeFplApiClient();
      await tester.pumpWidget(createWidgetUnderTest(apiClient));
      await tester.pumpAndSettle();

      expect(find.text('Gameweek 1'), findsOneWidget);
      expect(find.text('4 matches'), findsOneWidget);

      expect(find.text('UPCOMING'), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);
      expect(
        find.text('FINISHED'),
        findsNWidgets(2),
      ); // Regular finished + missing score finished

      expect(find.text('1 - 0'), findsOneWidget);
      expect(find.text('2 - 2'), findsOneWidget);
      expect(find.text('—'), findsOneWidget); // Em dash for missing scores
    },
  );

  testWidgets(
    'renders upcoming, live, and finished states correctly in Arabic',
    (tester) async {
      final apiClient = FakeFplApiClient();
      await tester.pumpWidget(
        createWidgetUnderTest(apiClient, locale: const Locale('ar')),
      );
      await tester.pumpAndSettle();

      expect(find.text('الأسبوع 1'), findsOneWidget);
      expect(find.text('4 مباريات'), findsOneWidget);

      expect(find.text('قادمة'), findsOneWidget);
      expect(find.text('مباشر'), findsOneWidget);
      expect(find.text('انتهت'), findsNWidgets(2));
    },
  );

  testWidgets('renders official badges gracefully', (tester) async {
    final apiClient = FakeFplApiClient();
    await tester.pumpWidget(createWidgetUnderTest(apiClient));
    await tester.pumpAndSettle();

    // 4 fixtures * 2 teams = 8 badges total.
    expect(find.byType(Image), findsNWidgets(8));
  });

  testWidgets('opens match details in a bottom sheet', (tester) async {
    final apiClient = FakeFplApiClient();
    await tester.pumpWidget(createWidgetUnderTest(apiClient));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('fixture-card-3')));
    await tester.pumpAndSettle();

    expect(find.text('Match details'), findsOneWidget);
    expect(find.text('Goals'), findsOneWidget);
    expect(find.text('Bonus points'), findsOneWidget);
    expect(find.text('Yellow cards'), findsOneWidget);
    expect(find.text('Booked'), findsOneWidget);
    expect(find.text('-1 pts'), findsOneWidget);
    expect(find.text('Saves'), findsNothing);
    expect(find.text('Scorer'), findsNWidgets(2));
    expect(find.text('+8 pts'), findsOneWidget);
    expect(find.text('+3 pts'), findsOneWidget);
  });
}
