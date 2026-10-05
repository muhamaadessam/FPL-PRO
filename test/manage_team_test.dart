import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fantasy_pl/features/auth/domain/entities/official_session.dart';
import 'package:fantasy_pl/features/auth/domain/repositories/auth_repository.dart';
import 'package:fantasy_pl/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:fantasy_pl/features/fixtures/data/models/fpl_models.dart';
import 'package:fantasy_pl/features/fixtures/domain/repositories/fixtures_repository.dart';
import 'package:fantasy_pl/features/team/data/models/team_models.dart';
import 'package:fantasy_pl/features/team/domain/repositories/team_repository.dart';
import 'package:fantasy_pl/features/team/presentation/cubit/manage_team_cubit.dart';
import 'package:fantasy_pl/features/team/presentation/screens/manage_team_page.dart';
import 'package:fantasy_pl/l10n/app_localizations.dart';

const _session = OfficialSession(accessToken: 'token', entryId: 123);
const _positions = [1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 1, 2, 3, 4];

FplBootstrap _bootstrap() => FplBootstrap.fromJson({
  'events': [
    {'id': 5, 'name': 'Gameweek 5', 'is_current': true, 'finished': true},
    {'id': 6, 'name': 'Gameweek 6', 'is_next': true},
  ],
  'teams': [
    for (var t = 1; t <= 16; t++)
      {'id': t, 'name': 'Team $t', 'short_name': 'T$t'},
  ],
  'elements': [
    for (var i = 0; i < _positions.length; i++)
      {
        'id': i + 1,
        'web_name': 'Player ${i + 1}',
        'team': i + 1,
        'element_type': _positions[i],
        'now_cost': 50,
      },
    {
      'id': 99,
      'web_name': 'Signing',
      'team': 16,
      'element_type': 3,
      'now_cost': 55,
    },
  ],
});

MyTeam _team() => MyTeam.fromJson({
  'picks': [
    for (var i = 0; i < _positions.length; i++)
      {
        'element': i + 1,
        'position': i + 1,
        'multiplier': i == 9 ? 2 : (i < 11 ? 1 : 0),
        'is_captain': i == 9,
        'is_vice_captain': i == 10,
        'element_type': _positions[i],
        'selling_price': 50,
      },
  ],
  'transfers': {'bank': 10, 'limit': 1, 'made': 0, 'cost': 4},
  'chips': [
    {'name': 'bboost', 'status_for_entry': 'available'},
    {'name': '3xc', 'status_for_entry': 'available'},
    {'name': 'wildcard', 'status_for_entry': 'available'},
    {'name': 'freehit', 'status_for_entry': 'available'},
  ],
});

