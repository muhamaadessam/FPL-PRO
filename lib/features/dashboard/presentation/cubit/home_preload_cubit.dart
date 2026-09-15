import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../fixtures/data/models/fpl_models.dart';
import '../../../fixtures/domain/repositories/fixtures_repository.dart';
import '../../../team/data/models/team_models.dart';
import '../../../team/domain/repositories/team_repository.dart';

enum PreloadStatus { initial, loading, success, failure }

class HomePreloadState {
  const HomePreloadState({
    this.status = PreloadStatus.initial,
    this.bootstrap,
    this.teamCurrent,
    this.teamNext,
    this.entry,
    this.gameweekPoints = const {},
    this.historyPoints = const {},
    this.fixtures = const [],
    this.currentGameweekFixtures = const [],
    this.playerSummaries = const {},
    this.error,
    this.entryId,
  });

  final PreloadStatus status;
  final FplBootstrap? bootstrap;
  final MyTeam? teamCurrent;
  final MyTeam? teamNext;
  final FplEntry? entry;
  final Map<int, int> gameweekPoints;
  final Map<int, int> historyPoints;
  final List<FplFixture> fixtures;
  final List<FplFixture> currentGameweekFixtures;
  final Map<int, FplPlayerSummary> playerSummaries;
  final Object? error;
  final int? entryId;

  HomePreloadState copyWith({
    PreloadStatus? status,
    FplBootstrap? bootstrap,
    MyTeam? teamCurrent,
    MyTeam? teamNext,
    FplEntry? entry,
    Map<int, int>? gameweekPoints,
    Map<int, int>? historyPoints,
    List<FplFixture>? fixtures,
    List<FplFixture>? currentGameweekFixtures,
    Map<int, FplPlayerSummary>? playerSummaries,
    Object? error,
    int? entryId,
  }) {
    return HomePreloadState(
      status: status ?? this.status,
      bootstrap: bootstrap ?? this.bootstrap,
      teamCurrent: teamCurrent ?? this.teamCurrent,
      teamNext: teamNext ?? this.teamNext,
      entry: entry ?? this.entry,
      gameweekPoints: gameweekPoints ?? this.gameweekPoints,
      historyPoints: historyPoints ?? this.historyPoints,
      fixtures: fixtures ?? this.fixtures,
      currentGameweekFixtures:
          currentGameweekFixtures ?? this.currentGameweekFixtures,
      playerSummaries: playerSummaries ?? this.playerSummaries,
      error: error,
      entryId: entryId ?? this.entryId,
    );
  }
}

class HomePreloadCubit extends Cubit<HomePreloadState> {
  HomePreloadCubit({
    required this.fixturesRepository,
    required this.teamRepository,
    required this.authCubit,
  }) : super(const HomePreloadState());

  final FixturesRepository fixturesRepository;
  final TeamRepository teamRepository;
  final AuthCubit authCubit;

  bool _isLoading = false;

  Future<void> load() async {
    if (_isLoading) return;
    final session = authCubit.state.session;
    if (session == null || session.entryId == null) {
      emit(
        state.copyWith(status: PreloadStatus.failure, error: 'Unauthenticated'),
      );
      return;
    }

    _isLoading = true;
    emit(state.copyWith(status: PreloadStatus.loading, error: null));
    try {
      final bootstrap = await fixturesRepository.getBootstrap();
      final currentGameweekId = bootstrap.currentGameweekId;

      final nextGameweekId = bootstrap.gameweeks
          .firstWhere(
            (gameweek) => gameweek.isNext,
            orElse: () => bootstrap.gameweeks.firstWhere(
              (gameweek) => gameweek.id > bootstrap.currentGameweekId,
              orElse: () => bootstrap.gameweeks.last,
            ),
          )
          .id;

      final futures = await Future.wait([
        teamRepository.getTeamForGameweek(
          entryId: session.entryId!,
          gameweekId: currentGameweekId,
          session: session,
          currentGameweekId: currentGameweekId,
        ),
        teamRepository.getMyTeam(
          session: session,
          entryId: session.entryId!,
          gameweekId: nextGameweekId,
        ),
        fixturesRepository.getFixtures(),
        fixturesRepository.getGameweekPoints(currentGameweekId),
      ]);

      final teamCurrent = futures[0] as MyTeam;
      final teamNext = futures[1] as MyTeam;
      final fixtures = futures[2] as List<FplFixture>;
      final gameweekPoints = futures[3] as Map<int, int>;
      final currentGameweekFixtures = fixtures
          .where((fixture) => fixture.gameweekId == currentGameweekId)
          .toList(growable: false);

      var historyPoints = const <int, int>{};
      try {
        historyPoints = await fixturesRepository.getEntryHistoryPoints(
          session.entryId!,
        );
      } catch (_) {
        // history points are supplementary, failure shouldn't fail whole preload
      }

      FplEntry? entry;
      try {
        entry = await teamRepository.getEntry(session.entryId!);
      } catch (_) {
        // entry metadata is supplementary, failure shouldn't fail whole preload
      }

      final playerSummaries = Map<int, FplPlayerSummary>.fromEntries(
        await Future.wait(
          teamNext.picks.map((pick) async {
            try {
              return MapEntry(
                pick.elementId,
                await fixturesRepository.getPlayerSummary(pick.elementId),
              );
            } catch (_) {
              return MapEntry(pick.elementId, const FplPlayerSummary());
            }
          }),
        ),
      );

      emit(
        state.copyWith(
          status: PreloadStatus.success,
          bootstrap: bootstrap,
          teamCurrent: teamCurrent,
          teamNext: teamNext,
          entry: entry,
          fixtures: fixtures,
          currentGameweekFixtures: currentGameweekFixtures,
          gameweekPoints: gameweekPoints,
          historyPoints: historyPoints,
          playerSummaries: playerSummaries,
          entryId: session.entryId,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: PreloadStatus.failure, error: e));
    } finally {
      _isLoading = false;
    }
  }
}
