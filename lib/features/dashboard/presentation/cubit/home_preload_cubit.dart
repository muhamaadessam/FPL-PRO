import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../fixtures/data/datasources/fpl_api_client.dart';
import 'package:fpl_engine/fpl_engine.dart';
import '../../../fixtures/domain/repositories/fixtures_repository.dart';
import '../../../team/domain/repositories/team_repository.dart';

enum PreloadStatus { initial, loading, success, failure, teamSetupRequired }

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

  /// The gameweek the home team view opens on: the current one, or the
  /// manager's first gameweek when they joined after its deadline.
  int? get homeGameweekId {
    final currentGameweekId = bootstrap?.currentGameweekId;
    if (currentGameweekId == null) return null;
    final startedEvent = entry?.startedEvent;
    return startedEvent != null && startedEvent > currentGameweekId
        ? startedEvent
        : currentGameweekId;
  }

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
    final entryId = session.entryId!;
    try {
      // Entry metadata is supplementary, but it tells us whether this manager
      // has played yet, so fetch it alongside the bootstrap.
      final entryFuture = _loadEntry(entryId);
      final bootstrap = await fixturesRepository.getBootstrap();
      final entry = await entryFuture;
      final currentGameweekId = bootstrap.currentGameweekId;
      final nextGameweekId = bootstrap.gameweeks.isEmpty
          ? currentGameweekId
          : bootstrap.gameweeks
                .firstWhere(
                  (gameweek) => gameweek.isNext,
                  orElse: () => bootstrap.gameweeks.firstWhere(
                    (gameweek) => gameweek.id > currentGameweekId,
                    orElse: () => bootstrap.gameweeks.last,
                  ),
                )
                .id;

      // A manager who joined after the current gameweek's deadline has no
      // squad, live points or history for it yet; only the upcoming squad.
      final hasCurrentSquad = entry?.hasStartedBy(currentGameweekId) ?? true;

      final futures = await Future.wait([
        hasCurrentSquad
            ? _loadOptional(
                teamRepository.getTeamForGameweek(
                  entryId: entryId,
                  gameweekId: currentGameweekId,
                  session: session,
                  editableGameweekId: nextGameweekId,
                ),
              )
            : Future<MyTeam?>.value(),
        _loadTeamOrSetup(
          teamRepository.getMyTeam(
            session: session,
            entryId: entryId,
            gameweekId: nextGameweekId,
          ),
        ),
        fixturesRepository.getFixtures(),
        hasCurrentSquad
            ? _loadOptional(
                fixturesRepository.getGameweekPoints(currentGameweekId),
              )
            : Future<Map<int, int>?>.value(),
      ]);

      final teamNext = futures[1] as MyTeam;
      // The current-gameweek squad is missing for new managers; the upcoming
      // squad is what they have picked, so show that instead of failing.
      final teamCurrent = futures[0] as MyTeam? ?? teamNext;
      final fixtures = futures[2] as List<FplFixture>;
      final gameweekPoints = futures[3] as Map<int, int>? ?? const <int, int>{};
      final currentGameweekFixtures = fixtures
          .where((fixture) => fixture.gameweekId == currentGameweekId)
          .toList(growable: false);

      // History points are supplementary; failure shouldn't fail the preload.
      final historyPoints =
          await _loadOptional(
            fixturesRepository.getEntryHistoryPoints(entryId),
          ) ??
          const <int, int>{};

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
          entryId: entryId,
        ),
      );
    } on _MissingTeamPicksException {
      emit(
        state.copyWith(
          status: PreloadStatus.teamSetupRequired,
          entryId: entryId,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: PreloadStatus.failure, error: e));
    } finally {
      _isLoading = false;
    }
  }

  Future<FplEntry?> _loadEntry(int entryId) =>
      _loadOptional(teamRepository.getEntry(entryId));

  Future<T?> _loadOptional<T extends Object>(Future<T> request) async {
    try {
      return await request;
    } catch (_) {
      return null;
    }
  }

  Future<MyTeam> _loadTeamOrSetup(Future<MyTeam> request) async {
    try {
      return await request;
    } on FplApiException catch (error) {
      if (error.statusCode == 404) {
        throw const _MissingTeamPicksException();
      }
      rethrow;
    }
  }

  Future<void> refreshEntry() async {
    final session = authCubit.state.session;
    if (session == null || session.entryId == null) return;
    try {
      final entry = await teamRepository.getEntry(session.entryId!);
      emit(state.copyWith(entry: entry, entryId: session.entryId));
    } catch (_) {
      // Keep the existing home data visible when a lightweight refresh fails.
    }
  }
}

class _MissingTeamPicksException implements Exception {
  const _MissingTeamPicksException();
}