void main() {
  late _FakeTeamRepository teamRepository;
  late ManageTeamCubit cubit;

  setUp(() async {
    teamRepository = _FakeTeamRepository();
    cubit = ManageTeamCubit(
      fixturesRepository: _FakeFixturesRepository(),
      teamRepository: teamRepository,
      authCubit: AuthCubit(
        const _FakeAuthRepository(),
        initialState: const AuthAuthenticated(_session),
      ),
    );
    await cubit.load();
  });

  tearDown(() => cubit.close());

  test('loads the squad for the next deadline', () {
    expect(teamRepository.requestedGameweeks, [6]);
    expect(cubit.state.gameweek?.id, 6);
    expect(cubit.state.hasLineupChanges, isFalse);
  });

  test('saves a new captain and triple captain chip', () async {
    expect(cubit.setCaptain(6), isNull);
    cubit.toggleLineupChip(FplChipName.tripleCaptain);
    expect(cubit.state.hasLineupChanges, isTrue);

    await cubit.saveLineup();

    final saved = teamRepository.savedLineups.single;
    expect(saved.chip, '3xc');
    expect(saved.picks.singleWhere((p) => p.isCaptain).elementId, 6);
    expect(saved.picks.singleWhere((p) => p.isViceCaptain).elementId, 11);
    expect(cubit.state.lastAction, ManageTeamAction.lineupSaved);
  });

  test('confirms queued transfers with a free hit', () async {
    final signing = cubit.state.bootstrap!.players[99]!;
    expect(cubit.queueTransfer(7, signing), isNull);
    cubit.toggleTransferChip(FplChipName.freeHit);
    expect(cubit.state.plan!.remainingBank, 5);

    await cubit.confirmTransfers();

    final call = teamRepository.transferCalls.single;
    expect(call.gameweekId, 6);
    expect(call.chip, 'freehit');
    expect(
      call.transfers.single,
      const TransferRequest(
        elementIn: 99,
        elementOut: 7,
        purchasePrice: 55,
        sellingPrice: 50,
      ),
    );
    expect(cubit.state.lastAction, ManageTeamAction.transfersConfirmed);
  });

  testWidgets('manages the lineup on a narrow Arabic screen', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeTeamRepository();

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<FixturesRepository>.value(
            value: _FakeFixturesRepository(),
          ),
          RepositoryProvider<TeamRepository>.value(value: repository),
        ],
        child: BlocProvider(
          create: (_) => AuthCubit(
            const _FakeAuthRepository(),
            initialState: const AuthAuthenticated(_session),
          ),
          child: MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ManageTeamPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Player 6'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Player 6'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اجعله القائد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ التشكيلة'));
    await tester.pumpAndSettle();

    expect(
      repository.savedLineups.single.picks
          .singleWhere((p) => p.isCaptain)
          .elementId,
      6,
    );
    expect(find.text('تم حفظ التشكيلة على FPL.'), findsOneWidget);

    await tester.tap(find.text('الانتقالات'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class _SavedLineup {
  const _SavedLineup(this.chip, this.picks);

  final String? chip;
  final List<TeamPick> picks;
}

class _TransferCall {
  const _TransferCall(this.gameweekId, this.transfers, this.chip);

  final int gameweekId;
  final List<TransferRequest> transfers;
  final String? chip;
}

class _FakeTeamRepository implements TeamRepository {
  final requestedGameweeks = <int>[];
  final savedLineups = <_SavedLineup>[];
  final transferCalls = <_TransferCall>[];

  @override
  Future<MyTeam> getMyTeam({
    required OfficialSession session,
    required int entryId,
    required int gameweekId,
  }) async {
    requestedGameweeks.add(gameweekId);
    return _team();
  }

  @override
  Future<void> saveMyTeam({
    required OfficialSession session,
    required int entryId,
    required String? chip,
    required List<TeamPick> picks,
  }) async {
    savedLineups.add(_SavedLineup(chip, picks));
  }

  @override
  Future<void> makeTransfers({
    required OfficialSession session,
    required int entryId,
    required int gameweekId,
    required List<TransferRequest> transfers,
    String? chip,
  }) async {
    transferCalls.add(_TransferCall(gameweekId, transfers, chip));
  }

  @override
  Future<FplEntry> getEntry(int entryId) async =>
      FplEntry(id: entryId, name: 'Fake FC');

  @override
  Future<FplLeagueDetails> getLeagueStandings({
    required FplLeague league,
    int page = 1,
  }) async => FplLeagueDetails(
    league: league,
    standings: const [],
    page: page,
    hasNext: false,
  );

  @override
  Future<MyTeam> getTeamForGameweek({
    required OfficialSession session,
    required int entryId,
    required int gameweekId,
    required int currentGameweekId,
  }) async => _team();

  @override
  Future<MyTeam> getPublicTeam({
    required int entryId,
    required int gameweekId,
  }) async => _team();
}

class _FakeFixturesRepository implements FixturesRepository {
  @override
  Future<FplBootstrap> getBootstrap() async => _bootstrap();

  @override
  Future<List<FplFixture>> getFixtures({int? gameweekId}) async => const [];

  @override
  Future<Map<int, int>> getGameweekPoints(int gameweekId) async => const {};

  @override
  Future<Map<int, int>> getEntryHistoryPoints(int entryId) async => const {};

  @override
  Future<FplPlayerSummary> getPlayerSummary(int playerId) async =>
      const FplPlayerSummary();
}

class _FakeAuthRepository implements AuthRepository {
  const _FakeAuthRepository();

  @override
  Future<OfficialSession?> restoreSession() async => _session;

  @override
  Future<OfficialSession> signIn({
    Future<String> Function(Uri authorizationUri)? authenticate,
    Future<Map<String, String>> Function()? webSessionProvider,
  }) async => _session;

  @override
  Future<void> logout() async {}
}
