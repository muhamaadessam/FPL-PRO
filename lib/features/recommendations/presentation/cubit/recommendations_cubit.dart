import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/cubit/auth_cubit.dart';
import 'package:fpl_engine/fpl_engine.dart';
import '../../../fixtures/domain/repositories/fixtures_repository.dart';
import '../../../team/data/repositories/team_repository.dart';
import '../../../team/domain/repositories/team_repository.dart';
import '../../domain/entities/recommendation_data.dart';

enum RecommendationsStatus { initial, loading, success, failure }

class RecommendationsState {
  const RecommendationsState({
    this.status = RecommendationsStatus.initial,
    this.data,
    this.error,
  });

  final RecommendationsStatus status;
  final RecommendationData? data;
  final Object? error;

  RecommendationsState copyWith({
    RecommendationsStatus? status,
    RecommendationData? data,
    Object? error,
  }) {
    return RecommendationsState(
      status: status ?? this.status,
      data: data ?? this.data,
      error: error,
    );
  }
}

class RecommendationsCubit extends Cubit<RecommendationsState> {
  RecommendationsCubit({
    required this.fixturesRepository,
    required this.teamRepository,
    required this.authCubit,
    RecommendationsState? initialState,
  }) : super(initialState ?? const RecommendationsState());

  final FixturesRepository fixturesRepository;
  final TeamRepository teamRepository;
  final AuthCubit authCubit;

  Future<void> load() async {
    if (isClosed || state.status == RecommendationsStatus.loading) return;
    emit(state.copyWith(status: RecommendationsStatus.loading, error: null));
    try {
      final bootstrap = await fixturesRepository.getBootstrap();
      final gameweek = _nextGameweek(bootstrap);
      final session = authCubit.state.session;
      if (session == null || session.entryId == null) {
        throw const TeamAccessException(TeamAccessError.entryIdMissing);
      }
      final publishedFuture = fixturesRepository.getPublishedPlayerProjections(
        bootstrap.players,
      );
      final fixtures = await fixturesRepository.getFixtures();
      final team = await teamRepository.getMyTeam(
        session: session,
        entryId: session.entryId!,
        gameweekId: gameweek.id,
      );
      final playerSummaries = Map<int, FplPlayerSummary>.fromEntries(
        await Future.wait(
          team.picks.map((pick) async {
            try {
              return MapEntry(
                pick.elementId,
                await fixturesRepository.getPlayerSummary(pick.elementId),
              );
            } on Object {
              return MapEntry(pick.elementId, const FplPlayerSummary());
            }
          }),
        ),
      );
      const engine = RecommendationEngine();
      // The server's projections when current, so every user sees the same
      // numbers; only the squad-specific advice below is computed here.
      final projections =
          (await publishedFuture)?.usableFor(gameweek.id) ??
          engine.buildPlayerProjections(
            bootstrap: bootstrap,
            fixtures: fixtures,
            gameweekId: gameweek.id,
            playerSummaries: playerSummaries,
            recentGameweekMinutes: await _recentGameweekMinutes(bootstrap),
          );
      final result = engine.build(
        bootstrap: bootstrap,
        fixtures: fixtures,
        team: team,
        gameweekId: gameweek.id,
        playerSummaries: playerSummaries,
        precomputedProjections: projections,
      );
      if (isClosed) return;
      emit(
        RecommendationsState(
          status: RecommendationsStatus.success,
          data: RecommendationData(
            result: result,
            gameweek: gameweek,
            bootstrap: bootstrap,
            team: team,
            fixtures: fixtures,
            projections: projections,
            updatedAt: DateTime.now(),
          ),
        ),
      );
    } on Object catch (error) {
      if (isClosed) return;
      emit(state.copyWith(status: RecommendationsStatus.failure, error: error));
    }
  }

  /// Live minutes for every player in the latest finished Gameweeks, so
  /// transfer targets are judged on recent minutes like the squad is. A
  /// Gameweek that fails to load is skipped.
  Future<Map<int, Map<int, int>>> _recentGameweekMinutes(
    FplBootstrap bootstrap,
  ) async {
    final finished =
        bootstrap.gameweeks
            .where((gameweek) => gameweek.finished)
            .map((gameweek) => gameweek.id)
            .toList()
          ..sort();
    final recent = finished.reversed.take(5).toList(growable: false);
    final minutes = await Future.wait(
      recent.map((id) async {
        try {
          return MapEntry(id, await fixturesRepository.getGameweekMinutes(id));
        } on Object {
          return null;
        }
      }),
    );
    return {
      for (final entry in minutes.nonNulls)
        if (entry.value.isNotEmpty) entry.key: entry.value,
    };
  }

  Gameweek _nextGameweek(FplBootstrap bootstrap) {
    return bootstrap.gameweeks.firstWhere(
      (gameweek) => gameweek.isNext,
      orElse: () => bootstrap.gameweeks.firstWhere(
        (gameweek) => gameweek.id > bootstrap.currentGameweekId,
        orElse: () => bootstrap.gameweeks.last,
      ),
    );
  }

  Future<void> refresh() => load();

  Future<void> makeTransfer(TransferSuggestion transfer) async {
    final session = authCubit.state.session;
    final data = state.data;
    if (session == null || session.entryId == null || data == null) {
      throw const TeamAccessException(TeamAccessError.entryIdMissing);
    }
    await teamRepository.makeTransfers(
      session: session,
      entryId: session.entryId!,
      gameweekId: data.gameweek.id,
      transfers: [
        TransferRequest(
          elementIn: transfer.inPlayer.id,
          elementOut: transfer.outPlayer.id,
          purchasePrice: transfer.inPlayer.nowCost ?? 0,
          sellingPrice: _sellingPrice(data.team, transfer.outPlayer.id),
        ),
      ],
    );
    await load();
  }

  Future<void> saveChip(SuggestedChip chip) async {
    final session = authCubit.state.session;
    final data = state.data;
    if (session == null || session.entryId == null || data == null) {
      throw const TeamAccessException(TeamAccessError.entryIdMissing);
    }
    await teamRepository.saveMyTeam(
      session: session,
      entryId: session.entryId!,
      chip: _chipName(chip),
      picks: data.team.picks,
    );
    await load();
  }

  int _sellingPrice(MyTeam team, int elementId) {
    return team.picks
            .firstWhere(
              (pick) => pick.elementId == elementId,
              orElse: () => const TeamPick(
                elementId: 0,
                position: 0,
                multiplier: 0,
                isCaptain: false,
                isViceCaptain: false,
                elementType: 0,
              ),
            )
            .sellingPrice ??
        0;
  }

  String? _chipName(SuggestedChip chip) {
    return switch (chip) {
      SuggestedChip.none => null,
      SuggestedChip.wildcard => FplChipName.wildcard,
      SuggestedChip.freeHit => FplChipName.freeHit,
      SuggestedChip.benchBoost => FplChipName.benchBoost,
      SuggestedChip.tripleCaptain => FplChipName.tripleCaptain,
    };
  }
}
