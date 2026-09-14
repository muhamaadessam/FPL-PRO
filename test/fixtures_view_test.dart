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
      players: const {},
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
      FplFixture(
        id: 3,
        gameweekId: 1,
        homeTeamId: 1,
        awayTeamId: 2,
        kickoffTime: DateTime.now().subtract(const Duration(days: 1)),
        finished: true,
        started: true,
        homeScore: 2,
        awayScore: 2,
      ),
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
}
